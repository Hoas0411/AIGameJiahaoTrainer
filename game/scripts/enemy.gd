extends CharacterBody3D

signal eliminated(enemy: Node)
@export_enum("Cover", "Ramp", "Tracking", "Guard") var behavior: int = 0
@export var operator_target: bool = true
@export var externally_scheduled: bool = false
@export var health: float = 100.0
@export var strafe_speed: float = 4.5
@export var reaction_seconds: float = 0.5
@export var attack_damage: float = -1.0
@export var shooting_enabled: bool = false
@export var attack_interval: float = 0.65
@export var accuracy: float = 0.6
@export var peek_distance: float = 2.5
@export var wide_distance: float = 4.6
@export var jump_force: float = 6.8
@export var enabled_actions: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var ramp_target: Vector3 = Vector3(0, 3, 2)
var motion: MotionProfile = preload("res://resources/motion_baseline.tres")
var dead: bool = false
var origin: Vector3
var state_time: float = 1.0
var exposed_time: float = 0.0
var attack_time: float = 0.0
var phase: int = 0
var action: int = 0
var side: float = 1.0
var active: bool = true
var alert: bool = false
var player: Node3D
var action_label: String = "等待出击"
var stunned: float = 0.0
var move_sign: float = 1.0
var incoming_profile: WeaponProfile
var ammunition: int = 30
var burst_shots: int = 0
var reload_remaining: float = 0
const ROUND = preload("res://scenes/effects/bullet.tscn")



# 记录编辑器中摆放的位置，并获取训练玩家。
func _ready() -> void:
	add_to_group("enemies")
	strafe_speed = motion.walk_speed * motion.equipment_speed_multiplier
	jump_force = motion.jump_speed()
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	for part: String in ["ArmL", "ArmR", "ForearmL", "ForearmR"]:
		var shape_node: CollisionShape3D = get_node("Hitboxes/" + part + "/Shape")
		shape_node.shape = shape_node.shape.duplicate()
	incoming_profile = preload("res://resources/weapons/rifle.tres").duplicate()
	if attack_damage < 0:
		attack_damage = incoming_profile.damage
	ammunition = incoming_profile.magazine_size
	origin = global_position
	player = get_tree().get_first_node_in_group("player")
	state_time = randf_range(0.6, 1.4)
	move_sign = -1.0 if randf() < 0.5 else 1.0
	$Doll.play_pose("stand")



# 执行掩体策略或斜坡行进；侦察跳不会射击。
func _physics_process(delta: float) -> void:
	if dead or not active or not is_instance_valid(player) or not player.active:
		return
	state_time -= delta
	$CollisionShape3D.shape.height = motion.crouch_height if behavior == 1 else motion.stand_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height * 0.5
	attack_time -= delta
	if reload_remaining > 0:
		reload_remaining = maxf(0, reload_remaining - delta)
		if reload_remaining == 0:
			ammunition = incoming_profile.magazine_size
	velocity.y -= motion.gravity_value() * delta
	if stunned > 0:
		stunned -= delta
		velocity.x = move_toward(velocity.x, 0, delta * 8)
		velocity.z = move_toward(velocity.z, 0, delta * 8)
		move_and_slide()
		$Doll.play_pose("stun")
		update_hitboxes()
		action_label = "虎蹲压制 / 暂时失能"
		return
	var pose: String = "low_ready"
	var escape: Vector3 = charge_escape_direction()
	if not escape.is_zero_approx():
		velocity.x = escape.x * strafe_speed
		velocity.z = escape.z * strafe_speed
		pose = "run"
		action_label = "C4 逼位 / 离开爆炸范围"
	elif behavior == 0:
		pose = cover_movement(delta)
	elif behavior == 1:
		pose = ramp_movement(delta)
	elif behavior == 2:
		pose = tracking_movement(delta)
	else:
		velocity.x = 0
		velocity.z = 0
		if can_see_player():
			exposed_time += delta
			if exposed_time > reaction_seconds:
				attack()
				pose = "shoot"
		else:
			exposed_time = 0
	move_and_slide()
	var direction: Vector3 = player.global_position - global_position
	if direction.length() > 0.1:
		$Doll.rotation.y = atan2(direction.x, direction.z)
	if pose == "stand":
		pose = "low_ready"
	if can_see_player() and exposed_time > reaction_seconds:
		pose = "crouch_aim" if behavior == 1 else ("shoot" if attack_time > attack_interval - 0.12 else "aim")
	$Doll.aim_target = player.global_position + Vector3.UP * 1.3
	$Doll.play_pose(pose)
	update_hitboxes()
	if global_position.y < -10:
		global_position = origin



# 四种动作等概率抽取，完整走出、停留和退回掩体。
func cover_movement(delta: float) -> String:
	if phase == 0:
		velocity.x = 0.0
		velocity.z = 0.0
		if state_time <= 0:
			action = enabled_actions[randi() % enabled_actions.size()] if not enabled_actions.is_empty() else 0
			side = -1.0 if randf() < 0.5 else 1.0
			phase = 1
			exposed_time = 0.0
			state_time = 1.4 if action == 0 else 1.9
			action_label = ["短身 PEEK", "横向大拉", "起跳大拉", "跳跃侦察"][action]
			if action >= 2:
				velocity.y = jump_force
		return "stand"
	var distance: float = peek_distance if action == 0 else wide_distance
	if action == 3:
		distance = 0.0
	var destination: float = origin.x + side * distance if phase == 1 else origin.x
	var offset: float = destination - global_position.x
	velocity.x = clampf(offset * 8.0, -strafe_speed, strafe_speed)
	if phase == 1:
		if action != 3 and can_see_player():
			exposed_time += delta
			if exposed_time >= reaction_seconds:
				attack()
		if state_time <= 0:
			phase = 2
	elif absf(offset) < 0.12:
		phase = 0
		state_time = 999.0 if externally_scheduled else randf_range(0.65, 1.5)
		action_label = "重新架点"
	return "jump" if not is_on_floor() else ("run" if absf(velocity.x) > 0.5 else "shoot")



# 三人沿可编辑坡面向上蹲走，视线被墙体阻挡时不会隔墙攻击。
func ramp_movement(delta: float) -> String:
	var sees: bool = can_see_player()
	if sees:
		exposed_time += delta
		alert = exposed_time >= reaction_seconds
	else:
		exposed_time = 0.0
		alert = false
	var destination: Vector3 = ramp_target - global_position
	destination.y = 0
	var direction: Vector3 = destination.normalized() if destination.length() > 0.35 else Vector3.ZERO
	velocity.x = direction.x * (motion.crouch_speed * motion.ads_speed_multiplier if alert else motion.crouch_speed)
	velocity.z = direction.z * (motion.crouch_speed * motion.ads_speed_multiplier if alert else motion.crouch_speed)
	action_label = "发现玩家！" if alert else "蹲姿静步"
	if alert:
		attack()
	return "crouch"



# 用 NPC 眼睛到玩家胸口的射线进行视线判定。
func can_see_player() -> bool:
	var eye: Vector3 = global_position + Vector3(0, 1.55 if behavior == 0 else 1.2, 0)
	var target: Vector3 = player.global_position + Vector3(0, 1.1, 0)
	if eye.distance_to(target) > 65:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 5, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player



# 有反应延迟和瞄准误差的真实扫掠弹道，射出后仍被掩体阻挡。
func attack() -> void:
	if not shooting_enabled or attack_time > 0 or reload_remaining > 0 or attack_damage == 0:
		return
	if ammunition <= 0:
		reload_remaining = incoming_profile.reload_seconds
		burst_shots = 0
		return
	ammunition -= 1
	burst_shots += 1
	attack_time = 60.0 / incoming_profile.rpm
	if burst_shots >= 3:
		attack_time = maxf(attack_time, attack_interval)
		burst_shots = 0
	$Shot.play()
	$Doll/ShotFlash.show()
	get_tree().create_timer(0.065).timeout.connect(func():
		if is_instance_valid(self):
			$Doll/ShotFlash.hide())
	var round_instance: Node3D = ROUND.instantiate()
	round_instance.hit_player = true
	get_tree().current_scene.add_child(round_instance)
	round_instance.global_position = $Doll/ShotFlash.global_position
	var aim_point: Vector3 = player.global_position + Vector3.UP * (0.72 if player.crouched else 1.12)
	if randf() > accuracy:
		aim_point += Vector3(randf_range(0.8, 1.7) * (-1 if randf() < 0.5 else 1), randf_range(-0.2, 0.8), 0)
	incoming_profile.damage = attack_damage
	round_instance.launch((aim_point - round_instance.global_position).normalized(), incoming_profile, get_rid())



# 接收分部位伤害、统计命中并播放滑稽的向后倒地反馈。
func receive_hit(damage: float, zone: String) -> void:
	if dead:
		return
	get_tree().call_group("session", "begin_target_hit", self, zone)
	$Doll.show_hurt_face()
	health -= damage
	get_tree().call_group("session", "target_hit", zone, damage)
	if health > 0:
		return
	dead = true
	for region: Area3D in $Hitboxes.get_children():
		region.set_deferred("collision_layer", 0)
	$CollisionShape3D.set_deferred("disabled", true)
	$Doll.play_pose("death")
	get_tree().call_group("session", "complete_target_kill", self)
	eliminated.emit(self)
	get_tree().call_group("session", "enemy_down", operator_target)
	retire_after_death()

func retire_after_death() -> void:
	# Keep one readable hit/death beat, then remove the defeated silhouette.
	# The owning level may queue_free it later when its respawn timer expires.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property($Doll, "scale", Vector3(0.82, 0.03, 0.82), 0.18)
	await tween.finished
	if is_instance_valid(self) and dead:
		hide()



# 跟枪科目在限定横向区间内随机变向，练习持续跟踪与急停转火。
func tracking_movement(delta: float) -> String:
	if state_time <= 0 or absf(global_position.x - origin.x) > 2.7:
		move_sign *= -1.0
		state_time = randf_range(0.7, 1.7)
	velocity.x = move_toward(velocity.x, move_sign * strafe_speed, motion.acceleration * delta)
	velocity.z = 0
	if can_see_player():
		exposed_time += delta
		if exposed_time > reaction_seconds:
			attack()
	action_label = "横向变速"
	return "run"



# 跟随实际骨骼的头、胸、腿位置，而不是仅把整个碰撞组向下平移。
func update_hitboxes() -> void:
	if $Doll.skeleton == null:
		return
	$Hitboxes/Head.global_position = $Doll.bone_world("Head", Vector3(0, 0.4, 0))
	$Hitboxes/Body.global_position = $Doll.bone_world("Chest", Vector3(0, 0.06, 0))
	$Hitboxes/Abdomen.global_position = $Doll.bone_world("Spine", Vector3(0, -0.065, 0))
	$Hitboxes/Legs.global_position = ($Doll.bone_world("Shin_L") + $Doll.bone_world("Shin_R")) * 0.5
	for suffix: String in ["L", "R"]:
		_align_limb("Arm" + suffix, $Doll.bone_world("UpperArm_" + suffix), $Doll.bone_world("Forearm_" + suffix))
		_align_limb("Forearm" + suffix, $Doll.bone_world("Forearm_" + suffix), $Doll.bone_world("Hand_" + suffix))

func _align_limb(node_name: String, start: Vector3, end: Vector3) -> void:
	var region: Area3D = get_node("Hitboxes/" + node_name)
	var axis: Vector3 = end - start
	region.global_position = (start + end) * 0.5
	if axis.length() > 0.001:
		region.global_basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
		(region.get_node("Shape").shape as CapsuleShape3D).height = maxf(0.20, axis.length() + 0.12)



# 虎蹲炮触发明确失能动作和定时恢复，期间不会移动射击。
func apply_stun(seconds: float, impulse: Vector3) -> void:
	if dead:
		return
	stunned = maxf(stunned, seconds)
	velocity += impulse
	$Doll.play_pose("stun")



# 发现附近可见的已落地 C4 后离开危险区，使投掷能创造转火机会。
func charge_escape_direction() -> Vector3:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if not projectile.scene_file_path.ends_with("magnetic_charge.tscn"):
			continue
		if not projectile.attached or projectile.life < 0.45:
			continue
		var offset: Vector3 = global_position - projectile.global_position
		if offset.length() > 4.5:
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, projectile.global_position, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		offset.y = 0
		return offset.normalized() if offset.length() > 0.1 else Vector3.RIGHT
	return Vector3.ZERO
