extends RefCounted

# Only this adapter maps conversational targets onto the game's real level list.
const COURSES = preload("res://scripts/course_registry.gd")
const NAMES = COURSES.NAMES
const ALIASES = {"镭射": 0, "雷射": 0, "激光": 0, "awm": 0, "aw": 0, "靶场": 6, "距离": 6, "控枪": 6, "反应训练": 7, "随机反应": 7, "valorant": 7, "高低差": 8, "基地": 12, "大厅": 12, "平滑": 13, "跟枪": 13, "跟随移动射击": 13, "中门": 15, "架门缝": 15, "门缝": 15, "三球": 19, "gridshot": 19}
var awaiting_target := false
var asked_at := 0

func catalog() -> Array:
	var rows: Array = []
	for index in game_level_ids(): rows.append({"id":index,"name":NAMES[index]})
	return rows

func game_level_ids() -> Array[int]:
	return [0,6,7,8,12,13,15,19]

func adjacent_level(current: int, direction: int, ids: Array[int]) -> int:
	var position := ids.find(current)
	if position < 0: position = 0
	return ids[posmod(position + direction, ids.size())]

func matches(text: String, pattern: String) -> bool:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(text) != null

func is_command(text: String) -> bool:
	return matches(text.to_lower(), "切换|换关|换个|换一|下一关|下一段|上一个关|上一关|带我|带咱|去.*练|开始.*练|进入|返回大厅|回大厅|(停止|取消|结束|暂停|继续|开始|按).*路线")

func resolve_target(text: String) -> int:
	var lower := text.to_lower()
	# Specific multiword names beat a generic 'tracking' mention.
	for index in game_level_ids():
		if NAMES[index].to_lower() in lower: return index
	var longest := 0
	var found := -1
	for alias in ALIASES:
		if alias in lower and alias.length() > longest:
			longest = alias.length(); found = ALIASES[alias]
	var number := RegEx.new()
	number.compile("第?\\s*(\\d+)\\s*(关|号)")
	var hit := number.search(lower)
	if hit: return int(hit.get_string(1)) - 1
	for index in ["一","二","三","四","五","六","七","八","九","十"].size():
		if "第" + ["一","二","三","四","五","六","七","八","九","十"][index] + "关" in text: return index
	return found

func interpret(text: String, game: Node) -> Dictionary:
	if awaiting_target and Time.get_ticks_msec() - asked_at > 90000: awaiting_target = false
	var was_awaiting := awaiting_target
	var lower := text.to_lower().strip_edges()
	var online: bool = game.get_node("Companion").ai_enabled
	var target := resolve_target(lower)
	var bare_target := target >= 0 and lower.length() <= 16 and not matches(lower,"[？?]|为什么|喜欢|讨厌|不想|不要|别|怎么|什么|比|和|还是")
	var delegated := matches(lower,"^(你选吧?|你定吧?|都行|随便|听你的)[。！! ]*$")
	# A clarification owns at most one relevant reply, never the entire conversation.
	awaiting_target = false
	if was_awaiting and matches(lower,"^(算了|取消|先不换|不换了)[。！! ]*$"):
		return {"kind":"reply","text":"好，先不换。"}
	if matches(lower,"换.*(话题|称呼|名字|衣服|人设|性格|说法)"): return {}
	var complex := matches(lower,"然后|再练|之后|接着|先.*再|但是|而是|不过|不要.*[，,]|不想.*[，,]|别.*[，,]|分钟.*分钟|分别|依次|轮流|各练|先.*分钟|练.*分钟")
	if complex:
		return {} if online else {"kind":"reply","text":"我现在处于离线模式，不能可靠拆解这段复杂安排。可以逐项说‘去三球定位’；开启模型后我再帮你编排。"}
	if matches(lower,"怎么|如何|为什么|假如|假设|如果|能不能.*换关|能.*换关吗|会.*换关吗|有.*换关.*能力"): return {}
	if matches(lower,"别.*(切|换|进|开始|停止|暂停|继续|取消|结束)|不(要|用|想).*?(切|换|去|开始|停止|暂停|继续|取消|结束)|先不|取消换关"):
		return {"kind":"reply","text":"好，留在这里。"} if is_command(lower) or was_awaiting else {}
	var intent := is_command(lower) or matches(lower,"(切|换|去|进|练|开).*(关|镭射|激光|靶场|跟枪|中门|定位|gridshot|awm)")
	if was_awaiting and (bare_target or delegated): intent = true
	if not intent: return {}
	if "路线" in lower:
		if matches(lower,"停止|取消|结束"): return {"kind":"stop_route"}
		if "暂停" in lower: return {"kind":"pause_route"}
		if "继续" in lower: return {"kind":"resume_route"}
		if matches(lower,"开始|就选|按.*练"):
			var focus := "tracking" if "跟枪" in lower else ("laser" if matches(lower,"镭射|awm|激光") else "mixed")
			var duration := RegEx.new()
			duration.compile("(\\d+)\\s*分钟")
			var found := duration.search(lower)
			return {"kind":"start_route","focus":focus,"minutes":clampi(int(found.get_string(1)),3,30) if found else 15}
		return {}
	if matches(lower,"下一段|下一关|下一个关") and game.get_node("CompanionRoutes").owns_session(): return {"kind":"next_route"}
	if matches(lower,"下一关|下一个关"): target = adjacent_level(game.level_index, 1, game.LEVEL_IDS)
	if matches(lower,"上一关|上一个关"): target = adjacent_level(game.level_index, -1, game.LEVEL_IDS)
	if was_awaiting and delegated:
		var candidates: Array = game.get_node("CompanionRoutes").build()
		target = candidates[0].steps[0].level
		if target == game.level_index: target = candidates[1].steps[0].level
	if target in game.LEVEL_IDS: return {"kind":"switch_level","level":target}
	# Only an explicit bare switch request opens clarification; descriptive language goes to the model.
	if target == -1 and online and matches(lower,"那个|那种|项目|模式|不断|目标"): return {}
	if not matches(lower,"切换|换关|换个关|换一关|第.*关"): return {}
	awaiting_target = true
	asked_at = Time.get_ticks_msec()
	return {"kind":"reply","text":"想去哪一关？你可以告诉我名字、描述玩法，或者让我推荐。" if target == -1 else "这个编号不在目录里。告诉我关卡名吧。"}

func execute(command: Dictionary, game: Node) -> Dictionary:
	var routes: Node = game.get_node("CompanionRoutes")
	var kind: String = command.get("kind", "")
	if kind == "reply": return {"ok":true,"tool":"clarify_level","text":command.text}
	if kind in ["switch_level", "start_route", "next_route", "start_custom_route"]:
		var panel: Node = game.get_node("CompanionUI")
		if panel.box.visible: panel.close_panel()
		game.get_node("BubbleUI").close_input()
	if kind == "switch_level":
		var value: Variant = command.get("level", -1)
		if not (value is int or value is float) or float(value) != floorf(float(value)):
			return {"ok":false,"tool":kind,"text":"关卡编号无效，我没有切换。"}
		var index: int = command.get("level", -1)
		if not game.LEVELS.has(index): return {"ok":false,"tool":kind,"text":"这个关卡不在训练目录里，我没有切换。"}
		if game.running and (game.elapsed > 1 or game.shots > 0) and game.level_index != 12: game.record_training(false)
		game.start_session(index)
		return {"ok":game.running and game.level_index == index,"tool":kind,"level":index,"text":"到啦，%s。" % NAMES[index]}
	if kind in ["start_custom_route", "prepare_custom_route"]:
		var result: Dictionary = routes.install_custom(command.get("steps", []), str(command.get("title", "本次训练")), kind == "start_custom_route")
		return {"ok":result.ok,"tool":kind,"text":result.text}
	if kind == "next_route":
		if not routes.owns_session(): return {"ok":false,"tool":kind,"text":"现在没有正在进行的路线。"}
		routes.request_next(); routes.accept_next()
		return {"ok":true,"tool":kind,"text":"这套练完了，可以自由练或歇会儿。" if not routes.owns_session() else "到啦，%s。" % NAMES[game.level_index]}
	if kind == "start_route":
		routes.build(command.focus, int(command.get("minutes",15)))
		var ok: bool = routes.start_route(command.focus)
		return {"ok":ok,"tool":kind,"text":"开始了，先练%s。每段结束我会问你要不要继续。" % NAMES[game.level_index]}
	if kind == "stop_route": routes.stop(); return {"ok":true,"tool":kind,"text":"路线停了，这一关还能继续练。"}
	if kind in ["pause_route","resume_route"]:
		if not routes.owns_session(): return {"ok":false,"tool":kind,"text":"现在没有正在进行的路线。想练哪套？"}
		routes.suspended = kind == "pause_route"; routes.changed.emit()
		return {"ok":true,"tool":kind,"text":"路线计时暂停了。" if routes.suspended else "好，路线接着计时。"}
	return {"ok":false,"tool":kind,"text":"这项操作还不能执行，当前训练没变。"}
