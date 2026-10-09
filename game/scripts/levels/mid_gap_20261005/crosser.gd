extends "res://scripts/enemy.gd"

signal training_hit(zone: String)
var enabled := false
var crossing_kind := 0
var crossing_direction := 1.0
var crossing_time := 0.0
var crossing_speed := 5.8

func _ready() -> void:
	super._ready()
	$CollisionShape3D.disabled = true
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	for region in $Hitboxes.get_children(): region.collision_layer = 2 if value else 0

func start_crossing(kind: int, direction: float, speed_multiplier: float = 1.0) -> void:
	crossing_kind = kind
	crossing_direction = direction
	crossing_time = 0.0
	crossing_speed = (8.4 if kind == 2 else 5.8) * speed_multiplier
	position = Vector3(-direction * 3.6, 0, -0.7)
	_face_player()
	$Doll.position = Vector3.ZERO
	$Doll.play_pose(["run", "jump", "crouch"][kind])
	if $Doll.animator:
		$Doll.animator.speed_scale = speed_multiplier
		$Doll.animator.advance(0.25)
	set_enabled(true)
	update_hitboxes()

func _physics_process(delta: float) -> void:
	var owner_level: Node = get_parent().get_parent()
	if not owner_level.crossing or not owner_level.game.running: return
	crossing_time += delta
	position.x += crossing_direction * crossing_speed * delta
	# Jump peaks as the runner crosses the opening; sliding uses the rig's
	# crouch pose and a faster, continuous ground trajectory, not mesh scaling.
	position.y = maxf(0.0, 1.15 * (1.0 - pow(position.x / 2.2, 2))) if crossing_kind == 1 else 0.0
	_face_player()
	update_hitboxes()

func _face_player() -> void:
	if not is_instance_valid(player): return
	var toward_player: Vector3 = player.global_position - global_position
	toward_player.y = 0.0
	if toward_player.length_squared() > 0.001:
		$Doll.rotation = Vector3(0, atan2(toward_player.x, toward_player.z), 0)

func update_hitboxes() -> void:
	super.update_hitboxes()
	# Keep the torso hit regions aligned with the visible front-facing rig.
	# Limb capsules retain the actual bone-to-bone orientation from the base class.
	for region_name: String in ["Head", "Body", "Abdomen", "Legs"]:
		get_node("Hitboxes/" + region_name).global_basis = $Doll.global_basis.orthonormalized()

func receive_hit(damage: float, zone: String) -> void:
	if not enabled or zone == "explosive": return
	get_tree().call_group("session", "target_hit", zone, damage)
	training_hit.emit(zone)
	set_enabled(false)
