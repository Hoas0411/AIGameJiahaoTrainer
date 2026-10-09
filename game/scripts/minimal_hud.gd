extends CanvasLayer
const Art = preload("res://ui/approved/skin.gd")
const Frame = preload("res://ui/approved/hud_frame.gd")
var root: Control
var title: Label
var mouse: Button
var values: Array[Label] = []
var stat_labels: Array[Label] = []
var data_panel: Control
const DEFAULT_STAT_LABELS := ["实际击倒时间","命中率","爆头率"]
var materials: Array[ShaderMaterial] = []
var key_labels: Array[Label] = []
var ammo: Label
var weapon_mode: Label
var ability_row: Control
var sight_notice_root: Control
var sight_notice: Panel
var sight_notice_text: Label
var sight_notice_age := -1.0
const SIGHT_ENTER := 0.25
const SIGHT_HOLD := 0.75
const SIGHT_EXIT := 0.20
const SIGHT_RECT := Rect2(670.833333,125.0,258.333333,31.666667)
@onready var game: Node = get_parent()

func panel(parent: Node, name_: String, area: Rect2) -> Control:
	var node := Frame.new()
	node.name = name_
	parent.add_child(node)
	Art.rect(node,area.position.x,area.position.y,area.size.x,area.size.y)
	return node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Art.theme()
	root.size = Vector2(1600,900)
	add_child(root)
	var top := panel(root,"NameFrame",Rect2(40,30,275,46))
	title = Art.label(top,"",Rect2(15,3,245,40),23)
	mouse = Art.button(root,"麦小鼠       H",Rect2(40,658,166,42),func(): game.get_node("CompanionUI").open_panel())
	mouse.name = "Mouse"
	mouse.add_theme_font_size_override("font_size",19)
	mouse.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	var mouse_frame := panel(mouse,"Frame",Rect2(0,0,166,42))
	mouse.move_child(mouse_frame,0)
	mouse_frame.show_behind_parent = true
	data_panel = panel(root,"Data",Rect2(40,712,296,130))
	var data := data_panel
	for i in 3:
		stat_labels.append(Art.label(data,DEFAULT_STAT_LABELS[i],Rect2(17,9+i*40,177,32),19,Color("d8ded9")))
		var value := Art.label(data,"—",Rect2(187,8+i*40,91,34),23,Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		values.append(value)
	ability_row = Control.new()
	ability_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ability_row)
	Art.rect(ability_row,688,752,220,94)
	for i in 3:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = UIAppearance.hud_icon(["dash","charge","thumper"][i])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://ui/approved/charge.gdshader")
		icon.material = mat
		materials.append(mat)
		ability_row.add_child(icon)
		Art.rect(icon,i*82,0,56,56)
		var key := Art.label(ability_row,["X","G","V"][i],Rect2(i*82,62,56,32),21,Color.WHITE)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_labels.append(key)
	ammo = Art.label(root,"",Rect2(1390,788,170,46),28,Color.WHITE)
	ammo.add_theme_color_override("font_shadow_color",Color(0,0,0,0.65))
	ammo.add_theme_constant_override("shadow_offset_y",1)
	weapon_mode = Art.label(root,"",Rect2(1290,835,270,34),18,Color.WHITE)
	weapon_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	setup_sight_notice()
	refresh()

func setup_sight_notice() -> void:
	# Independent of the selected HUD skin; reference is 310x38 at (805,150)
	# in a 1920x1080 capture. Existing fit() also compensates 4:3 stretch.
	sight_notice_root = Control.new()
	sight_notice_root.name = "SightNoticeRoot"
	sight_notice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sight_notice_root.size = Vector2(1600,900)
	add_child(sight_notice_root)
	sight_notice = Panel.new()
	sight_notice.name = "SightNotice"
	sight_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sight_notice_root.add_child(sight_notice)
	sight_notice.position = SIGHT_RECT.position
	sight_notice.size = SIGHT_RECT.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01,0.018,0.016,0.78)
	style.border_color = Color(0.28,0.34,0.32,0.85)
	style.set_border_width_all(1)
	sight_notice.add_theme_stylebox_override("panel",style)
	sight_notice_text = Label.new()
	sight_notice_text.name = "Text"
	sight_notice_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sight_notice_text.add_theme_font_override("font",preload("res://assets/fonts/NotoSansSC-Medium.ttf"))
	sight_notice_text.add_theme_font_size_override("font_size",16)
	sight_notice_text.add_theme_color_override("font_color",Color(0.84,0.87,0.86,1))
	sight_notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sight_notice_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sight_notice.add_child(sight_notice_text)
	sight_notice_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sight_notice.hide()
	game.player.weapon.sight_changed.connect(show_sight_notice)
	game.player.weapon.sight_notice_reset.connect(clear_sight_notice)

func clear_sight_notice() -> void:
	sight_notice_age = -1.0
	sight_notice.hide()

func show_sight_notice(multiplier: float, is_laser: bool) -> void:
	if not game.running or not game.player.active or not game.player.combat_enabled or game.player.controls_blocked or get_tree().paused:
		return
	var number := ("%.2f" % multiplier).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	sight_notice_text.text = "瞄具倍率：%s倍" % number + ("（镭射）" if is_laser else "")
	sight_notice_age = 0.0
	update_sight_notice(0.0)

func update_sight_notice(delta: float) -> void:
	UIAppearance.fit(sight_notice_root)
	if not game.running or not game.player.active or not game.player.combat_enabled or game.player.controls_blocked or get_tree().paused:
		clear_sight_notice()
		return
	if sight_notice_age < 0.0:
		return
	sight_notice_age += delta
	if sight_notice_age >= SIGHT_ENTER + SIGHT_HOLD + SIGHT_EXIT:
		clear_sight_notice()
		return
	var travel := 0.0
	var opacity := 1.0
	if sight_notice_age < SIGHT_ENTER:
		var t := sight_notice_age / SIGHT_ENTER
		travel = 33.333333 * pow(1.0-t,3.0)
		opacity = minf(1.0,sight_notice_age/0.08)
	elif sight_notice_age > SIGHT_ENTER + SIGHT_HOLD:
		var t := (sight_notice_age-SIGHT_ENTER-SIGHT_HOLD)/SIGHT_EXIT
		travel = -16.666667*t
		opacity = 1.0-t
	sight_notice.position = SIGHT_RECT.position + Vector2(0,travel)
	sight_notice.modulate.a = opacity
	sight_notice.show()

func key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	return "—"

func refresh() -> void:
	root.visible = UIAppearance.selected == 2 and game.running and not get_tree().paused
	if not root.visible: return
	title.text = game.ui.TITLES[game.level_index]
	var name_width := clampf(title.get_theme_font("font").get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x+30,180,580)
	title.get_parent().size.x = name_width
	title.size.x = name_width-30
	# Courses may publish their own three live stats; the base shows none.
	var lvl: Node = game.level if is_instance_valid(game.level) else null
	data_panel.visible = game.level_index != 12
	if lvl != null and lvl.has_method("hud_stats"):
		var rows: Array = lvl.hud_stats()
		for i in 3:
			stat_labels[i].text = str(rows[i][0]) if i < rows.size() else ""
			values[i].text = str(rows[i][1]) if i < rows.size() else ""
	else:
		for i in 3: stat_labels[i].text = DEFAULT_STAT_LABELS[i]
		values[0].text = "%.2f s" % game.last_takedown_seconds if game.last_takedown_seconds >= 0 else "—"
		values[1].text = "%.0f%%" % (100.0*game.hits/game.shots) if game.shots > 0 else "—"
		values[2].text = "%.0f%%" % (100.0*game.headshots/game.hits) if game.hits > 0 else "—"
	var kit: Node = game.player.abilities
	materials[0].set_shader_parameter("progress",clampf(1.0-kit.dash_cd/maxf(kit.dash_cooldown,0.001),0,1))
	materials[1].set_shader_parameter("progress",1.0 if kit.charges > 0 else clampf(1.0-kit.charge_cd/maxf(kit.charge_replenish,0.001),0,1))
	materials[2].set_shader_parameter("progress",clampf(1.0-kit.thumper_cd/maxf(kit.thumper_cooldown,0.001),0,1))
	for i in 3: key_labels[i].text = key_name(["dash","charge","thumper"][i])
	ammo.text = "%d / ∞" % game.player.weapon.ammo
	ability_row.visible = game.player.combat_enabled
	ammo.visible = game.player.combat_enabled
	weapon_mode.visible = game.player.combat_enabled and game.player.weapon.profile.weapon_id == "m7"
	weapon_mode.text = "M7 · " + game.player.weapon.fire_mode_label() + "  [N]"
	# Keep scope, crosshair and non-text hit/hurt feedback; remove all old HUD text and plates.
	for child in game.ui.get_node("Root/HUD").get_children():
		if child is CanvasItem and child.name not in ["Scope","Crosshair","HitMarker","Hurt","JetVignette"]: child.hide()
	game.get_node("CompanionUI/Root/Open").hide()

func _process(delta: float) -> void:
	UIAppearance.fit(root)
	refresh()
	update_sight_notice(delta)
