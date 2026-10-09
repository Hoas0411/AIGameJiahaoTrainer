extends Button

var last_text := ""

func _ready() -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	queue_redraw()

func _process(_delta: float) -> void:
	if last_text != text:
		last_text = text
		queue_redraw()

func _draw() -> void:
	var font := get_theme_font("font")
	var lines := text.split("\n")
	draw_colored_polygon(PackedVector2Array([Vector2(13,17),Vector2(13,31),Vector2(24,24)]), Color("b8bec0"))
	draw_string(font, Vector2(34,23), lines[0], HORIZONTAL_ALIGNMENT_LEFT, size.x-42, 17, Color("f1f2f3"))
	if lines.size() > 1:
		draw_string(font, Vector2(34,42), lines[1], HORIZONTAL_ALIGNMENT_LEFT, size.x-42, 13, Color("43c4c7"))
