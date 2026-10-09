extends Window

var waiting: String = ""
var defaults: Dictionary = {}
const ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "fire", "aim", "reload", "lean_left", "lean_right", "laser", "zoom", "dash", "charge", "thumper", "restart", "map", "weapon_one", "weapon_two"]



# 保存项目默认键位，然后读取用户独立配置，避免覆盖灵敏度设置。
func _ready() -> void:
	close_requested.connect(func(): waiting = ""; hide())
	$Restore.pressed.connect(restore_defaults)
	for action in ACTIONS:
		defaults[action] = InputMap.action_get_events(action).duplicate()
		get_node("Rows/" + action).pressed.connect(func(): waiting = action; $Status.text = "请按键或鼠标按钮；Esc 取消。")
	var config := ConfigFile.new()
	if config.load("user://keybindings.cfg") == OK:
		for action in ACTIONS:
			var event = config.get_value("keys", action) if config.has_section_key("keys", action) else null
			if event is InputEventKey or event is InputEventMouseButton:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
		$LeanToggle.button_pressed = bool(config.get_value("options", "lean_toggle", false))
		if int(config.get_value("options", "qe_lean_migration", 0)) < 1:
			var laser_events := InputMap.action_get_events("laser")
			if not laser_events.is_empty() and laser_events[0] is InputEventKey and laser_events[0].physical_keycode == KEY_T:
				var replacement := InputEventKey.new()
				replacement.physical_keycode = KEY_B
				InputMap.action_erase_events("laser")
				InputMap.action_add_event("laser", replacement)
			save()
	$LeanToggle.toggled.connect(func(value):
		get_tree().call_group("player", "set_lean_toggle_mode", value)
		save())
	refresh()



# 界面显示当前绑定；按钮和布局均保存于场景供人工编辑。
func refresh() -> void:
	for action in ACTIONS:
		var events := InputMap.action_get_events(action)
		get_node("Rows/" + action).text = events[0].as_text().replace(" (Physical)", "").replace(" - Physical", "").replace("Left Mouse Button", "鼠标左键").replace("Right Mouse Button", "鼠标右键") if not events.is_empty() else "未绑定"



# 捕获一次实体按键，拒绝冲突和系统菜单键，避免一次输入触发两个动作。
func _input(event: InputEvent) -> void:
	if not visible or waiting == "" or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		waiting = ""
		$Status.text = "已取消。"
		set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	var clean: InputEvent
	if event is InputEventKey:
		clean = InputEventKey.new()
		clean.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if clean.physical_keycode in [KEY_T, KEY_F, KEY_J, KEY_ENTER, KEY_TAB, KEY_F6, KEY_F7, KEY_F8, KEY_F9]:
			$Status.text = "该键保留给语音、交互、聊天或校准，请选择其他按键。"
			set_input_as_handled()
			return
	else:
		clean = InputEventMouseButton.new()
		clean.button_index = event.button_index
	for action in ACTIONS:
		if action != waiting and InputMap.event_is_action(clean, action):
			$Status.text = "该按键已绑定：" + action + "，请选择其他按键。"
			set_input_as_handled()
			return
	InputMap.action_erase_events(waiting)
	InputMap.action_add_event(waiting, clean)
	waiting = ""
	save()
	refresh()
	$Status.text = "已保存并立即生效。"
	set_input_as_handled()



# 键位独立持久化，重启游戏继续有效。
func save() -> void:
	var config := ConfigFile.new()
	for action in ACTIONS:
		var events := InputMap.action_get_events(action)
		if not events.is_empty():
			config.set_value("keys", action, events[0])
	config.set_value("options", "lean_toggle", $LeanToggle.button_pressed)
	config.set_value("options", "qe_lean_migration", 1)
	config.save("user://keybindings.cfg")



# 恢复工程中的默认动作绑定。
func restore_defaults() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		for event in defaults[action]:
			InputMap.action_add_event(action, event)
	waiting = ""
	$LeanToggle.button_pressed = false
	save()
	refresh()
	$Status.text = "已恢复默认按键。"
