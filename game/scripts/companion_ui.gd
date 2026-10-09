extends CanvasLayer

@onready var game: Node = get_parent()
@onready var companion: Node = game.get_node("Companion")
var box: Control
var fields: Node
var chat_box: Node
var was_paused: bool = false
var old_mouse: int = Input.MOUSE_MODE_VISIBLE
var toast_time: float = 0
var studio: Control
var tools_workspace: Control
var history_open := false
var writing_open := false
var message_signature := ""

func _ready() -> void:
	build_skin()
	UIAppearance.changed.connect(build_skin)
	companion.changed.connect(refresh)
	companion.reply_received.connect(on_reply)

func build_skin() -> void:
	var opened := false
	var settings_open := false
	var draft := ""
	var values := {}
	var scroll := 0.0
	var tools_open := false
	var workspace_values := {}
	if has_node("Root"):
		tools_open = is_instance_valid(tools_workspace) and tools_workspace.visible
		if tools_open:
			workspace_values = {"selected": tools_workspace.selected_route, "focus": tools_workspace.get_node("Root/Focus").selected, "minutes": tools_workspace.get_node("Root/Duration").value}
		opened = box.visible
		settings_open = fields.visible
		draft = chat_box.get_node("Input").text
		scroll = chat_box.get_node("Log").get_v_scroll_bar().value
		for key in ["Role", "Style", "Partner"]:
			values[key] = fields.get_node(key).selected
		for key in ["Address", "Memories"]:
			values[key] = fields.get_node(key).text
		for key in ["AI", "Enabled"]:
			values[key] = fields.get_node(key).button_pressed
		var previous := $Root
		remove_child(previous)
		previous.queue_free()
		studio = null
		tools_workspace = null
	add_child(UIAppearance.skin("companion"))
	message_signature = ""
	box = $Root/Panel
	fields = $Root/Panel/Margin/Columns/Preferences
	chat_box = $Root/Panel/Margin/Columns/Chat
	box.visible = opened
	$Root/Shade.visible = opened
	UIAppearance.bind_selector($Root/Panel/Appearance)
	$Root/Panel/Settings.pressed.connect(func(): show_preferences(not fields.visible))
	fields.get_node("Back").pressed.connect(func(): show_preferences(false))
	$Root/Open.text = "麦小鼠 / H"
	$Root/Open.pressed.connect(open_panel)
	chat_box.get_node("Close").pressed.connect(close_panel)
	chat_box.get_node("Send").pressed.connect(send_message)
	chat_box.get_node("Input").text_submitted.connect(func(_text): send_message())
	fields.get_node("Save").pressed.connect(save_preferences)
	fields.get_node("AI").toggled.connect(func(value): companion.set_ai_enabled(value))
	fields.get_node("Enabled").toggled.connect(func(value): companion.enabled = value; companion.save_state(); game.get_node("CompanionActor").reset_position())
	fields.get_node("Reconnect").pressed.connect(func(): companion.connect_ai())
	chat_box.get_node("Summon").pressed.connect(func():
		companion.enabled = true
		companion.save_state()
		fields.get_node("Enabled").set_pressed_no_signal(true)
		game.get_node("CompanionActor").reset_position()
		close_panel())
	fields.get_node("ForgetChat").pressed.connect(func(): companion.invalidate(); companion.conversation.clear(); companion.save_state(); refresh())
	chat_box.get_node("Remember").pressed.connect(func(): companion.confirm_memory(); fields.get_node("Memories").text = "\n".join(companion.memories); refresh())
	for value in ["男威龙", "女威龙"]:
		fields.get_node("Role").add_item(value)
	for value in ["温柔具体", "活泼夸夸", "轻松调侃", "安静简短"]:
		fields.get_node("Style").add_item(value)
	for value in ["女友陪伴", "男友陪伴", "训练搭档"]:
		fields.get_node("Partner").add_item(value)
	for key in values:
		if key in ["Role", "Style", "Partner"]:
			fields.get_node(key).select(values[key])
		elif key in ["AI", "Enabled"]:
			fields.get_node(key).set_pressed_no_signal(values[key])
		else:
			fields.get_node(key).text = values[key]
	chat_box.get_node("Input").text = draft
	chat_box.get_node("Studio").pressed.connect(show_studio)
	chat_box.get_node("Tools").pressed.connect(show_tools)
	chat_box.get_node("History").pressed.connect(func(): history_open = not history_open; refresh_reading_mode())
	for path in ["Margin/Columns/LeftRail/Create", "Margin/Columns/LeftRail/CurrentChat", "Margin/Columns/RightRail/NewChat"]:
		var button := box.get_node_or_null(path) as Button
		if button:
			button.pressed.connect(func():
				show_preferences(false)
				history_open = false
				refresh_reading_mode()
				chat_box.get_node("Input").grab_focus())
	var rail_history := box.get_node_or_null("Margin/Columns/RightRail/RightHistory") as Button
	if rail_history:
		rail_history.pressed.connect(func():
			show_preferences(false)
			history_open = not history_open
			refresh_reading_mode())
	var rail_persona := box.get_node_or_null("Margin/Columns/RightRail/RightPersona") as Button
	if rail_persona: rail_persona.pressed.connect(func(): show_preferences(true))
	if chat_box.has_node("Write"):
		chat_box.get_node("Write").pressed.connect(toggle_writing)
	if fields.has_node("Cultivate"):
		fields.get_node("Cultivate").pressed.connect(show_studio)
	show_preferences(settings_open)
	refresh()
	if tools_open:
		show_tools()
		tools_workspace.selected_route = workspace_values.selected
		tools_workspace.get_node("Root/Focus").select(workspace_values.focus)
		tools_workspace.get_node("Root/Duration").value = workspace_values.minutes
		tools_workspace.refresh()
	chat_box.get_node("Log").get_v_scroll_bar().set_deferred("value", scroll)
	if opened and not settings_open and chat_box.get_node("Input").visible:
		chat_box.get_node("Input").grab_focus()

func show_preferences(value: bool) -> void:
	if is_instance_valid(studio): studio.hide()
	if is_instance_valid(tools_workspace): tools_workspace.hide()
	box.get_node("Margin").show()
	$Root/Panel/Appearance.show()
	$Root/Panel/Settings.show()
	fields.visible = value
	chat_box.visible = not value
	$Root/Panel/Settings.text = "回到对话" if value else "相处方式"
	if not value and box.visible:
		if chat_box.get_node("Input").visible: chat_box.get_node("Input").grab_focus()

func toggle_writing() -> void:
	writing_open = not writing_open
	history_open = false
	refresh_reading_mode()
	if writing_open: chat_box.get_node("Input").grab_focus()

func show_studio() -> void:
	if is_instance_valid(tools_workspace): tools_workspace.hide()
	if not is_instance_valid(studio):
		studio = preload("res://scripts/companion_studio.gd").new()
		box.add_child(studio)
		studio.setup(self)
		studio.tabs.set_tab_title(1, "训练操作台")
		studio.tabs.tab_changed.connect(func(index):
			if index == 1: show_tools())
	studio.tabs.current_tab = 0
	$Root/Panel/Appearance.hide()
	$Root/Panel/Settings.hide()
	box.get_node("Margin").hide()
	studio.show()
	studio.refresh()
	style_studio()

func style_studio() -> void:
	if not is_instance_valid(studio): return
	studio.state_label.add_theme_color_override("font_color", UIAppearance.accent())
	for index in studio.persona_buttons.size():
		var button: Button = studio.persona_buttons[index]
		button.modulate = Color.WHITE
		button.theme_type_variation = &"IndexButton"
		button.toggle_mode = true
		button.set_pressed_no_signal(companion.mind.persona == companion.mind.PERSONAS[index])

func show_tools() -> void:
	if is_instance_valid(studio): studio.hide()
	if not is_instance_valid(tools_workspace):
		tools_workspace = preload("res://scripts/ui_tool_workspace.gd").new()
		tools_workspace.name = "ToolWorkspace"
		box.add_child(tools_workspace)
		tools_workspace.setup(self)
	box.get_node("Margin").hide()
	$Root/Panel/Appearance.hide()
	$Root/Panel/Settings.hide()
	tools_workspace.show()
	tools_workspace.refresh()

func refresh_reading_mode() -> void:
	if UIAppearance.selected == 2:
		for n in ["Portrait", "NamePlate", "NamePlateGraphic", "DialogueFrame", "Latest", "InputFrame", "Input", "Send"]:
			chat_box.get_node(n).visible = not history_open
		chat_box.get_node("Log").visible = history_open
		chat_box.get_node("HistoryBackdrop").visible = history_open
		chat_box.get_node("History").text = "回到对话" if history_open else "历史记录"
		chat_box.get_node("Write").hide()
		return
	var ink := UIAppearance.selected == 1
	chat_box.get_node("Log").visible = history_open
	chat_box.get_node("Latest").visible = ink and not history_open and not writing_open
	if chat_box.has_node("ReplyTime"):
		chat_box.get_node("ReplyTime").visible = ink and not history_open and not writing_open and not companion.busy and companion.last_reply_latency_ms > 0 and not companion.conversation.is_empty() and companion.conversation.back().get("source", "") == "ai"
	chat_box.get_node("History").visible = true
	chat_box.get_node("History").text = "回到对话" if history_open else "聊天记录"
	if chat_box.has_node("MessageScroll"):
		chat_box.get_node("MessageScroll").visible = not history_open
	if ink:
		for name in ["Artwork", "Portrait", "NamePlate", "DialogueFrame"]:
			if chat_box.has_node(name): chat_box.get_node(name).visible = not history_open and not writing_open
		for name in ["Input", "Send", "InputShade", "InputFrame", "InputBackdrop", "InputHint"]:
			if chat_box.has_node(name): chat_box.get_node(name).visible = writing_open and not history_open
		if chat_box.has_node("HistoryShade"): chat_box.get_node("HistoryShade").visible = history_open
		if chat_box.has_node("HistoryBackdrop"): chat_box.get_node("HistoryBackdrop").visible = history_open
		if chat_box.has_node("Write"): chat_box.get_node("Write").text = "收起输入" if writing_open else "说点什么"

func select_text(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == value:
			option.select(i)

func open_panel() -> void:
	if box.visible:
		return
	game.get_node("BubbleUI").close_input()
	was_paused = get_tree().paused
	old_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	box.show()
	show_preferences(false)
	$Root/Shade.show()
	$Root/Open.hide()
	select_text(fields.get_node("Role"), companion.profile.role)
	select_text(fields.get_node("Style"), companion.profile.style)
	select_text(fields.get_node("Partner"), companion.profile.partner)
	fields.get_node("Address").text = companion.profile.address
	fields.get_node("Enabled").set_pressed_no_signal(companion.enabled)
	fields.get_node("AI").set_pressed_no_signal(companion.ai_enabled)
	fields.get_node("Memories").text = "\n".join(companion.memories)
	refresh()
	if companion.ai_enabled:
		companion.connect_ai()
	if chat_box.get_node("Input").visible: chat_box.get_node("Input").grab_focus()

func close_panel() -> void:
	box.hide()
	$Root/Shade.hide()
	$Root/Open.show()
	get_tree().paused = was_paused
	Input.mouse_mode = old_mouse

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if box.visible and event.is_action_pressed("ui_cancel"):
			if writing_open or history_open:
				writing_open = false
				history_open = false
				refresh_reading_mode()
			else: close_panel()
			get_viewport().set_input_as_handled()
		elif box.visible and UIAppearance.selected == 1 and not fields.visible and not writing_open and not history_open and event.physical_keycode == KEY_ENTER and not (is_instance_valid(tools_workspace) and tools_workspace.visible):
			toggle_writing()
			get_viewport().set_input_as_handled()
		elif not box.visible and event.physical_keycode == KEY_H and not (get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit):
			open_panel()
			get_viewport().set_input_as_handled()

func save_preferences() -> void:
	companion.configure({"role": fields.get_node("Role").get_item_text(fields.get_node("Role").selected), "style": fields.get_node("Style").get_item_text(fields.get_node("Style").selected), "partner": fields.get_node("Partner").get_item_text(fields.get_node("Partner").selected), "address": fields.get_node("Address").text.strip_edges().left(40)}, fields.get_node("Memories").text, fields.get_node("Enabled").button_pressed, fields.get_node("AI").button_pressed)
	fields.get_node("Memories").text = "\n".join(companion.memories)
	fields.get_node("Save").text = "已保存 · 修改后再点此保存"

func send_message() -> void:
	var input: LineEdit = chat_box.get_node("Input")
	if input.text.strip_edges().is_empty():
		return
	var text := input.text
	input.clear()
	writing_open = false
	companion.chat(text)
	refresh()

func refresh() -> void:
	var shown_messages: Array = companion.conversation.duplicate()
	if companion.busy and companion.current_kind == "chat":
		shown_messages.append({"role":"assistant","source":"ai","content":companion.progress_text if not companion.progress_text.is_empty() else "消息收到了，正在想…"})
	chat_box.get_node("Status").text = companion.status
	chat_box.get_node("Send").disabled = false
	fields.get_node("Reconnect").disabled = companion.checking or not companion.ai_enabled
	var log: RichTextLabel = chat_box.get_node("Log")
	if chat_box.has_node("MessageScroll/Messages"):
		var signature := JSON.stringify(shown_messages) + str(companion.busy)
		if signature != message_signature:
			var scroller: ScrollContainer = chat_box.get_node("MessageScroll")
			var scrollbar := scroller.get_v_scroll_bar()
			var stick_to_end := scrollbar.value >= scrollbar.max_value - scrollbar.page - 8
			preload("res://ui/rebuild/shared/message_flow.gd").populate(chat_box.get_node("MessageScroll/Messages"), shown_messages.slice(-40), companion.busy)
			message_signature = signature
			if stick_to_end: scroller.set_deferred("scroll_vertical", 100000)
	var old_scroll: float = log.get_v_scroll_bar().value
	var following: bool = old_scroll >= log.get_v_scroll_bar().max_value - log.get_v_scroll_bar().page - 2
	log.clear()
	if shown_messages.is_empty():
		log.add_text("今天过得怎么样？\n\n你可以从一次训练、一点进步，\n或一件想分享的小事开始。\n\n麦小鼠会在这里陪你聊。")
	for entry in shown_messages:
		var label := "你" if entry.role == "user" else ("麦小鼠 · AI" if entry.get("source") == "ai" else "麦小鼠 · 本地陪伴")
		if entry.role == "assistant" and int(entry.get("latency_ms", 0)) > 0:
			label += " · 本次回复 %.2f 秒" % (float(entry.latency_ms) / 1000.0)
		log.push_color(UIAppearance.accent())
		log.push_font_size(18)
		log.add_text(label + "\n")
		log.pop()
		log.pop()
		log.add_text(entry.content + "\n\n")
	if not following:
		log.get_v_scroll_bar().set_deferred("value", old_scroll)
	var latest: RichTextLabel = chat_box.get_node("Latest")
	latest.clear()
	if shown_messages.is_empty():
		latest.add_text("今天想从哪里聊起？\n训练里的小事，或者今天的心情，都可以。")
	else:
		var entry: Dictionary = shown_messages.back()
		latest.add_text(entry.content)
	if chat_box.has_node("ReplyTime"):
		chat_box.get_node("ReplyTime").text = "本次回复 %.2f 秒" % (float(companion.last_reply_latency_ms) / 1000.0)
	fields.get_node("Stats").text = companion.training_summary()
	chat_box.get_node("MemoryProposal").text = "待确认记忆：" + companion.pending_memory if not companion.pending_memory.is_empty() else "记忆由你决定。相处方式中可随时查看与修改。"
	chat_box.get_node("MemoryProposal").visible = UIAppearance.selected == 0 or not companion.pending_memory.is_empty()
	chat_box.get_node("Send").text = ("…" if companion.busy else "→") if UIAppearance.selected == 0 else ("发送中…" if companion.busy else "发送 →")
	chat_box.get_node("Remember").disabled = companion.pending_memory.is_empty()
	chat_box.get_node("Remember").visible = not companion.pending_memory.is_empty()
	refresh_reading_mode()
	style_studio.call_deferred()

func on_reply(text: String, source: String, action: String) -> void:
	var speed := " · 本次回复 %.2f 秒" % (float(companion.last_reply_latency_ms) / 1000.0) if source == "ai" and companion.last_reply_latency_ms > 0 else ""
	$Root/Toast.text = "麦小鼠" + (" · AI" + speed + "\n" if source == "ai" else " · 备用台词\n") + text
	toast_time = 7
	game.get_node("CompanionActor").react(action)

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	$Root/Toast.visible = false
	UIAppearance.fit($Root)
	UIAppearance.backdrop(self, box.visible)
	$Root/Open.position = Vector2(24, 174) if game.running else Vector2(1352, 20)
	$Root/Open.visible = not get_tree().paused and not box.visible and not game.get_node("HubUI/Root/Catalog").visible and not game.get_node("MotionSettings/Root/Panel").visible

