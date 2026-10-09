extends Node

signal reply_received(text: String, source: String, action: String)
signal reply_progress(text: String)
signal changed
var progress_request: HTTPRequest
var progress_id := ""
var progress_poll_id := ""
var progress_polling := false
var progress_next := 0
var progress_text := ""
var mind = preload("res://scripts/companion_mind.gd").new()
var commands = preload("res://scripts/companion_actions.gd").new()
var last_execution: Dictionary = {}
var pending_chats: Array[String] = []
const SAVE_PATH := "user://companion.json"
const AI_PROVIDER := "codex_agents"
var save_path: String = SAVE_PATH
var profile: Dictionary = {"role": "男威龙", "address": "", "style": "温柔具体", "partner": "女友陪伴"}
var memories: Array = []
var conversation: Array = []
var enabled: bool = true
var ai_enabled: bool = true
var pending_memory: String = ""
var busy: bool = false
var status: String = "Codex AI 已启用 · 等待对话"
var current_kind: String = ""
var current_fallback: String = ""
var request_started_msec: int = 0
var last_reply_latency_ms: int = 0
var epoch: int = 0
var request_epoch: int = 0
var service_url: String = "http://127.0.0.1:18765/companion"
var connection_status: String = ""
var checking: bool = false
var connection_epoch: int = 0
var health_retries: int = 0
var last_tools: Array = []
var last_auto: int = -100000
var recent_kill: float = -100.0
var combo_dash: bool = false
@onready var request: HTTPRequest = $Request

func _ready() -> void:
	var test_mode: bool = "--smoke" in OS.get_cmdline_user_args() or "--companion-test" in OS.get_cmdline_user_args() or "--companion-live-test" in OS.get_cmdline_user_args() or "--upgrade-test" in OS.get_cmdline_user_args() or "--voice-live-test" in OS.get_cmdline_user_args() or "--latency-ui-test" in OS.get_cmdline_user_args() or "--latency-live-test" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		test_mode = test_mode or arg.begins_with("--capture-")
	if test_mode:
		save_path = "user://companion_test.json"
		ai_enabled = false
	else:
		load_state()
	progress_request = HTTPRequest.new()
	progress_request.timeout = 2.0
	add_child(progress_request)
	progress_request.request_completed.connect(_progress_completed)
	request.request_completed.connect(_completed)
	$Health.request_completed.connect(_health_completed)
	if save_path == SAVE_PATH and ai_enabled:
		call_deferred("connect_ai")

# A toggle is an immediate preference, not a claim that a model is ready.
func set_ai_enabled(value: bool) -> void:
	invalidate()
	ai_enabled = value
	save_state()
	if value:
		connect_ai()
	else:
		connection_epoch += 1
		$Health.cancel_request()
		checking = false
		status = "Codex AI 已关闭 · 开启后才能聊天"
		changed.emit()

func connect_ai() -> void:
	if checking or not ai_enabled:
		return
	checking = true
	connection_epoch += 1
	var generation := connection_epoch
	health_retries = 0
	status = "正在检查模型连接…"
	changed.emit()
	# The game EXE can be opened directly; start the same bundled local service.
	var root := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var script := root.path_join("companion-service/start.ps1")
	if FileAccess.file_exists(script) and (save_path == SAVE_PATH or "--companion-live-test" in OS.get_cmdline_user_args() or "--upgrade-test" in OS.get_cmdline_user_args() or "--voice-live-test" in OS.get_cmdline_user_args()):
		OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script])
	await get_tree().create_timer(2.0).timeout
	if not checking or not ai_enabled or generation != connection_epoch:
		return
	if $Health.request(service_url.get_base_dir() + "/health") != OK:
		checking = false
		status = "陪伴服务未启动，请使用新版启动游戏入口"
		changed.emit()

func _health_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	checking = false
	if not ai_enabled:
		return
	var data = parse_response(body)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary or data.get("service") != "jiahao-companion":
		if health_retries < 3:
			health_retries += 1
			checking = true
			var generation := connection_epoch
			await get_tree().create_timer(2.0).timeout
			if generation == connection_epoch and ai_enabled:
				if $Health.request(service_url.get_base_dir() + "/health") != OK:
					checking = false
					status = "陪伴服务启动失败，请重启游戏"
					changed.emit()
			return
		connection_status = "陪伴服务未启动；请点击检查 / 重连 AI"
	elif not data.get("ready", false):
		connection_status = str(data.get("error", "模型没有就绪"))
	else:
		connection_status = "本地 AI 就绪 · " + str(data.get("model", "")) if data.get("provider") == "ollama" else "云端模型已配置 · 首次回复验证连接"
	if not busy:
		status = connection_status
	changed.emit()

func address() -> String:
	if mind.preferences.has("address"):
		return str(mind.preferences.address.value)
	var custom := str(profile.get("address", "")).strip_edges()
	return custom if not custom.is_empty() else ("姐姐" if profile.role == "女威龙" else "哥哥")

func save_state() -> void:
	var data := {"version": 2, "profile": profile, "memories": memories, "conversation": conversation, "enabled": enabled, "ai_enabled": ai_enabled, "ai_provider": AI_PROVIDER, "mind": mind.snapshot()}
	var f := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if not f:
		status = "保存失败，请检查存档目录"
		changed.emit()
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var error := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error != OK:
		status = "保存失败，请检查存档目录"
		changed.emit()

func load_state() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		status = "存档无法读取，原文件保留"
		return
	if data.get("profile") is Dictionary:
		for key in profile:
			if data.profile.get(key) is String:
				profile[key] = data.profile[key].left(100)
	if data.get("memories") is Array:
		for value in data.memories:
			if value is String and memories.size() < 30:
				memories.append(value.left(200))
	if data.get("conversation") is Array:
		for value in data.conversation.slice(-240):
			if value is Dictionary and value.get("role") in ["user", "assistant"] and value.get("content") is String:
				conversation.append({"role": value.role, "content": value.content.left(1500), "source": str(value.get("source", "")), "latency_ms": clampi(int(value.get("latency_ms", 0)), 0, 120000)})
	enabled = data.get("enabled", true) == true
	mind.restore(data.get("mind", {}))
	# Old saves may have AI disabled for the local-model edition. Enable Codex once.
	ai_enabled = data.get("ai_enabled", true) == true if data.get("ai_provider") == AI_PROVIDER else true
	status = "Codex AI 已启用 · 等待对话" if ai_enabled else "Codex AI 已关闭 · 开启后才能聊天"

func invalidate() -> void:
	epoch += 1
	request.cancel_request()
	progress_request.cancel_request()
	progress_polling = false
	progress_id = ""
	busy = false
	pending_memory = ""
	changed.emit()

func configure(values: Dictionary, notes: String, active: bool, online: bool) -> void:
	invalidate()
	profile = values.duplicate()
	mind.set_preference("style", str(profile.get("style", "温柔具体")), "玩家在偏好页设置")
	if str(profile.get("address", "")).is_empty(): mind.preferences.erase("address")
	else: mind.set_preference("address", str(profile.address), "玩家在偏好页设置")
	memories.clear()
	for line in notes.split("\n", false):
		var item := line.strip_edges().left(200)
		if not item.is_empty() and not memories.has(item) and memories.size() < 30:
			memories.append(item)
	enabled = active
	ai_enabled = online
	status = "Codex AI 已启用 · 等待对话" if online else "Codex AI 已关闭 · 开启后才能聊天"
	save_state()
	changed.emit()

func history() -> Array:
	var path := history_path()
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Array else []

func history_path() -> String:
	return "user://training_history.json" if save_path == SAVE_PATH else "user://training_history_test.json"

func training_summary() -> String:
	var rows := history()
	var counts: Dictionary = {}
	var seconds: float = 0
	for row in rows:
		if not row is Dictionary:
			continue
		var key := str(int(row.get("level", 0)))
		counts[key] = int(counts.get(key, 0)) + 1
		seconds += float(row.get("seconds", 0))
	var favorite := "暂无"
	var highest: int = 0
	for key in counts:
		if counts[key] > highest:
			highest = counts[key]
			favorite = "第 %s 关（%d 轮）" % [key, highest]
	return "最近 %d 轮 · %.1f 分钟\n最常练：%s" % [rows.size(), seconds / 60.0, favorite]

func model_history() -> Array:
	# Detailed per-frame evidence stays in the game save, outside model context.
	var compact: Array = []
	for row in history().slice(-100):
		if not row is Dictionary: continue
		var item := {}
		for key in ["level", "seconds", "shots", "hits", "headshots", "kills", "abilities", "unix_time", "success"]:
			if row.has(key): item[key] = row[key]
		var metrics := {}
		if row.get("drill_metrics") is Dictionary:
			for key in ["drill", "reaction_ms", "reaction_hits", "opportunities", "audio_correct", "audio_attempts", "explosive_hits", "jump_height", "apex_seconds", "dash_distance"]:
				var value = row.drill_metrics.get(key)
				if value is float or value is int: metrics[key] = value
		item["drill_metrics"] = metrics
		compact.append(item)
	return compact

func append_line(role: String, text: String, source: String = "", latency_ms: int = 0) -> void:
	conversation.append({"role": role, "content": text, "source": source, "latency_ms": latency_ms})
	if conversation.size() > 240:
		conversation.pop_front()
	save_state()

func say(text: String, source: String = "fallback", action: String = "nod", latency_ms: int = 0) -> void:
	last_reply_latency_ms = latency_ms if source == "ai" else 0
	append_line("assistant", text, source, last_reply_latency_ms)
	reply_received.emit(text, source, action)
	changed.emit()

func chat(message: String) -> void:
	message = message.strip_edges().left(1500)
	if message.is_empty():
		return
	if busy and current_kind == "event": invalidate()
	if busy and not commands.is_command(message):
		pending_chats.append(message)
		status = "我先接着这句说，下一句也收到了。"
		changed.emit()
		return
	if busy: invalidate()
	pending_memory = ""
	var prior := conversation.duplicate(true)
	append_line("user", message)
	var learned: Array[String] = mind.learn(message)
	if mind.preferences.has("style"): profile.style = mind.preferences.style.value
	var fallback: String = mind.reply(message, address(), learned)
	var routes: Node = get_parent().get_node("CompanionRoutes")
	last_tools = []
	var command: Dictionary = commands.interpret(message, get_parent())
	if not command.is_empty():
		status = "收到，正在处理…"
		changed.emit()
		_perform_command.call_deferred(command)
		return
	if not ai_enabled and commands.matches(message, "(安排|制定|推荐|准备|规划|给我).*?(路线|训练|计划)") and not commands.matches(message,"不要|别|不想|为什么|如果"):
		var minutes_pattern := RegEx.new()
		minutes_pattern.compile("(\\d+)\\s*分钟")
		var minutes_match := minutes_pattern.search(message)
		var minutes := clampi(int(minutes_match.get_string(1)), 3, 30) if minutes_match else 15
		routes.build("", minutes)
		fallback = "我按你的偏好排了三套路线。打开 F7 的训练路线页可以看每一段并开始；每段到时会问你，按 Y 才换关。"
		last_tools = ["read_training", "plan_training"]
		status = "路线已准备好 · 本地工具"
		say(fallback, "local")
		return
	if message.begins_with("记住：") or message.begins_with("记住:"):
		pending_memory = message.substr(3).strip_edges().left(200)
		fallback = "我把这件事放在下方了，点“记住这件事”后就会写进记忆。"
	elif "进步" in message or "成绩" in message:
		fallback = "%s，这是存档里的训练记录：\n%s\n慢慢来，下一轮继续陪你。" % [address(), training_summary()]
		last_tools = ["read_training"]
	save_state()
	if ai_enabled:
		ask("chat", message, fallback, prior)
	else:
		status = "离线陪伴 · 本地回应"
		say(fallback, "local")

func ask(kind: String, content: String, fallback: String, prior: Array = []) -> void:
	request_started_msec = Time.get_ticks_msec()
	if get_parent().get_node("CompanionRoutes").candidates.is_empty(): get_parent().get_node("CompanionRoutes").build()
	busy = true
	current_kind = kind
	current_fallback = fallback
	request_epoch = epoch
	status = "麦小鼠正在想…"
	progress_id = Crypto.new().generate_random_bytes(16).hex_encode()
	progress_text = ""
	progress_next = Time.get_ticks_msec() + 200
	if kind == "chat": reply_progress.emit("")
	changed.emit()
	# A stopped loopback service should fail quickly; model generation may still
	# need the longer HTTP timeout for an initial cold load.
	if service_url.begins_with("http://127.0.0.1:"):
		var generation := epoch
		var peer := StreamPeerTCP.new()
		var port := int(service_url.trim_prefix("http://127.0.0.1:").get_slice("/", 0))
		var connected := peer.connect_to_host("127.0.0.1", port)
		var deadline := Time.get_ticks_msec() + 1200
		while connected == OK and peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < deadline and generation == epoch:
			peer.poll()
			await get_tree().process_frame
		var ready := peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
		peer.disconnect_from_host()
		if generation != epoch: return
		if not ready:
			failed("本地陪伴服务未连接；训练操作仍可使用")
			return
	var body := {"request_id": progress_id, "kind": kind, "message": content if kind == "chat" else "", "event": content if kind == "event" else "", "profile": profile.merged({"address": address()}, true), "memories": memories, "history": model_history(), "conversation": prior.slice(-240), "mind": mind.snapshot(), "training": get_parent().get_node("CompanionRoutes").context(), "game": {"levels": commands.catalog(), "current_level":get_parent().level_index, "running":get_parent().running}}
	var error := request.request(service_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		failed()

func failed(reason: String = "无法连接陪伴服务；请点击检查 / 重连 AI") -> void:
	if "--live-model" in OS.get_cmdline_user_args(): print("LIVE_MODEL_FAILURE ", reason)
	busy = false
	status = reason + " · 备用台词"
	say("这次没能完成理解或操作：%s。训练仍可继续。" % reason if current_kind == "chat" else current_fallback)

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if request_epoch != epoch:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var error = parse_response(body)
		failed(str(error.error).left(160) if error is Dictionary and error.get("error") is String else "陪伴服务无响应或超时；请点击检查 / 重连 AI")
		return
	var data = parse_response(body)
	if not data is Dictionary or not data.get("text") is String or data.text.strip_edges().is_empty() or data.get("source") not in ["ai", "local"]:
		failed()
		return
	busy = false
	status = "本地回应" if data.source == "local" else "AI 已连接"
	last_tools = data.get("tools", []) if data.get("tools") is Array else []
	if data.get("emotion") is String: mind.feel(data.emotion, float(data.get("intensity", 0.5)))
	if current_kind == "chat" and data.get("preferences") is Array:
		var allowed := {"style": ["温柔具体", "活泼夸夸", "轻松调侃", "安静简短"], "service": ["先陪伴，暂不建议训练", "陪伴与训练建议"], "focus": ["laser", "tracking", "mixed"], "persona": mind.PERSONAS}
		var current_message := ""
		for line in conversation:
			if line.role == "user": current_message = line.content
		for preference in data.preferences.slice(0, 4):
			if not preference is Dictionary or not allowed.has(preference.get("key")): continue
			if preference.get("value") not in allowed[preference.key] or not preference.get("source") is String: continue
			if preference.source.length() < 2 or preference.source not in current_message: continue
			if preference.key == "persona": mind.persona = preference.value
			else: mind.set_preference(preference.key, preference.value, preference.source)
			if preference.key == "style": profile.style = preference.value
	if data.get("route_focus") in ["laser", "tracking", "mixed"]:
		get_parent().get_node("CompanionRoutes").build(data.route_focus, clampi(int(data.get("route_minutes", 15)), 3, 30))
	if current_kind == "chat" and data.get("game_action") is Dictionary and data.game_action.get("kind") in ["switch_level", "start_custom_route", "prepare_custom_route", "stop_route", "pause_route", "resume_route", "next_route"]:
		data.game_action["origin"] = "model"
		_perform_command.call_deferred(data.game_action)
		return
	if current_kind == "chat" and pending_memory.is_empty() and data.get("memory") is String:
		pending_memory = data.memory.left(200)
	var action: String = str(data.get("action", "idle"))
	var latency_ms := maxi(0, Time.get_ticks_msec() - request_started_msec) if current_kind == "chat" and data.source == "ai" else 0
	say(data.text.left(500), data.source, action if action in ["nod", "cheer", "idle"] else "idle", latency_ms)

func _perform_command(command: Dictionary) -> void:
	var model_tools: Array = last_tools.duplicate() if command.get("origin") == "model" else []
	last_execution = commands.execute(command, get_parent())
	last_execution["origin"] = command.get("origin", "local")
	last_tools = model_tools
	if last_execution.tool not in last_tools: last_tools.append(last_execution.tool)
	busy = false
	status = "操作已完成" if last_execution.ok and command.kind != "reply" else "等你告诉我"
	if not last_execution.ok: status = "操作未完成"
	get_parent().get_node("BubbleUI").explicit_reply_pending = true
	get_parent().get_node("BubbleUI").operation_receipt_until = Time.get_ticks_msec() + 8000
	say(last_execution.text, "local")

func parse_response(body: PackedByteArray) -> Variant:
	var json := JSON.new()
	return json.data if not body.is_empty() and json.parse(body.get_string_from_utf8()) == OK else null

func confirm_memory() -> void:
	if pending_memory.is_empty():
		return
	if memories.size() >= 30:
		status = "记忆已满，请先编辑或删除一些内容"
		changed.emit()
		return
	if not memories.has(pending_memory):
		memories.append(pending_memory)
	pending_memory = ""
	save_state()
	changed.emit()

func reset_session() -> void:
	invalidate()
	recent_kill = -100
	combo_dash = false
	last_auto = -100000

func observe(kind: String, elapsed: float) -> void:
	if kind == "kill":
		recent_kill = elapsed
		combo_dash = false
		auto_feedback("完成一次击倒", "%s，这次击倒拿下了！继续稳住。" % address(), false)
	elif kind == "dash" and elapsed - recent_kill <= 5.0:
		combo_dash = true
		auto_feedback("击倒后五秒内完成动力推进衔接；不代表已验证入掩体", "%s，击倒接喷气，衔接起来了！" % address(), true)

func auto_feedback(event: String, fallback: String, important: bool = false) -> void:
	if not enabled:
		return
	if str(mind.preferences.get("service", {}).get("value", "")).begins_with("先陪伴"):
		return
	if get_parent().get_node("CompanionRoutes").pending:
		return
	mind.feel("激动" if important else "佩服", 0.75 if important else 0.4)
	# Every action gets a gesture; text/AI is paced to avoid interrupting aim.
	get_parent().get_node("CompanionActor").react("cheer")
	if profile.style == "安静简短" and not important:
		return
	if not important and Time.get_ticks_msec() - last_auto < 7000:
		return
	last_auto = Time.get_ticks_msec()
	if profile.style == "活泼夸夸":
		fallback = ("太飒了！" if profile.role == "女威龙" else "太帅了！") + fallback
	elif profile.style == "轻松调侃":
		fallback += "这波，给你记上一笔。"
	if busy:
		if current_kind == "chat":
			return
		invalidate()
	if ai_enabled:
		ask("event", event, fallback)
	else:
		say(fallback)

func training_finished(success: bool, kills: int, shots: int, hits: int) -> void:
	var accuracy := int(100.0 * hits / maxi(1, shots))
	auto_feedback("训练已结算：成功=%s，击倒%d，命中率%d%%。可查训练工具对比，勿编造纪录。" % [success, kills, accuracy],
		"%s，这轮 %d 次击倒，命中率 %d%%。%s" % [address(), kills, accuracy, "练完了，休息一下也很好。" if success else "没关系，我们按自己的节奏再来。"], true)

func _progress_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	progress_polling = false
	if not busy or current_kind != "chat" or progress_poll_id != progress_id or result != HTTPRequest.RESULT_SUCCESS or code != 200: return
	var data = parse_response(body)
	if data is Dictionary and data.get("text") is String and not data.text.is_empty() and data.text != progress_text:
		progress_text = data.text.left(500)
		status = "麦小鼠正在回复…"
		reply_progress.emit(progress_text)
		changed.emit()

func _process(delta: float) -> void:
	if busy and current_kind == "chat" and not progress_polling and Time.get_ticks_msec() >= progress_next and not progress_id.is_empty():
		progress_next = Time.get_ticks_msec() + 250
		progress_poll_id = progress_id
		progress_polling = progress_request.request(service_url.get_base_dir() + "/progress/" + progress_id) == OK
	if not busy and not pending_chats.is_empty(): chat(pending_chats.pop_front())
	if not get_tree().paused and mind.tick(delta): changed.emit()
