extends Node

var weapon: Node3D
var player: CharacterBody3D
var left_upright: MeshInstance3D
var right_upright: MeshInstance3D
var applied_frames: int = 0
var last_correction := Vector3.ZERO

func _ready() -> void:
	process_priority = 110
	weapon = get_parent()
	call_deferred("setup")

func setup() -> void:
	player = weapon.player
	left_upright = weapon.get_node("Model/M7").find_child("Sight left V upright", true, false) as MeshInstance3D
	right_upright = weapon.get_node("Model/M7").find_child("Sight right V upright", true, false) as MeshInstance3D

func optic_world_center() -> Vector3:
	var left_center: Vector3 = left_upright.to_global(left_upright.mesh.get_aabb().get_center())
	var right_center: Vector3 = right_upright.to_global(right_upright.mesh.get_aabb().get_center())
	return (left_center + right_center) * 0.5

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.active:
		return
	if weapon.profile.weapon_id != "m7" or weapon.ads_progress < 0.35 or weapon.sight_blend > 0.15:
		return
	# Keep the physical M7 reflex-window centre on the camera aiming axis.
	# The gun may roll around this point, but the reticle cannot slide to an edge.
	var camera: Camera3D = player.camera
	var screen_size: Vector2 = weapon.get_viewport().get_visible_rect().size
	var physical_optic_center: Vector3 = optic_world_center()
	var depth: float = (physical_optic_center - camera.global_position).dot(-camera.global_basis.z)
	if depth <= camera.near:
		return
	var desired_world: Vector3 = camera.project_position(screen_size * 0.5, depth)
	var ads_weight: float = smoothstep(0.35, 0.95, weapon.ads_progress)
	var correction_world: Vector3 = (desired_world - physical_optic_center) * ads_weight
	last_correction = camera.global_basis.inverse() * correction_world
	player.viewmodel_lean.position += last_correction
	applied_frames += 1
