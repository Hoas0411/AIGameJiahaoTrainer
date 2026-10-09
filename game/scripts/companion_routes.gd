extends Node

signal changed
const PROMPT_SECONDS := 15.0
const TRACKS := {
	"laser": [{"level": 0, "title": "AWM 镭射", "weapon": "awm", "laser": true, "goal": "稳定预瞄，击倒后回到掩体"}, {"level": 15, "title": "中门缝反应", "weapon": "awm", "laser": false, "goal": "看到目标再击发，避免预判乱开枪"}, {"level": 6, "title": "基础靶场", "weapon": "rifle", "laser": false, "goal": "降低节奏，观察首发落点"}],
	"tracking": [{"level": 13, "title": "平滑跟枪", "weapon": "rifle", "laser": false, "goal": "连续贴住目标，减少来回过冲"}, {"level": 7, "title": "随机反应", "weapon": "rifle", "laser": false, "goal": "观察亮靶，确认后射击"}, {"level": 6, "title": "基础靶场", "weapon": "rifle", "laser": false, "goal": "放慢节奏，结束前巩固准星控制"}],
	"mixed": [{"level": 6, "title": "基础靶场", "weapon": "rifle", "laser": false, "goal": "点射热身，找到舒适节奏"}, {"level": 0, "title": "AWM 镭射", "weapon": "awm", "laser": true, "goal": "单发定位，观察预瞄误差"}, {"level": 13, "title": "平滑跟枪", "weapon": "rifle", "laser": false, "goal": "持续跟住目标，以稳定结束"}]
}
var candidates: Array = []
var active: Dictionary = {}
var step_index: int = 0
var step_elapsed: float = 0
var pending: bool = false
var prompt_remaining: float = 0
var deferred_prompt: bool = false
var suspended: bool = false
var switching: bool = false
var status: String = "说说想练什么，我来排路线"
var game: Node:
	get: return get_parent()

func build(focus: String = "", minutes: int = 15) -> Array:
	var reason := "还没有足够训练记录，先提供均衡选择"
	var mind = game.get_node("Companion").mind
	if not TRACKS.has(focus):
		focus = str(mind.preferences.get("focus", {}).get("value", ""))
		if TRACKS.has(focus): reason = "按你在对话里明确表达的训练偏好"
	else:
		reason = "按本次指定训练方向"
	if not TRACKS.has(focus):
		var seconds := {"laser": 0.0, "tracking": 0.0, "mixed": 0.0}
		for row in game.get_node("Companion").history():
			if not row is Dictionary: continue
			var key := "laser" if int(row.get("level", 0)) in [1,16] else ("tracking" if int(row.get("level", 0)) in [14,15] else "mixed")
			seconds[key] += clampf(float(row.get("seconds", 0)), 0, 1800)
		focus = "mixed"
		for key in seconds:
			if seconds[key] > seconds[focus]: focus = key
		if seconds[focus] > 0: reason = "按最近已结算训练的累计时长推测，可自由换一套"
	var order: Array = [focus]
	for key in TRACKS:
		if key != focus: order.append(key)
	candidates.clear()
	for key in order:
		var steps: Array = TRACKS[key].duplicate(true)
		for step in steps: step["seconds"] = clampi(minutes, 3, 30) * 20
		candidates.append({"id": key, "title": {"laser": "镭射与反应", "tracking": "跟枪进阶", "mixed": "轻量综合"}[key], "reason": reason if key == focus else "另一种练法，随时可选择", "steps": steps})
	changed.emit()
	return candidates.duplicate(true)


func install_custom(raw: Variant, title: String, begin: bool) -> Dictionary:
	if not raw is Array or raw.is_empty() or raw.size() > 8:
		return {"ok":false,"text":"路线段数无效，当前训练没变。"}
	var steps: Array = []
	var total := 0
	var names: Array = game.get_node("Companion").commands.NAMES
	for row in raw:
		if not row is Dictionary or not row.get("level") is float and not row.get("level") is int:
			return {"ok":false,"text":"关卡参数无效，当前训练没变。"}
		var level := int(row.level)
		var seconds := int(row.get("seconds",0))
		if float(row.level) != level or not game.LEVELS.has(level) or level == 12 or seconds < 30 or seconds > 600:
			return {"ok":false,"text":"路线包含无效关卡或时长，当前训练没变。"}
		total += seconds
		steps.append({"level":level,"title":names[level],"seconds":seconds,"weapon":"awm" if row.get("weapon") == "awm" else "rifle","laser":level==0,"goal":str(row.get("goal", "按自己的节奏练习")).left(100)})
	if total > 3600: return {"ok":false,"text":"路线超过一小时，请分成两次安排。"}
	var route := {"id":"custom","title":title.left(60),"reason":"按本轮对话的具体顺序和时长编排","steps":steps}
	candidates = candidates.filter(func(r): return r.id != "custom")
	candidates.push_front(route)
	changed.emit()
	if begin:
		var ok := start_route("custom")
		return {"ok":ok,"text":"开始了：%s，先练%s %s分钟。每段结束仍由你确认是否继续。" % [route.title, steps[0].title, str(steps[0].seconds / 60.0)]}
	return {"ok":true,"text":"已准备%s，共%d段、%s分钟，还没有开始。F7里可以查看并选择。" % [route.title, steps.size(), str(total / 60.0)]}

func start_route(id: String) -> bool:
	for route in candidates:
		if route.id == id:
			active = route.duplicate(true)
			step_index = 0
			suspended = false
			_start_step()
			return true
	return false

func _start_step() -> void:
	pending = false
	deferred_prompt = false
	step_elapsed = 0
	switching = true
	game.start_session(int(active.steps[step_index].level))
	switching = false
	# Drill ready hooks are deferred; configure after their own weapon setup.
	call_deferred("_configure_step")
	status = "%s · %d/%d · %s" % [active.title, step_index + 1, active.steps.size(), active.steps[step_index].title]
	changed.emit()

func _configure_step() -> void:
	if active.is_empty(): return
	var step: Dictionary = active.steps[step_index]
	game.session_length = float(step.seconds)
	game.player.weapon.equip(game.AWM if step.weapon == "awm" else game.RIFLE)
	game.player.weapon.laser_mode = step.laser
	if game.level.get("session_context") != null:
		game.level.session_context.begin(game.player)

func owns_session() -> bool:
	return not active.is_empty()

func on_manual_session() -> void:
	if not switching and not active.is_empty(): stop("已退出路线 · 按手动选择练习")

func stop(reason: String = "路线已结束，当前练习保持") -> void:
	active.clear()
	pending = false
	deferred_prompt = false
	suspended = false
	status = reason
	if game.running:
		game.session_length = maxf(game.elapsed + 60, 90)
	changed.emit()

func _process(delta: float) -> void:
	if active.is_empty() or suspended or get_tree().paused or not game.running: return
	step_elapsed += delta
	if pending:
		# Typing and overlays preserve the response window without stealing input.
		if not game.player.controls_blocked:
			prompt_remaining = maxf(0, prompt_remaining - delta)
			if prompt_remaining <= 0:
				pending = false
				deferred_prompt = true
				status = "没关系，继续当前练习 · F7 路线页可再次提示"
				changed.emit()
	elif not deferred_prompt and step_elapsed >= float(active.steps[step_index].seconds):
		request_next()

func request_next() -> void:
	if active.is_empty(): return
	pending = true
	deferred_prompt = false
	prompt_remaining = PROMPT_SECONDS
	changed.emit()

func prompt_text() -> String:
	if active.is_empty(): return ""
	var next := "完成路线并留在当前训练" if step_index + 1 >= active.steps.size() else "接着练「%s」" % active.steps[step_index + 1].title
	return "这段练到时间啦，要%s吗？\n按 Y 确认 · N 继续练 · %d 秒后继续当前关" % [next, ceili(prompt_remaining)]

func accept_next() -> void:
	if not pending or prompt_remaining <= 0 or active.is_empty(): return
	game.record_training(true)
	step_index += 1
	if step_index >= active.steps.size():
		stop("整套路线完成 · 辛苦啦，休息或自由练都可以")
		game.get_node("Companion").say(status, "local", "cheer")
	else:
		_start_step()

func decline_next() -> void:
	pending = false
	deferred_prompt = true
	status = "继续当前关 · 想换关时在 F7 路线页再次提示"
	changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not pending or suspended or get_tree().paused or game.player.controls_blocked or not game.running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Y:
			accept_next()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_N:
			decline_next()
			get_viewport().set_input_as_handled()

func context() -> Dictionary:
	return {"candidates": candidates.duplicate(true), "active": active.duplicate(true), "step": step_index, "elapsed": step_elapsed, "pending": pending, "suspended": suspended, "status": status}
