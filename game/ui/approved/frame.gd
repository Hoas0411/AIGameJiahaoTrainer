extends Control

var fill := Color("eeeae0")
var edge := Color("b7b09d")
var beak := false
var cut := 12.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var p := PackedVector2Array([Vector2(cut, 2), Vector2(w-cut, 2), Vector2(w-2, cut), Vector2(w-2,h-cut), Vector2(w-cut,h-2),Vector2(cut,h-2),Vector2(2,h-cut)])
	if beak:
		p.append(Vector2(2,h*0.55))
		p.append(Vector2(-20,h*0.43))
		p.append(Vector2(2,h*0.25))
	p.append(Vector2(2,cut))
	draw_colored_polygon(p, fill)
	outline(p, Color("151e22"), 7)
	outline(p, edge, 2)
	var inset := Rect2(7,7,w-14,h-14)
	draw_line(inset.position+Vector2(cut,0),inset.position+Vector2(inset.size.x-cut,0),Color(1,1,1,0.32),1,true)
