extends CanvasLayer

var was_paused: bool = false
var previous_mouse: int = Input.MOUSE_MODE_CAPTURED
@onready var level: Node = get_parent()

func _ready() -> void:
	$Panel/Precision.button_pressed = level.precision_variant
	$Panel/Viewmodel.button_pressed = level.show_viewmodel
	$Panel/Close.pressed.connect(close)
	$Panel/Apply.pressed.connect(func():
		level.game.training_options[level.game.level_index] = {"precision_variant":$Panel/Precision.button_pressed,"show_viewmodel":$Panel/Viewmodel.button_pressed}
		close()
		level.game.start_session(level.game.level_index))

func open() -> void:
	if $Panel.visible:
		return
	was_paused = get_tree().paused
	previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Panel.show()

func close() -> void:
	if not $Panel.visible:
		return
	$Panel.hide()
	get_tree().paused = was_paused
	Input.mouse_mode = previous_mouse

func _input(event: InputEvent) -> void:
	if level.game.get_node("TrainingCatalog").is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if $Panel.visible and (event.physical_keycode == KEY_F9 or event.is_action_pressed("ui_cancel")):
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F9 and level.game.running and not level.game.player.controls_blocked:
			open()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	$Panel.scale = Vector2.ONE * minf(size.x/1600.0,size.y/900.0)
	$Panel.position = (size-Vector2(900,520)*$Panel.scale)/2.0
