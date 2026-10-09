extends "res://scenes/levels/range_honor_R36/honor.gd"

func _finish_materials()->void:
 super._finish_materials()
 var probe=get_node("HonorInteriorReflection")
 probe.position=Vector3(0,1.53,7.0)
 probe.size=Vector3(25,2.65,2.5)
