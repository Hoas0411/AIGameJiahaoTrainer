extends CanvasLayer

var old_mouse: int = Input.MOUSE_MODE_CAPTURED
var old_paused: bool = false
var selected_course: int = 0
var courses: Array = []
@onready var game: Node = get_parent()

func _ready() -> void:
	courses = JSON.parse_string(FileAccess.get_file_as_string("res://resources/training/course_catalog.json"))
	for label in ["轻松", "标准", "强化"]:
		$Panel/Difficulty.add_item(label)
	$Panel/Difficulty.item_selected.connect(func(index: int): game.ui.difficulty_choice.select(index))
	for i in 10:
		if i >= courses.size():
			get_node("Panel/Course%d" % i).hide()
			continue
		var button: Button = get_node("Panel/Course%d" % i)
		button.text = courses[i].title + "\n" + courses[i].summary
		button.pressed.connect(show_course.bind(i))
	$Panel/Close.pressed.connect(close)
	$Details/Back.pressed.connect(func(): $Details.hide(); $Panel.show())
	$Details/Start.pressed.connect(func(): close(); game.start_session(int(courses[selected_course].index)))
	$Details/Body.meta_clicked.connect(func(url: Variant):
		if str(url).begins_with("https://"):
			OS.shell_open(str(url)))

func is_open() -> bool:
	if UIAppearance.selected == 2 and game.has_node("ApprovedUI"):
		return game.get_node("ApprovedUI").is_open()
	return $Panel.visible or $Details.visible

func show_course(index: int) -> void:
	selected_course = index
	var course: Dictionary = courses[index]
	$Panel.hide()
	$Details.show()
	$Details/Title.text = course.title
	var body: String = ""
	for item in [["训练核心","core"],["训练能力","skills"],["怎么玩","steps"],["看哪些数据","metrics"],["如何练得更有效","improvement"],["参考与适用边界","boundary"]]:
		body += "[color=#6be0cc][b]" + item[0] + "[/b][/color]\n" + str(course[item[1]]) + "\n\n"
	body += "[color=#6be0cc][b]参考视频[/b][/color]\n" + course.reference + "\n[url=" + course.url + "]打开原视频 ↗[/url]"
	$Details/Body.text = body
	$Details/Body.scroll_to_line(0)

func open() -> void:
	if UIAppearance.selected == 2 and game.has_node("ApprovedUI"):
		game.get_node("ApprovedUI").open_catalog()
		return
	if is_open():
		return
	game.get_node("HubUI").close_catalog()
	old_mouse = Input.mouse_mode
	old_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Panel.show()
	$Panel/Difficulty.select(game.ui.difficulty_choice.selected)

func close() -> void:
	if UIAppearance.selected == 2 and game.has_node("ApprovedUI"):
		game.get_node("ApprovedUI").close_catalog()
		return
	if not is_open():
		return
	$Panel.hide()
	$Details.hide()
	get_tree().paused = old_paused
	Input.mouse_mode = old_mouse

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if is_open() and (event.physical_keycode == KEY_F6 or event.is_action_pressed("ui_cancel")):
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F6 and not game.player.controls_blocked:
			open()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	for panel in [$Panel,$Details]:
		panel.scale = Vector2.ONE * minf(size.x / 1600.0, size.y / 900.0)
		panel.position = (size - Vector2(1280,740) * panel.scale) / 2.0
