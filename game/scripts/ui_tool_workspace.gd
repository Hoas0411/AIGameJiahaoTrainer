extends Control

# Presentation consumes the existing route and companion controllers.
var owner_ui: Node
var routes: Node
var companion: Node
var selected_route := 0
var clock := 0.0

func setup(ui: Node) -> void:
	owner_ui = ui
	routes = ui.game.get_node("CompanionRoutes")
	companion = ui.companion
	size = Vector2(1600, 900)
	add_child(UIAppearance.skin("tools"))
	for value in ["按偏好推荐", "AWM 镭射", "跟枪", "综合"]:
		$Root/Focus.add_item(value)
	$Root/Close.pressed.connect(owner_ui.close_panel)
	$Root/BackChat.pressed.connect(func(): owner_ui.show_preferences(false))
	$Root/Generate.pressed.connect(func():
		selected_route = 0
		routes.build(["", "laser", "tracking", "mixed"][$Root/Focus.selected], int($Root/Duration.value)))
	for index in 3:
		get_node("Root/Route%d" % index).pressed.connect(func(): selected_route = index; refresh())
	$Root/Start.pressed.connect(start_selected)
	$Root/Pause.pressed.connect(func():
		if routes.owns_session():
			routes.suspended = not routes.suspended
			routes.changed.emit())
	$Root/Stop.pressed.connect(func(): routes.stop("路线已结束 · 当前练习保留"))
	$Root/Next.pressed.connect(func():
		if routes.owns_session():
			routes.request_next()
			owner_ui.close_panel())
	if $Root.has_node("DataToggle"):
		$Root/DataToggle.pressed.connect(func(): show_data(not $Root/Records.visible))
	routes.changed.connect(refresh)
	companion.changed.connect(refresh_trace)
	if routes.candidates.is_empty(): routes.build()
	refresh()

func show_data(value: bool) -> void:
	if not $Root.has_node("DataToggle"): return
	if not $Root/DataToggle.has_meta("home_position"):
		$Root/DataToggle.set_meta("home_position", $Root/DataToggle.position)
	$Root/DataToggle.position = Vector2(1040, 142) if value else $Root/DataToggle.get_meta("home_position")
	$Root.move_child($Root/DataToggle, $Root.get_child_count() - 1)
	for name in ["Records", "ToolTrace", "DataShade", "DataFrame", "DataBackdrop"]:
		if $Root.has_node(name): $Root.get_node(name).visible = value
	$Root/DataToggle.text = "返回训练计划" if value else "训练记录 / 调用"
	if value: refresh_records(); refresh_trace()

func start_selected() -> void:
	if selected_route >= routes.candidates.size(): return
	var route_id: String = routes.candidates[selected_route].id
	owner_ui.close_panel()
	if not routes.start_route(route_id):
		owner_ui.open_panel()
		owner_ui.show_tools()
		$Root/State.text = "未能开始这条路线，请重新编排。"

func refresh() -> void:
	if not has_node("Root"): return
	for index in 3:
		var button: Button = get_node("Root/Route%d" % index)
		button.disabled = index >= routes.candidates.size()
		button.text = str(routes.candidates[index].title) if not button.disabled else "暂无方案"
		if UIAppearance.selected == 0 and not button.disabled:
			button.text += "\n" + str(routes.candidates[index].reason)
		button.set_pressed_no_signal(index == selected_route)
	$Root/Start.disabled = routes.candidates.is_empty()
	if not routes.candidates.is_empty():
		selected_route = clampi(selected_route, 0, routes.candidates.size() - 1)
		var plan: Dictionary = routes.candidates[selected_route]
		$Root/Start.text = "开始路线" if routes.active.is_empty() else ("重新开始" if routes.active.id == plan.id else "切换路线")
		$Root/PlanTitle.text = plan.title
		$Root/PlanReason.text = plan.reason
		$Root/Steps.clear()
		for index in plan.steps.size():
			var step: Dictionary = plan.steps[index]
			var state := "待开始"
			if not routes.active.is_empty() and routes.active.id == plan.id:
				state = "已结束" if index < routes.step_index else ("当前段" if index == routes.step_index else "待下一段")
			$Root/Steps.push_color(UIAppearance.accent())
			$Root/Steps.add_text("%02d  %s  ·  %s\n" % [index + 1, step.title, state])
			$Root/Steps.pop()
			$Root/Steps.add_text("%d:%02d  ·  %s%s\n" % [int(step.seconds) / 60, int(step.seconds) % 60, "AWM" if step.weapon == "awm" else "步枪", " · 镭射" if step.laser else ""])
			$Root/Steps.push_font_size(19)
			$Root/Steps.add_text(str(step.goal) + "\n")
			$Root/Steps.pop()
	refresh_state()
	refresh_records()
	refresh_trace()

func refresh_state() -> void:
	$Root/State.text = ("路线计时暂停 · " if routes.suspended else "") + routes.status
	if routes.owns_session():
		$Root/State.text += "\n当前段已进行 %d:%02d · 打开面板时训练暂停" % [int(routes.step_elapsed) / 60, int(routes.step_elapsed) % 60]
	$Root/Pause.text = "继续" if routes.suspended else "暂停"
	for node in [$Root/Pause, $Root/Stop, $Root/Next]: node.disabled = not routes.owns_session()
	$Root/Stop.tooltip_text = "结束后续路线，保留当前练习。"
	$Root/Stop.text = "结束"
	$Root/Next.text = "下一段"
	$Root/Next.tooltip_text = "返回训练并重新询问是否进入下一段。"

func refresh_records() -> void:
	var rows: Array = companion.history()
	var log: RichTextLabel = $Root/Records
	log.clear()
	log.add_text("最近结算 · 最多 5 轮\n\n")
	if rows.is_empty():
		log.add_text("暂无已结算训练。\n完成一轮后，这里会显示实际记录。\n\n能力雷达图尚未定义指标，当前不生成评分。")
		return
	var recent := rows.slice(-5)
	recent.reverse()
	for row in recent:
		if not row is Dictionary: continue
		var stamp := "时间未记录"
		if row.has("unix_time"):
			stamp = Time.get_datetime_string_from_unix_time(int(row.unix_time)).replace("T", " ") + " UTC"
		var shots := int(row.get("shots", 0))
		var hits := int(row.get("hits", 0))
		var accuracy := "未测" if shots == 0 else "%.1f%%" % (100.0 * hits / shots)
		log.push_color(UIAppearance.accent())
		log.add_text("第 %d 关 · %d 秒\n" % [int(row.get("level", 0)), int(row.get("seconds", 0))])
		log.pop()
		log.push_font_size(17)
		log.add_text(stamp + "\n")
		log.pop()
		log.add_text("命中 %d / 射击 %d · %s\n击倒 %d\n\n" % [hits, shots, accuracy, int(row.get("kills", 0))])
	log.add_text("不同关卡不直接合成能力评分。")

func refresh_trace() -> void:
	if not has_node("Root"): return
	$Root/ToolTrace.clear()
	if companion.busy:
		$Root/ToolTrace.add_text("正在等待 AI 回复\n尚无本次调用结果。")
		return
	var names := {"read_training":"读取训练记录", "read_memories":"读取记忆", "read_companion_state":"读取陪伴偏好", "learn_preference":"理解明确偏好", "read_routes":"读取路线", "plan_training":"编排候选路线", "propose_memory":"提议记忆（待确认）", "stop_route":"结束路线"}
	$Root/ToolTrace.add_text("最近报告的调用\n")
	if companion.last_tools.is_empty():
		$Root/ToolTrace.add_text("暂无工具调用记录。")
	else:
		for item in companion.last_tools:
			$Root/ToolTrace.add_text("· " + str(names.get(str(item), str(item))) + "\n")
	$Root/ToolTrace.add_text("\n" + companion.status)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not has_node("Root"): return
	clock += delta
	if clock > 0.5:
		clock = 0
		refresh_state()
