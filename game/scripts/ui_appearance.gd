extends Node

signal changed
const IDS = ["workstation", "ink", "approved"]
const NAMES = ["训练工作站", "漫画对白", "批准美术稿"]
const RESOURCE_ROOTS = ["res://ui/rebuild/iteration-003", "res://ui/rebuild/iteration-005"]
var selected := 2
var save_path := "user://ui_approved_20260915.cfg"
var hud_texture_cache: Dictionary = {}
var theme_cache: Dictionary = {}
const HUD_FONTS = [preload("res://assets/fonts/NotoSansSC.ttf"),preload("res://assets/fonts/NotoSansSC-Medium.ttf")]

func _ready() -> void:
	# Shared font resources are configured once, before any menu/HUD is built.
	# MSDF glyphs keep their contour when the 1600x900 layout scales to high DPI.
	for font: FontFile in HUD_FONTS:
		font.multichannel_signed_distance_field=true
		font.msdf_pixel_range=16
		font.msdf_size=64
	# Keep menus in the game viewport, including pointer/keyboard focus at 4:3.
	get_tree().root.gui_embed_subwindows = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-") or arg.begins_with("--ui-test"):
			save_path = "user://ui_appearance_test.cfg"
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		selected = clampi(int(config.get_value("appearance", "style", 2)), 0, IDS.size() - 1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-style="):
			selected = clampi(int(arg.get_slice("=", 1)), 0, IDS.size() - 1)

func choose(index: int) -> void:
	if index == selected:
		return
	selected = clampi(index, 0, IDS.size() - 1)
	var config := ConfigFile.new()
	config.set_value("appearance", "style", selected)
	config.save(save_path)
	changed.emit()

func hud_icon(name_: String) -> Texture2D:
	if not hud_texture_cache.has(name_):
		# The SVG import scale is 4x. Use the same imported 256px texture in
		# both the editor and the PCK; no original SVG text is needed at runtime.
		hud_texture_cache[name_]=load("res://assets/hud-minimal/"+name_+".svg")
	return hud_texture_cache[name_]

func skin(surface: String) -> Control:
	if selected == 2 and surface == "companion":
		return preload("res://ui/approved/skin.gd").companion()
	return load(RESOURCE_ROOTS[mini(selected, 1)] + "/" + surface + ".tscn").instantiate()

func get_theme() -> Theme:
	# Theme creation is intentionally cached. This method is reached by two UI
	# layers while they are alive; rebuilding and deep-duplicating the approved
	# theme every frame previously caused hundreds of MB of resource churn and
	# eventually a native access violation during lobby-to-training transitions.
	if not theme_cache.has(selected):
		theme_cache[selected] = preload("res://ui/approved/skin.gd").theme() if selected == 2 else load(RESOURCE_ROOTS[selected] + "/theme.tres")
	return theme_cache[selected] as Theme

func accent() -> Color:
	return [Color("43d1d6"), Color("ff173d"), Color("74c8bf")][selected]

func background() -> Color:
	var panel: StyleBoxFlat = get_theme().get_stylebox("panel", "Panel")
	return panel.bg_color

func fit(canvas: Control) -> void:
	var viewport_size := canvas.get_viewport().get_visible_rect().size
	# The game's 4:3 mode stretches a 1200-wide viewport into a 16:9 window.
	# Compensate that final stretch so UI glyphs are uniform on the physical screen.
	var screen_scale := canvas.get_viewport().get_screen_transform().get_scale().abs()
	screen_scale.x = maxf(0.001, screen_scale.x)
	screen_scale.y = maxf(0.001, screen_scale.y)
	var signature := Vector4(viewport_size.x, viewport_size.y, screen_scale.x, screen_scale.y)
	if canvas.get_meta(&"ui_fit_signature", Vector4.ZERO) == signature:
		return
	canvas.set_meta(&"ui_fit_signature", signature)
	var displayed := viewport_size * screen_scale
	var factor := minf(displayed.x / 1600.0, displayed.y / 900.0)
	canvas.scale = Vector2.ONE * factor / screen_scale
	canvas.position = (viewport_size - Vector2(1600, 900) * canvas.scale) * 0.5

func backdrop(layer: CanvasLayer, enabled: bool) -> void:
	var fill := layer.get_node_or_null("Backdrop") as ColorRect
	if fill == null:
		fill = ColorRect.new()
		fill.name = "Backdrop"
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(fill)
		layer.move_child(fill, 0)
	# Only refresh theme-derived state when the chosen appearance changes.
	# Visibility and viewport size are cheap state assignments and do not load
	# or duplicate resources.
	if int(fill.get_meta(&"appearance_style", -1)) != selected:
		fill.color = background()
		fill.set_meta(&"appearance_style", selected)
	var viewport_size := layer.get_viewport().get_visible_rect().size
	if fill.size != viewport_size:
		fill.size = viewport_size
	var should_show := enabled and selected != 2
	if fill.visible != should_show:
		fill.visible = should_show

func bind_selector(selector: OptionButton) -> void:
	for label in NAMES:
		selector.add_item("界面 · " + label)
	selector.select(selected)
	selector.item_selected.connect(func(index): choose.call_deferred(index))
