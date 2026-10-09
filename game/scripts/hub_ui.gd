extends CanvasLayer

@onready var game: Node = get_parent()
var old_mouse: int = Input.MOUSE_MODE_CAPTURED
var was_paused: bool = false
var selected_course := 0
var course_drawer_open := false
const HUB_LEVEL_IDS: Array[int] = [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const DETAILS = ["击倒 · 喷气 · 跳拉", "", "逐角清除 · 预瞄", "变向急停 · 持续追踪", "喷气接枪 · 控制衔接", "整图路线 · 自由探索", "10 / 25 / 50 米分段练习", "随机亮靶 · 首发反应计时", "平台目标 · 垂直转移", "C4 逼位 · 虎蹲后接枪", "辨别方向 · 转身确认", "跳跃 / 喷气距离实测"]

func _ready() -> void:
	build_skin()
	UIAppearance.changed.connect(build_skin)

func build_skin() -> void:
	var opened := false
	if has_node("Root"):
		opened = $Root/Catalog.visible
		var previous := $Root
		remove_child(previous)
		previous.queue_free()
	add_child(UIAppearance.skin("hub"))
	$Root/Catalog.visible = opened
	UIAppearance.bind_selector($Root/Catalog/Appearance)
	$Root/Catalog/Close.pressed.connect(close_catalog)
	$Root/Catalog/Companion.pressed.connect(func(): close_catalog(); game.get_node("CompanionUI").open_panel())
	$Root/Catalog/Tools.pressed.connect(func(): close_catalog(); game.get_node("CompanionUI").open_panel(); game.get_node("CompanionUI").show_tools())
	$Root/Catalog/Start.pressed.connect(func(): close_catalog(); game.start_session(selected_course))
	$Root/Catalog/Training.pressed.connect(func(): close_catalog(); game.get_node("TrainingCatalog").open())
	if $Root/Catalog.has_node("TrainingSelect"):
		$Root/Catalog/TrainingSelect.pressed.connect(func(): show_course_drawer(true))
		$Root/Catalog/CourseBack.pressed.connect(func(): show_course_drawer(false))
		for pair in [["Tracking",13],["Flick",19],["Reaction",7],["DoorGap",15]]:
			var course: int = pair[1]
			$Root/Catalog.get_node(pair[0]).pressed.connect(func(): close_catalog(); game.start_session(course))
		$Root/Catalog/RecordsOpen.pressed.connect(func(): open_tools_records())
		$Root/Catalog/PreferencesOpen.pressed.connect(func():
			close_catalog()
			game.get_node("CompanionUI").open_panel()
			game.get_node("CompanionUI").show_preferences(true))
		show_course_drawer(false)
	for value in ["轻松", "标准", "强化"]:
		$Root/Catalog/Difficulty.add_item(value)
	$Root/Catalog/Difficulty.item_selected.connect(func(i): game.ui.difficulty_choice.select(i))
	$Root/Catalog/Invincible.toggled.connect(func(value): game.ui.invincible.button_pressed = value; game.ui.settings_changed.emit())
	for i in HUB_LEVEL_IDS:
		var button: Button = get_node("Root/Catalog/Course%d" % i)
		button.visible = i in [0,6,7,8]
		if button.visible:
			button.text = preload("res://scripts/course_registry.gd").NAMES[i]+"\n"+DETAILS[i]
			button.pressed.connect(func(): select_course(i))
	select_course(selected_course)
	if is_instance_valid(game.ui):
		$Root/Catalog/Difficulty.select(game.ui.difficulty_choice.selected)
		$Root/Catalog/Invincible.set_pressed_no_signal(game.ui.invincible.button_pressed)

func show_course_drawer(value: bool) -> void:
	course_drawer_open = value
	if not $Root/Catalog.has_node("TrainingSelect"): return
	for child in $Root/Catalog.get_children():
		if child.get_meta("course_drawer", false): child.visible = value and (not str(child.name).begins_with("Course") or str(child.name).trim_prefix("Course").to_int() in [0,6,7,8])
		elif child.name in ["TrainingSelect","Tracking","Flick","Reaction","DoorGap","Companion","Tools","RecordsOpen","PreferencesOpen","MenuCaption","ActionTitle","ActionHint"]: child.visible = not value

func open_tools_records() -> void:
	close_catalog()
	var companion_ui: Node = game.get_node("CompanionUI")
	companion_ui.open_panel()
	companion_ui.show_tools()
	if companion_ui.tools_workspace.has_method("show_data"):
		companion_ui.tools_workspace.show_data(true)

func select_course(index: int) -> void:
	if not game.LEVELS.has(index): return
	selected_course = index
	for i in HUB_LEVEL_IDS:
		get_node("Root/Catalog/Course%d" % i).set_pressed_no_signal(i == index)
	$Root/Catalog/Selected.text = get_node("Root/Catalog/Course%d" % index).text.split("\n")[0]
	$Root/Catalog/Description.text = DETAILS[index]

func open_catalog() -> void:
	if UIAppearance.selected == 2 and game.has_node("ApprovedUI"):
		game.get_node("ApprovedUI").open_catalog()
		return
	if $Root/Catalog.visible:
		return
	old_mouse = Input.mouse_mode
	was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Root/Catalog.show()
	$Root/Catalog/Difficulty.select(game.ui.difficulty_choice.selected)
	$Root/Catalog/Invincible.set_pressed_no_signal(game.ui.invincible.button_pressed)
	if $Root/Catalog.has_node("RightMiddle/RecordEmpty"):
		var rows: Array = game.get_node("Companion").history()
		var label: Label = $Root/Catalog/RightMiddle/RecordEmpty
		if rows.is_empty():
			label.text = "还没有已结算的记录。\n练完一轮，再回来看看。"
		else:
			var row: Dictionary = rows.back()
			var shots: int = int(row.get("shots", 0))
			var accuracy := "尚未开火" if shots == 0 else "命中率 %.1f%%" % (100.0 * int(row.get("hits", 0)) / shots)
			label.text = "第 %d 关  ·  %d 秒\n%s" % [int(row.get("level", 0)), int(row.get("seconds", 0)), accuracy]

func close_catalog() -> void:
	if not $Root/Catalog.visible:
		return
	$Root/Catalog.hide()
	get_tree().paused = was_paused
	Input.mouse_mode = old_mouse

func _input(event: InputEvent) -> void:
	if game.has_node("TrainingCatalog") and game.get_node("TrainingCatalog").is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if $Root/Catalog.visible and (event.physical_keycode == KEY_TAB or event.is_action_pressed("ui_cancel")):
			if course_drawer_open: show_course_drawer(false)
			else: close_catalog()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB and game.running and not get_tree().paused and not game.player.controls_blocked:
			open_catalog()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	UIAppearance.fit($Root)
	UIAppearance.backdrop(self, $Root/Catalog.visible)
	$Root/Prompt.text = ""
	if game.running and game.level_index == 12 and not get_tree().paused:
		var index: int = game.level.selected
		if index >= 0:
			$Root/Prompt.text = "F  进入「%s」" % game.ui.TITLES[index]
