extends MeshInstance3D

var timer: float = 0
@onready var kit: Node = get_parent()

func _ready() -> void:
	mesh = mesh.duplicate()
	top_level = true
	global_transform = Transform3D.IDENTITY

func _process(delta: float) -> void:
	visible = kit.player.active and kit.held_kind != "" and not kit.player.controls_blocked
	if not visible:
		return
	timer -= delta
	if timer > 0:
		return
	timer = 0.06
	var motion: MotionProfile = kit.motion
	var charge: bool = kit.held_kind == "charge"
	var forward: Vector3 = -kit.player.camera.global_basis.z
	var position: Vector3 = kit.player.camera.global_position + forward * 0.28
	var velocity: Vector3 = forward * (motion.charge_throw_speed if charge else motion.thumper_throw_speed) + kit.player.velocity * motion.throw_inheritance + Vector3.UP * (2 if charge else 0.3)
	var fuse: float = motion.charge_fuse if charge else motion.thumper_fuse
	var immediate := mesh as ImmediateMesh
	immediate.clear_surfaces()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	immediate.surface_add_vertex(position)
	var bounce_count: int = 0
	for i in mini(160, int(fuse / 0.04)):
		var next: Vector3 = position + velocity * 0.04
		var query := PhysicsRayQueryParameters3D.create(position, next, 5, [kit.player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			position = hit.position + hit.normal * 0.035
			immediate.surface_add_vertex(position)
			if charge: break
			velocity = velocity.bounce(hit.normal) * motion.restitution
			bounce_count += 1
			if bounce_count >= 4 or velocity.length() < 1.2: break
		else:
			position = next
			immediate.surface_add_vertex(position)
		velocity.y -= motion.projectile_gravity * 0.04
	immediate.surface_end()
