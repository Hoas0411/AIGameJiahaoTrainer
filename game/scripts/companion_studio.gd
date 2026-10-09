extends MarginContainer

var owner_ui: Node
var companion: Node
var routes: Node
var state_label: Label
var preference_log: RichTextLabel
var route_box: VBoxContainer
var route_status: Label
var duration: SpinBox
var focus: OptionButton
var persona_buttons: Array[Button] = []
var tabs: TabContainer

func label(text: String, font_size: int = 18) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item

func button(text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 42
	item.pressed.connect(callback)
	return item

func setup(ui: Node) -> void:
	owner_ui = ui
	companion = ui.companion
	routes = ui.game.get_node("CompanionRoutes")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: add_theme_constant_override("margin_" + edge, 28)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := label("麦小鼠   /   慢慢了解你", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("聊天与连接", func(): owner_ui.show_preferences(false)))
	header.add_child(button("返回训练  Esc", ui.close_panel))
	state_label = label("")
	state_label.add_theme_color_override("font_color", Color("8162ad") if UIAppearance.selected == 0 else Color("cfbaff"))
	column.add_child(state_label)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var cultivate := VBoxContainer.new()
	cultivate.name = "相处与培养"
	cultivate.add_theme_constant_override("separation", 14)
	tabs.add_child(cultivate)
	cultivate.add_child(label("今天，希望我怎样陪你？", 23))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	cultivate.add_child(cards)
	var details := ["先听你说，再一起想办法", "轻松接梗，为具体瞬间雀跃", "话少一点，给清楚的下一步"]
	for i in 3:
		var name_value: String = companion.mind.PERSONAS[i]
		var card := button(name_value + "\n" + details[i], func():
			companion.invalidate()
			companion.mind.persona = name_value
			companion.profile.style = ["温柔具体", "活泼夸夸", "安静简短"][i]
			companion.mind.set_preference("style", companion.profile.style, "玩家选择" + name_value)
			companion.save_state()
			companion.changed.emit())
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 98)
		card.add_theme_font_size_override("font_size", 16)
		cards.add_child(card)
		persona_buttons.append(card)
	cultivate.add_child(label("我目前理解的你", 22))
	cultivate.add_child(label("可以直接对我说「训练时少说话」「先陪我，别讲道理」「以后叫我阿豪」。", 17))
	preference_log = RichTextLabel.new()
	preference_log.custom_minimum_size.y = 180
	preference_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cultivate.add_child(preference_log)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	cultivate.add_child(actions)
	actions.add_child(button("先陪我聊聊", func():
		companion.mind.set_preference("service", "先陪伴，暂不建议训练", "玩家在培养页选择")
		companion.save_state(); companion.changed.emit()))
	actions.add_child(button("陪我训练", func():
		companion.mind.set_preference("service", "陪伴与训练建议", "玩家在培养页选择")
		companion.save_state(); companion.changed.emit(); tabs.current_tab = 1))
	actions.add_child(button("重置培养偏好", func():
		companion.invalidate()
		companion.mind.preferences.clear()
		companion.mind.last_topic = ""
		companion.profile.style = ["温柔具体", "活泼夸夸", "安静简短"][companion.mind.PERSONAS.find(companion.mind.persona)]
		companion.save_state(); companion.changed.emit()))
	cultivate.add_child(label("情绪会随聊天与训练变化，也会慢慢平复。这里展示的是角色表现；你随时可以改变相处方式。", 15))
	var training := VBoxContainer.new()
	training.name = "训练路线"
	training.add_theme_constant_override("separation", 12)
	tabs.add_child(training)
	training.add_child(label("一起练一套，或者只练喜欢的那一段", 22))
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	training.add_child(controls)
	focus = OptionButton.new()
	for text in ["按偏好推荐", "AWM 镭射", "跟枪", "综合"]: focus.add_item(text)
	controls.add_child(focus)
	var duration_label := label("总时长 / 分钟")
	duration_label.custom_minimum_size.x = 140
	duration_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	controls.add_child(duration_label)
	duration = SpinBox.new()
	duration.min_value = 3; duration.max_value = 30; duration.value = 15; duration.step = 3
	duration.custom_minimum_size.x = 110
	controls.add_child(duration)
	controls.add_child(button("重新编排三套", func(): routes.build(["", "laser", "tracking", "mixed"][focus.selected], int(duration.value))))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	training.add_child(scroll)
	route_box = VBoxContainer.new()
	route_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_box.add_theme_constant_override("separation", 14)
	scroll.add_child(route_box)
	route_status = label("")
	training.add_child(route_status)
	var route_actions := HBoxContainer.new()
	route_actions.add_theme_constant_override("separation", 12)
	training.add_child(route_actions)
	route_actions.add_child(button("再次提示下一段", func(): if routes.owns_session(): routes.request_next(); owner_ui.close_panel()))
	route_actions.add_child(button("暂停 / 继续路线计时", func(): routes.suspended = not routes.suspended; routes.changed.emit()))
	route_actions.add_child(button("停止路线", func(): routes.stop()))
	training.add_child(label("到时由麦小鼠在右下角问你：Y 下一段 / N 继续练。15 秒未回应就留在原关，不弹出全屏提示。", 16))
	companion.changed.connect(refresh)
	routes.changed.connect(refresh_routes)
	if routes.candidates.is_empty(): routes.build()
	refresh()
	refresh_routes()

func refresh() -> void:
	if not is_instance_valid(state_label): return
	state_label.text = "%s  ·  %s  /  %s" % [companion.mind.persona, companion.mind.emotion, "模型对话已启用" if companion.ai_enabled else "离线陪伴"]
	for i in persona_buttons.size(): persona_buttons[i].modulate = Color("d6c1ff") if companion.mind.persona == companion.mind.PERSONAS[i] else Color.WHITE
	preference_log.text = ""
	for key in companion.mind.preferences:
		var p: Dictionary = companion.mind.preferences[key]
		var key_title: String = {"service": "陪伴方式", "style": "说话风格", "focus": "训练偏好", "address": "称呼"}.get(key, key)
		var displayed: String = {"tracking":"跟枪", "laser":"AWM 镭射", "mixed":"综合"}.get(str(p.value), str(p.value))
		preference_log.add_text("%s · %s\n来自你说的：%s\n\n" % [key_title, displayed if displayed != "" else "不用昵称", p.source])
	if companion.mind.preferences.is_empty(): preference_log.text = "还没有培养偏好。聊几句，让我了解你希望怎样被陪伴。\n长期记忆仍由你在聊天页确认保存。"

func refresh_routes() -> void:
	if not is_instance_valid(route_box): return
	for child in route_box.get_children(): route_box.remove_child(child); child.queue_free()
	for route in routes.candidates:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		route_box.add_child(row)
		row.add_child(label(route.title + "   ·   " + route.reason, 17))
		var steps := HBoxContainer.new()
		steps.add_theme_constant_override("separation", 20)
		row.add_child(steps)
		for index in route.steps.size():
			var step: Dictionary = route.steps[index]
			var description := label("%d  %s  ·  %d:%02d\n%s" % [index + 1, step.title, int(step.seconds) / 60, int(step.seconds) % 60, step.goal], 16)
			description.custom_minimum_size.y = 64
			description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			steps.add_child(description)
		var route_id: String = route.id
		row.add_child(button("开始「%s」" % route.title, func(): owner_ui.close_panel(); routes.start_route(route_id)))
	route_status.text = ("计时暂停 · " if routes.suspended else "") + routes.status
