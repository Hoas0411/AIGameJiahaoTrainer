@tool
extends Node3D

@export var left_offset := Vector3.ZERO
@export var right_offset := Vector3.ZERO
@export_range(0.0, 1.0) var left_grip_shape := 0.0

var rests: Dictionary = {}
var left_glove: MeshInstance3D
var right_glove: MeshInstance3D
var left_rest_basis := Basis.IDENTITY
const LEFT_FOREARM_AXIS := Vector3(0.4282, 0.469166, -0.772352)
const LEFT_FOREARM_CENTER := Vector3(-0.083063, -0.156296, -0.122193)
const FOREARM_ROLL_DEGREES := 135.0
const VIEWMODEL_SCALE := 0.55

func _ready() -> void:
	$Model.scale = Vector3.ONE * VIEWMODEL_SCALE
	for child in $Model.get_children():
		if child is Node3D:
			rests[child] = child.position
			if child.name == "Left_OperatorSleeveGlove" and child is MeshInstance3D:
				left_glove = child
				left_rest_basis = child.basis
			elif child.name == "Right_OperatorSleeveGlove" and child is MeshInstance3D:
				right_glove = child

func _process(_delta: float) -> void:
	# The reload pose lifts the rifle across the screen and needs the original
	# arm reach. The compact first-person fit is only for holding and aiming.
	var weapon: Node = get_parent().get_parent()
	var arm_scale: float = lerpf(VIEWMODEL_SCALE, 1.0, clampf(weapon.reload_pose, 0.0, 1.0))
	$Model.scale = Vector3.ONE * arm_scale
	for child in rests:
		child.position = rests[child] + (left_offset if str(child.name).begins_with("Left_") else right_offset) / arm_scale
	if left_glove != null:
		var axis := (left_rest_basis * LEFT_FOREARM_AXIS).normalized()
		left_glove.basis = Basis(axis, deg_to_rad(FOREARM_ROLL_DEGREES)) * left_rest_basis
		var base_position: Vector3 = rests[left_glove] + left_offset / arm_scale
		var pivot := base_position + left_rest_basis * LEFT_FOREARM_CENTER
		left_glove.position = pivot - left_glove.basis * LEFT_FOREARM_CENTER
		if left_glove.mesh.get_blend_shape_count() >= 2:
			left_glove.set_blend_shape_value(0, left_grip_shape)
			left_glove.set_blend_shape_value(1, 0.0)
	if right_glove != null:
		right_glove.basis = Basis.IDENTITY
