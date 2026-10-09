@tool
extends Control
## A single closed contour owns both the card and its blunt upper-right lobe.

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	for i in range(1, 13):
		var t := float(i) / 12.0
		var u := 1.0 - t
		points.append(a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t)

func _draw() -> void:
	if size.x < 30.0 or size.y < 30.0: return
	var w := size.x
	var h := size.y
	var outline := PackedVector2Array([Vector2(8, 0), Vector2(w - 12, 0)])
	_curve(outline, Vector2(w - 12, 0), Vector2(w - 5, 0), Vector2(w + 5, -6), Vector2(w + 7, 1))
	_curve(outline, Vector2(w + 7, 1), Vector2(w + 10, 7), Vector2(w, 7), Vector2(w, 14))
	outline.append_array(PackedVector2Array([Vector2(w, h - 8), Vector2(w - 8, h), Vector2(8, h), Vector2(0, h - 8), Vector2(0, 8)]))
	for distance in [4.0, 2.0]:
		var shadow := PackedVector2Array()
		for point in outline: shadow.append(point + Vector2(0, distance))
		draw_colored_polygon(shadow, Color(0.035, 0.045, 0.05, 0.13))
	draw_colored_polygon(outline, Color("#f2ede2"))
	outline.append(outline[0])
	draw_polyline(outline, Color("#28343a"), 1.6, true)
	# Open decorative inset: it never cuts across the lobe's base.
	draw_polyline(PackedVector2Array([Vector2(w - 18, 5), Vector2(10, 5), Vector2(5, 10), Vector2(5, h - 10), Vector2(10, h - 5), Vector2(w - 10, h - 5), Vector2(w - 5, h - 10), Vector2(w - 5, 20)]), Color("#d9d1bf"), 0.8, true)
	draw_line(Vector2(8, h - 13), Vector2(13, h - 8), Color("#ad4144"), 1.8, true)
	draw_line(Vector2(w - 13, h - 8), Vector2(w - 8, h - 13), Color("#ad4144"), 1.8, true)

