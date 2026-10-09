extends CanvasLayer

const ArtUI = preload("res://ui/approved/skin.gd")
const ORDER = preload("res://scripts/course_registry.gd").TRAINING_IDS
const CROPS = [Rect2(186,235,298,345),Rect2(520,259,299,321),Rect2(858,235,298,345),Rect2(1195,235,294,345)]
var root: Control
var cards: Control
var description: Label
var counter: Label
var chosen := 0
var page := 0
var category := 0
var filtered: Array = ORDER.duplicate()
var old_paused := false
var old_mouse := Input.MOUSE_MODE_CAPTURED
var pause_origin := false
var pause_canvas: Control
@onready var game: Node = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	root = Control.new()
	root.name = "Catalog"
	root.theme = ArtUI.theme()
	root.size = Vector2(1600,900)
	root.hide()
	root.add_to_group("training_modal")
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.045,0.05,0.85)
	root.add_child(shade)
	ArtUI.rect(shade,0,0,1600,900)
	ArtUI.label(root,"训练关卡",Rect2(158,43,900,64),42)
	ArtUI.label(root,"选择今天的训练",Rect2(162,103,600,30),18,Color("b9c3be"))
	for i in 4:
		var b := ArtUI.button(root,["全部","定位","跟枪","反应"][i],Rect2(533+i*133,124,125,40),filter_courses.bind(i))
		b.name = "Filter%d" % i
	cards = Control.new()
	root.add_child(cards)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtUI.button(root,"‹",Rect2(89,405,55,75),turn_page.bind(-1)).name = "Previous"
	ArtUI.button(root,"›",Rect2(1460,405,55,75),turn_page.bind(1)).name = "Next"
	var foot := ArtUI.frame(root,"DescriptionFrame",Rect2(157,700,1284,100))
	description = ArtUI.label(foot,"",Rect2(27,12,958,76),20,ArtUI.DARK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var start := ArtUI.button(foot,"开始训练  ▸",Rect2(1007,20,246,59),launch)
	start.name = "Start"
	start.add_theme_stylebox_override("normal",ArtUI.flat(ArtUI.RED))
	counter = ArtUI.label(root,"",Rect2(700,834,260,40),18)
	ArtUI.button(root,"Esc  返回",Rect2(1450,832,130,43),close_catalog).name = "Close"
	var difficulty := OptionButton.new()
	difficulty.name = "Difficulty"
	root.add_child(difficulty)
	ArtUI.rect(difficulty,158,835,165,40)
	for s in ["轻松","标准","强化"]: difficulty.add_item(s)
	difficulty.item_selected.connect(func(i): game.ui.difficulty_choice.select(i))
	ArtUI.button(root,"训练说明",Rect2(337,835,155,40),show_details).name = "Details"
	install_pause()
	UIAppearance.changed.connect(func(): if is_open(): close_catalog())
	redraw_cards()

func art_kind(index: int) -> int:
	if index in [3,13,14]: return 1
	if index in [2,15]: return 2
	if index in [19,6,21,22]: return 0
	return 3

func filter_courses(index: int) -> void:
	category = index
	filtered = []
	for level in ORDER:
		if index == 0 or (index == 1 and art_kind(level) == 0) or (index == 2 and art_kind(level) == 1) or (index == 3 and art_kind(level) in [2,3]): filtered.append(level)
	page = 0
	chosen = filtered[0]
	redraw_cards()

func redraw_cards() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for slot in 4:
		var n := page*4+slot
		if n >= filtered.size(): break
		var level_index: int = filtered[n]
		var selected := level_index == chosen
		var x := 171.0+slot*322.0
		var y := 202.0 if selected else 222.0
		var h := 471.0 if selected else 441.0
		var f := ArtUI.frame(cards,"Card%d" % slot,Rect2(x,y,294,h),true)
		f.edge = Color("74c8bf") if selected else Color("a5a393")
		var illustration := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/ui-approved-20260915/levels.png")
		atlas.region = CROPS[art_kind(level_index)]
		illustration.texture = atlas
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.add_child(illustration)
		ArtUI.rect(illustration,8,8,278,h-109)
		ArtUI.label(f,game.ui.TITLES[level_index],Rect2(18,h-93,261,55),23).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ArtUI.label(f,["定位 · 精度","持续跟枪","预瞄 · 反应","综合训练"][art_kind(level_index)],Rect2(18,h-37,256,24),15,Color("a8bbb6"))
		if selected:
			ArtUI.label(f,"已选择",Rect2(14,12,255,28),17,Color("b4f2e4"))
		var hit := ArtUI.button(cards,"",Rect2(x,y,294,h),select_course.bind(level_index))
		hit.name = "Select%d" % slot
		hit.tooltip_text = game.ui.TITLES[level_index]
		for s in ["normal","hover","pressed"]: hit.add_theme_stylebox_override(s,StyleBoxEmpty.new())
	description.text = game.ui.TITLES[chosen]+"\n"+game.ui.OBJECTIVES[chosen]
	counter.text = "%d / %d     ·     %d 个关卡" % [page+1,ceili(filtered.size()/4.0),filtered.size()]
	root.get_node("Previous").disabled = page == 0
	root.get_node("Next").disabled = (page+1)*4 >= filtered.size()
	for i in 4:
		root.get_node("Filter%d" % i).add_theme_stylebox_override("normal",ArtUI.flat(ArtUI.CREAM if category==i else ArtUI.DARK))
		root.get_node("Filter%d" % i).add_theme_color_override("font_color",ArtUI.DARK if category==i else ArtUI.CREAM)

func select_course(index: int) -> void:
	chosen = index
	redraw_cards()

func show_details() -> void:
	var popup := AcceptDialog.new()
	popup.title = game.ui.TITLES[chosen]
	popup.dialog_text = game.ui.OBJECTIVES[chosen]
	for course in game.get_node("TrainingCatalog").courses:
		if int(course.index) != chosen: continue
		popup.dialog_text = ""
		for item in [["训练核心","core"],["训练能力","skills"],["怎么玩","steps"],["观察数据","metrics"],["如何改进","improvement"],["适用边界","boundary"],["参考视频","reference"],["链接","url"]]:
			popup.dialog_text += item[0]+"\n"+str(course.get(item[1],""))+"\n\n"
	root.add_child(popup)
	var body := RichTextLabel.new()
	body.text = popup.dialog_text
	body.custom_minimum_size = Vector2(780,570)
	body.add_theme_font_size_override("normal_font_size",20)
	popup.dialog_text = ""
	popup.add_child(body)
	popup.min_size = Vector2i(700,550)
	popup.popup_centered(Vector2i(850,720))
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)

func turn_page(direction: int) -> void:
	page = clampi(page+direction,0,maxi(0,ceili(filtered.size()/4.0)-1))
	chosen = filtered[page*4]
	redraw_cards()

func is_open() -> bool:
	return is_instance_valid(root) and root.visible

func open_catalog() -> void:
	if is_open(): return
	if game.get_node("CompanionUI").box.visible: game.get_node("CompanionUI").close_panel()
	game.get_node("BubbleUI").close_input()
	old_paused = get_tree().paused
	old_mouse = Input.mouse_mode
	pause_origin = game.ui.get_node("Root/Pause").visible
	if pause_origin: game.ui.get_node("Root/Pause").hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.get_node("Difficulty").select(game.ui.difficulty_choice.selected)
	root.show()

func close_catalog() -> void:
	if not is_open(): return
	root.hide()
	get_tree().paused = old_paused
	Input.mouse_mode = old_mouse
	if pause_origin: game.ui.get_node("Root/Pause").show()

func launch() -> void:
	close_catalog()
	game.start_session(chosen)

func install_pause() -> void:
	var host: Control = game.ui.get_node("Root/Pause")
	pause_canvas = Control.new()
	pause_canvas.name = "Approved"
	pause_canvas.theme = ArtUI.theme()
	pause_canvas.size = Vector2(1600,900)
	host.add_child(pause_canvas)
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.04,0.045,0.24)
	pause_canvas.add_child(dim)
	ArtUI.rect(dim,0,0,1600,900)
	ArtUI.label(pause_canvas,"暂停",Rect2(63,213,370,75),49)
	var f := ArtUI.frame(pause_canvas,"MenuFrame",Rect2(61,302,412,480),true)
	var names := ["继续","选择关卡","回到基地","设置","退出游戏"]
	var actions: Array[Callable] = [func(): game.ui.resume_requested.emit(),open_catalog,func(): game.ui.menu_requested.emit(),func(): game.ui.open_settings("pause"),func(): get_tree().quit()]
	for i in 5:
		var b := ArtUI.button(f,names[i],Rect2(9,30+i*77,394,61),actions[i])
		b.name = "Action%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",27)
		b.add_theme_stylebox_override("normal",ArtUI.flat(ArtUI.CREAM if i==0 else Color.TRANSPARENT))
		b.add_theme_color_override("font_color",ArtUI.DARK if i==0 else ArtUI.CREAM)
	ArtUI.label(f,"稍作休息，再来一轮。",Rect2(28,425,350,34),16,Color("b4b5a9"))

func _process(_delta: float) -> void:
	UIAppearance.fit(root)
	UIAppearance.fit(pause_canvas)
	var approved: bool = UIAppearance.selected == 2
	if approved and game.running:
		game.ui.get_node("Root/HUD").visible = not get_tree().paused
	pause_canvas.visible = approved
	for child in game.ui.get_node("Root/Pause").get_children():
		if child != pause_canvas and child is CanvasItem: child.visible = not approved

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_ESCAPE,KEY_TAB,KEY_F6]: close_catalog()
	elif event.physical_keycode == KEY_LEFT: turn_page(-1)
	elif event.physical_keycode == KEY_RIGHT: turn_page(1)
	else: return
	get_viewport().set_input_as_handled()

