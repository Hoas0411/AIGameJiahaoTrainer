extends "res://scripts/enemy.gd"

@export var bay: int = 0
@export var lane_center: float = 4.0
@export var lane_half_width: float = 1.25
@export var start_delay: float = 0.0
var cover_clock := 0.0
var hiding := true
var destination_x := 0.0
var reveal_duration := 0.0
var training_hits := 0
var level_owner: Node3D
var rng := RandomNumberGenerator.new()
var move_speed := 1.25
var move_clock := 0.0
var decision_serial := 0
var last_decision := ""

func _ready() -> void:
	super._ready()
	level_owner = get_parent().get_parent()
	active = true
	shooting_enabled = false
	health = 100.0
	rng.randomize()
	cover_clock = rng.randf_range(0.35, 1.25) + start_delay
	move_clock = rng.randf_range(0.15, 0.65)
	destination_x = global_position.x
	$Doll.play_pose("crouch")
	# This course uses the existing Gridshot target palette on the existing rig.
	# Keep held weapons and shared character assets owned by their original scenes.
	for mesh in $Doll/Model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = preload("res://assets/models/segmented_cover_gridshot_v2_20261005/enemy_cyan.tres")

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player): return
	if not active or not player.active:
		$Doll.play_pose("crouch")
		update_hitboxes()
		return
	cover_clock -= delta
	attack_time -= delta
	stunned = maxf(0, stunned - delta)
	var pose := "crouch"
	if hiding:
		move_clock -= delta
		if move_clock <= 0: choose_hidden_move()
		var step := move_toward(global_position.x, destination_x, delta * move_speed)
		# Recheck head, torso and shoulders from the player's current eye each step.
		var candidate := Vector3(step, global_position.y, origin.z)
		if position_is_hidden(candidate) and stunned <= 0:
			velocity.x = (step - global_position.x) / maxf(delta, 0.001)
		else:
			velocity.x = 0.0
		if cover_clock <= 0 and stunned <= 0:
			if rng.randf() < 0.22:
				# Sometimes keep crouched and reposition instead of a predictable peek.
				cover_clock = rng.randf_range(0.3, 0.95)
				choose_hidden_move()
			else:
				hiding = false
				reveal_duration = 0.0
				cover_clock = rng.randf_range(0.18, 0.72)
				last_decision = "peek"
				decision_serial += 1
	else:
		velocity.x = 0.0
		pose = "aim"
		reveal_duration += delta
		# An enemy who acquires a continuously exposed player keeps the angle.
		# Brief peeks must not make a continuously visible player automatically safe.
		if cover_clock <= 0 and (not can_see_player() or reveal_duration >= 0.9):
			hiding = true
			# Short re-peeks and longer crouched transfers have different rhythms.
			cover_clock = rng.randf_range(0.12, 0.3) if rng.randf() < 0.25 else rng.randf_range(0.45, 1.65)
			choose_hidden_move()
			pose = "crouch"
	if stunned > 0: pose = "crouch"
	velocity.z = 0.0
	velocity.y -= motion.gravity_value() * delta
	$CollisionShape3D.shape.height = motion.crouch_height if hiding else motion.stand_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height * 0.5
	move_and_slide()
	var direction: Vector3 = player.global_position - global_position
	$Doll.rotation.y = atan2(direction.x, direction.z)
	$Doll.aim_target = player.camera.global_position
	$Doll.play_pose(pose)
	update_hitboxes()
	action_label = "掩体后蹲移" if hiding else "探头锁定 / 立即收回"

func position_is_hidden(base: Vector3) -> bool:
	for offset in [Vector3(0,1.1,0), Vector3(0,0.75,0), Vector3(-0.25,0.75,0), Vector3(0.25,0.75,0), Vector3(0,0.45,0)]:
		if level_owner.point_visible_from_player(base + offset): return false
	return true

func choose_hidden_move() -> void:
	move_clock = rng.randf_range(0.35, 1.15)
	move_speed = rng.randf_range(0.75, 1.8)
	decision_serial += 1
	last_decision = "stay"
	destination_x = global_position.x
	if rng.randf() < 0.18: return
	for attempt in 10:
		var target := lane_center + rng.randf_range(-lane_half_width, lane_half_width)
		if absf(target - global_position.x) < 0.35: continue
		var candidate := Vector3(target, global_position.y, origin.z)
		if not position_is_hidden(candidate): continue
		var occupied := false
		for other in get_parent().get_children():
			if other != self and not other.dead and other.bay == bay and absf(other.global_position.x-target)<0.6:
				occupied = true
		if occupied: continue
		destination_x = target
		last_decision = "left" if target < global_position.x else "right"
		return

func eye_position() -> Vector3:
	if $Doll.skeleton != null:
		return $Doll.bone_world("Head", Vector3(0, 0.21, 0))
	return global_position + Vector3.UP * (1.03 if hiding else 1.70)

func can_see_player() -> bool:
	return active and not dead and is_instance_valid(level_owner) and level_owner.enemy_sees_player(self)

func receive_hit(_damage: float, zone: String) -> void:
	if dead or not active: return
	training_hits += 1
	# Three registered hits regardless of shared weapon damage/head multiplier.
	super.receive_hit(34.0, zone)
