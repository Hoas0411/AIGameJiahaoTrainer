extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w := size.x-1
	var h := size.y-1
	var p := PackedVector2Array([Vector2(1,1),Vector2(w-10,1),Vector2(w,11),Vector2(w,h),Vector2(11,h),Vector2(1,h-10)])
	draw_colored_polygon(p,Color(0.09,0.15,0.18,0.93))
	p.append(p[0])
	draw_polyline(p,Color(0.67,0.66,0.60,0.8),1.0,true)
	draw_line(Vector2(7,7),Vector2(w-15,7),Color(0.82,0.79,0.70,0.25),1,true)
