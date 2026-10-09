extends RefCounted

const Frame = preload("res://ui/approved/frame.gd")
const CREAM = Color("eeeae0")
const DARK = Color("19272c")
const RED = Color("853337")
static var _cached_theme: Theme

static func rect(node: Control, x: float, y: float, w: float, h: float) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = Vector2(x,y)
	node.size = Vector2(w,h)

static func flat(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s

static func theme() -> Theme:
	if is_instance_valid(_cached_theme):
		return _cached_theme
	# The base theme contains shared font and style resources. A deep duplicate
	# makes Godot recursively revisit those resources and was responsible for
	# the runaway theme loads seen before native crashes. We replace every style
	# that this skin customizes, so a shallow Theme copy is sufficient and safe.
	var t: Theme = load("res://ui/rebuild/iteration-003/theme.tres").duplicate(false)
	t.default_font_size = 20
	for type in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,flat(Color("233034"),Color("847f70")))
		t.set_stylebox("hover",type,flat(CREAM,Color("b7b09d")))
		t.set_stylebox("pressed",type,flat(CREAM,Color("64b5b1")))
		t.set_stylebox("focus",type,flat(Color.TRANSPARENT,Color("72c4bb")))
		t.set_color("font_color",type,CREAM)
		t.set_color("font_hover_color",type,DARK)
		t.set_color("font_pressed_color",type,DARK)
	t.set_stylebox("panel","Panel",flat(Color("1c292d"),Color("847f70")))
	_cached_theme = t
	return _cached_theme

static func frame(parent: Node, name_: String, area: Rect2, dark := false, beak := false) -> Control:
	var f := Frame.new()
	f.name = name_
	f.fill = DARK if dark else CREAM
	f.beak = beak
	parent.add_child(f)
	rect(f,area.position.x,area.position.y,area.size.x,area.size.y)
	return f

static func label(parent: Node, title: String, area: Rect2, font_size := 22, color := CREAM) -> Label:
	var l := Label.new()
	l.text = title
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color",color)
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	rect(l,area.position.x,area.position.y,area.size.x,area.size.y)
	return l

static func button(parent: Node, title: String, area: Rect2, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	rect(b,area.position.x,area.position.y,area.size.x,area.size.y)
	b.pressed.connect(action)
	return b

static func companion() -> Control:
	var root: Control = load("res://ui/rebuild/iteration-005/companion.tscn").instantiate()
	root.theme = theme()
	var panel: Panel = root.get_node("Panel")
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	panel.get_node("Background").hide()
	panel.get_node("SceneBackdrop").hide()
	root.get_node("Shade").color = Color(0.025,0.045,0.05,0.25)
	var c: Control = panel.get_node("Margin/Columns/Chat")
	for n in ["DialogueFrame","NamePlateGraphic","InputBackdrop"]:
		var old := c.get_node(n)
		c.remove_child(old)
		old.free()
	var f := frame(c,"DialogueFrame",Rect2(448,574,970,138),false,true)
	c.move_child(f,1)
	var nf := frame(c,"NamePlateGraphic",Rect2(474,547,179,43),true)
	c.move_child(nf,2)
	var inf := frame(c,"InputFrame",Rect2(448,728,970,46))
	c.move_child(inf,3)
	label(inf,"你",Rect2(31,0,45,45),23,DARK)
	var divider := ColorRect.new()
	divider.color = Color("a49f93")
	inf.add_child(divider)
	rect(divider,99,11,1,24)
	var portrait: TextureRect = c.get_node("Portrait")
	portrait.texture = load("res://assets/ui-approved-20260915/mouse.png")
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect(portrait,25,337,410,563)
	rect(c.get_node("NamePlate"),503,547,146,42)
	c.get_node("NamePlate").rotation = 0
	c.get_node("NamePlate").add_theme_color_override("font_color",CREAM)
	c.get_node("NamePlate").add_theme_font_size_override("font_size",24)
	var latest: RichTextLabel = c.get_node("Latest")
	rect(latest,508,603,855,91)
	latest.scroll_active = true
	latest.add_theme_color_override("default_color",DARK)
	latest.add_theme_font_size_override("normal_font_size",26)
	var entry: LineEdit = c.get_node("Input")
	rect(entry,555,729,710,44)
	entry.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	entry.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	entry.add_theme_color_override("font_color",DARK)
	entry.add_theme_color_override("font_placeholder_color",Color("797e78"))
	entry.add_theme_color_override("caret_color",DARK)
	entry.add_theme_font_size_override("font_size",21)
	rect(c.get_node("Send"),1277,733,132,37)
	c.get_node("Send").add_theme_stylebox_override("normal",flat(RED))
	c.get_node("Send").add_theme_font_size_override("font_size",20)
	rect(c.get_node("History"),32,838,140,40)
	rect(c.get_node("Close"),1460,838,112,40)
	c.get_node("Close").text = "Esc  返回"
	rect(c.get_node("Tools"),30,25,165,40)
	rect(c.get_node("Status"),210,27,670,34)
	rect(panel.get_node("Settings"),1220,25,150,40)
	rect(panel.get_node("Appearance"),1382,25,190,40)
	for n in ["History","Close","Tools"]:
		c.get_node(n).add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		rect(c.get_node(n),c.get_node(n).position.x,c.get_node(n).position.y,c.get_node(n).size.x,c.get_node(n).size.y)
	for n in ["InputHint","Write"]: c.get_node(n).hide()
	rect(c.get_node("MemoryProposal"),450,798,750,32)
	rect(c.get_node("Remember"),1210,793,206,38)
	return root
