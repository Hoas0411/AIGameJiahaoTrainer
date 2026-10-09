extends Polygon2D

var active_button: Button

func _ready() -> void:
	color = Color("ec001e")
	for key in ["TrainingSelect", "Tracking", "Flick", "Reaction", "DoorGap", "Companion", "Tools", "RecordsOpen", "PreferencesOpen", "Close"]:
		var button := get_parent().get_node(key) as Button
		button.mouse_entered.connect(func(): highlight(button))
		button.focus_entered.connect(func(): highlight(button))
	highlight(get_parent().get_node("TrainingSelect"))

func highlight(button: Button) -> void:
	active_button = button
	var r := button.get_rect()
	var x := r.position.x - 16.0
	var y := r.position.y - 15.0
	var w := r.size.x + 14.0
	var h := r.size.y + 24.0
	polygon = PackedVector2Array([Vector2(x,y+18),Vector2(x+45,y-12),Vector2(x+68,y+5),Vector2(x+w-70,y-8),Vector2(x+w-57,y+12),Vector2(x+w,y),Vector2(x+w-32,y+h),Vector2(x-6,y+h+12)])

func _process(_delta: float) -> void:
	visible = is_instance_valid(active_button) and active_button.is_visible_in_tree() and not get_parent().get_node("Course0").visible
