@tool
extends Node3D

@export var left_offset := Vector3.ZERO
@export var right_offset := Vector3.ZERO
var rests: Dictionary = {}
var left_glove: MeshInstance3D
var right_glove: MeshInstance3D
var right_hand_pivot := Vector3(0.04,-0.09,0.08)
const LEFT_FOREARM_AXIS := Vector3(0.4282, 0.469166, -0.772352)
const LEFT_FOREARM_CENTER := Vector3(-0.083063, -0.156296, -0.122193)
const M7_RELOAD_FOREARM_ROLL := 135.0
const M7_FOREGRIP_OFFSET := Vector3(-0.03, 0.07, 0.11)
var left_rest_basis := Basis.IDENTITY

func _ready() -> void:
	for child in $Model.get_children():
		if child is Node3D:
			rests[child] = child.position
			if str(child.name) == "Left_OperatorSleeveGlove" and child is MeshInstance3D:
				left_glove = child
				left_rest_basis = child.basis
			if str(child.name) == "Right_OperatorSleeveGlove" and child is MeshInstance3D:
				right_glove = child

func _process(_delta: float) -> void:
	for child in rests:
		child.position = rests[child] + (left_offset if str(child.name).begins_with("Left_") else right_offset)
	if left_glove == null or left_glove.mesh.get_blend_shape_count() < 2:
		return
	var weapon := get_parent().get_parent()
	var profile = weapon.get("profile")
	var is_m7: bool = (profile != null and profile.weapon_id == "m7") or bool(weapon.get_meta("test_m7",false))
	var reload_open := 0.0
	if is_m7:
		var player: AnimationPlayer = weapon.get_node_or_null("AnimationPlayer")
		if player != null and player.is_playing() and player.current_animation.begins_with("m7/reload"):
			var t := player.current_animation_position
			var close_end := 2.45 if player.current_animation.ends_with("reload_empty") else 2.30
			reload_open = smoothstep(0.20,0.65,t) * (1.0-smoothstep(1.75,close_end,t))
	left_glove.set_blend_shape_value(0, (1.0-reload_open) if is_m7 else 0.0)
	left_glove.set_blend_shape_value(1, reload_open)
	var left_base_position: Vector3 = rests[left_glove] + left_offset
	if is_m7:
		left_base_position += M7_FOREGRIP_OFFSET * (1.0-reload_open)
	var forearm_axis := (left_rest_basis * LEFT_FOREARM_AXIS).normalized()
	var forearm_roll := Basis(forearm_axis, deg_to_rad(M7_RELOAD_FOREARM_ROLL * reload_open))
	left_glove.basis = forearm_roll * left_rest_basis
	var pivot := left_base_position + left_rest_basis * LEFT_FOREARM_CENTER
	left_glove.position = pivot - left_glove.basis * LEFT_FOREARM_CENTER
	if right_glove != null:
		var counter_weight := clampf(absf(get_parent().rotation.z) / 0.40,0.0,1.0) if is_m7 else 0.0
		var counter := Basis.IDENTITY.slerp(get_parent().basis.orthonormalized().inverse() * Basis(Vector3.BACK,deg_to_rad(-45.0)), counter_weight)
		right_glove.basis = counter
		right_glove.position = rests[right_glove] + right_offset + right_hand_pivot - counter * right_hand_pivot



