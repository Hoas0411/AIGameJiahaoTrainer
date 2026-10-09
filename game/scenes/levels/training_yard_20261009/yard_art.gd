extends Node3D
## Visual-only root of a Training Yard Kit assembly. Gameplay collision lives in the
## level scene. Repeated floor/wall/column modules are batched per chunk at load.

func _ready() -> void:
	var stats: Dictionary = preload("res://scripts/presentation/static_batcher.gd").batch(self, 12.0)
	# Floor plates and lane lines never cast a visible shadow (they are the lowest surface).
	preload("res://scripts/presentation/shadow_policy.gd").ground_receives_only(self, ["Floor", "Lines"])
	for mm in get_node("StaticBatches").get_children():
		var src_name: String = str(mm.multimesh.mesh.resource_name)
		if src_name.begins_with("TY_F2") or src_name.begins_with("TY_LINE"):
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("YARD_BATCH ", name, " ", stats)
