extends Control

var records: Array = []
var reaction := false

func _draw() -> void:
	var box := Rect2(45, 28, maxf(1, size.x-70), maxf(1, size.y-60))
	draw_line(box.position+Vector2(0,box.size.y),box.end,Color("718182"),1)
	draw_line(box.position,box.position+Vector2(0,box.size.y),Color("718182"),1)
	var maximum := 100.0
	if reaction:
		maximum = 100.0
		for r in records:
			if r.get("mean_reaction_ms") != null: maximum = maxf(maximum,float(r.mean_reaction_ms)*1.15)
	var previous := Vector2.ZERO
	var has_previous := false
	for i in records.size():
		var value: Variant = records[i].get("mean_reaction_ms") if reaction else records[i].get("accuracy_percent",0)
		if value == null:
			has_previous = false
			continue
		var point := box.position+Vector2(box.size.x*i/maxf(1,records.size()-1),box.size.y*(1-float(value)/maximum))
		if has_previous: draw_line(previous,point,Color("e9ab52"),2,true)
		draw_circle(point,4,Color("e9ab52"))
		previous = point
		has_previous = true
	draw_string(ThemeDB.fallback_font,Vector2(3,36),"%.0f" % maximum,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	draw_string(ThemeDB.fallback_font,Vector2(20,size.y-29),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
