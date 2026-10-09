extends Node3D

# Stable IDs match CompanionActor.FaceExpression; 0/1 retain the original assets.
const MODELS := {
	2: preload("res://assets/models/companions/expressions_20260930/happy.glb"),
	3: preload("res://assets/models/companions/expressions_20260930/excited.glb"),
	4: preload("res://assets/models/companions/expressions_20260930/smug.glb"),
	5: preload("res://assets/models/companions/expressions_20260930/angry.glb"),
	6: preload("res://assets/models/companions/expressions_20260930/scared.glb"),
}
var instances: Dictionary = {}

func show_expression(value: int) -> void:
	for node in instances.values():
		node.hide()
	if not MODELS.has(value):
		return
	if not instances.has(value):
		var model: Node3D = MODELS[value].instantiate()
		model.name = "Expression_%d" % value
		model.scale = Vector3.ONE * 0.67
		add_child(model)
		instances[value] = model
	instances[value].show()
