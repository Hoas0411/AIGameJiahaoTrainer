extends CanvasLayer

var motion: MotionProfile = preload("res://resources/motion_baseline.tres")
var previous_pause: bool = false
var previous_mouse: int = Input.MOUSE_MODE_VISIBLE
@onready var game: Node = get_parent()

func _ready() -> void:
	var saved := ConfigFile.new()
	if saved.load("user://motion.cfg") == OK:
		for row in $Root/Panel/Scroll/Rows.get_children():
			var key: String = row.name
			var spin: SpinBox = row.get_node("Value")
			motion.set(key, clampf(saved.get_value("motion", key, motion.get(key)), spin.min_value, spin.max_value))
	$Root/Panel/Close.pressed.connect(close_panel)
	$Root/Panel/Save.pressed.connect(save_values)
	$Root/Panel/Reset.pressed.connect(func():
		var baseline := MotionProfile.new()
		for row in $Root/Panel/Scroll/Rows.get_children():
			row.get_node("Value").value = baseline.get(str(row.name)))
	game.get_node("Player").sync_motion()

func open_panel() -> void:
	previous_pause = get_tree().paused
	previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for row in $Root/Panel/Scroll/Rows.get_children():
		row.get_node("Value").value = motion.get(str(row.name))
	$Root/Panel.show()

func close_panel() -> void:
	$Root/Panel.hide()
	get_tree().paused = previous_pause
	Input.mouse_mode = previous_mouse

func save_values() -> void:
	var rows: Node = $Root/Panel/Scroll/Rows
	if rows.get_node("crouch_height/Value").value >= rows.get_node("stand_height/Value").value or rows.get_node("stand_eye/Value").value >= rows.get_node("stand_height/Value").value or rows.get_node("crouch_eye/Value").value >= rows.get_node("crouch_height/Value").value:
		$Root/Panel/Note.text = "未应用：蹲姿应低于站姿，视点应低于对应碰撞体顶部。"
		return
	var saved := ConfigFile.new()
	for row in $Root/Panel/Scroll/Rows.get_children():
		var value: float = row.get_node("Value").value
		motion.set(str(row.name), value)
		saved.set_value("motion", str(row.name), value)
	saved.save("user://motion.cfg")
	game.player.sync_motion()
	game.player.abilities.reset()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.strafe_speed = motion.walk_speed * motion.equipment_speed_multiplier
		enemy.jump_force = motion.jump_speed()
	$Root/Panel/Note.text = "已应用到玩家与 NPC。来源：个人调参；不代表已验证本体等效。"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if $Root/Panel.visible and (event.physical_keycode == KEY_F8 or event.is_action_pressed("ui_cancel")):
			close_panel()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F8 and not get_tree().paused and not game.player.controls_blocked:
			open_panel()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	$Root.scale.x = get_viewport().get_visible_rect().size.x / 1600.0
