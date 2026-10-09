extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.1
@export var jump_velocity: float = 5.8
@export var gravity: float = 18.0
@export var sensitivity: float = 1.0
@export var yaw_coefficient: float = 0.010685713351
@export var ads_multiplier: float = 0.65
@export var laser_multiplier: float = 0.85
@export var base_fov: float = 90.0
@export var horizontal_fov: bool = true
@export var invulnerable: bool = false
@export var mouse_dpi: float = 800.0
@export var horizontal_sensitivity: float = 1.0
@export var vertical_sensitivity: float = 1.0
@export var monitor_distance: float = 1.33
@export var monitor_match: bool = true
var raw_counts: Vector2 = Vector2.ZERO
var measured_aim_ratios: Dictionary = {}
var water_surface: float = -1000.0
var swimming_speed: float = 3.2
var motion: MotionProfile = preload("res://resources/motion_baseline.tres")
var controls_blocked: bool = false
var combat_enabled: bool = true
var jump_origin: float = 0
var jump_clock: float = 0
var peak_y: float = 0
var airborne: bool = false
var last_jump_height: float = 0
var last_apex_seconds: float = 0
var last_air_seconds: float = 0
var health: float = 100.0
var active: bool = false
var crouched: bool = false
var sprinting: bool = false
var standing_clearance_shape := CapsuleShape3D.new()
var locomotion_feedback = preload("res://scripts/locomotion_presentation.gd").new()
var feedback_air_seconds := 0.0
var pending_landing_speed := 0.0
var pending_landing_age := 0.0
var feedback_grounded_once := false
var lean_toggle_mode: bool = false
var lean_target: float = 0.0
var lean_value: float = 0.0
var lean_from: float = 0.0
var lean_elapsed: float = 0.0
var lean_duration: float = 0.0
@onready var lean_pivot: Node3D = $Head/LeanPivot
@onready var lean_probe: ShapeCast3D = $Head/LeanProbe
@onready var camera_mount: Node3D = $Head/LeanPivot/CameraMount
@onready var camera: Camera3D = $Head/LeanPivot/CameraMount/Camera3D
@onready var viewmodel_lean: Node3D = $Head/LeanPivot/CameraMount/Camera3D/ViewmodelLean
@onready var weapon: Node3D = $Head/LeanPivot/CameraMount/Camera3D/ViewmodelLean/Weapon
@onready var abilities: Node3D = $Abilities



# 初始化分组，供 NPC 获取当前训练者。
func _ready() -> void:
	process_priority = -20 # Compose camera translation before weapon and sight anchors.
	add_to_group("player")
	Input.use_accumulated_input = false
	var config := ConfigFile.new()
	if config.load("user://keybindings.cfg") == OK:
		lean_toggle_mode = bool(config.get_value("options", "lean_toggle", false))



# 原始鼠标位移转角；换算系数暴露于检查器，方便实测校准。
func _unhandled_input(event: InputEvent) -> void:
	if not active or controls_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		apply_mouse_motion(event)
	if event.is_action_pressed("reload"):
		weapon.reload()
	if event.is_action_pressed("laser") and not event.is_echo():
		weapon.cycle_sight()
	if event.is_action_pressed("zoom") and not event.is_echo():
		weapon.switch_optic()
	if lean_toggle_mode and event.is_action_pressed("lean_left") and not event.is_echo():
		set_lean_target(0.0 if lean_target < 0.0 else -1.0)
	if lean_toggle_mode and event.is_action_pressed("lean_right") and not event.is_echo():
		set_lean_target(0.0 if lean_target > 0.0 else 1.0)
	if event.is_action_pressed("weapon_one"):
		weapon.request_equip(preload("res://resources/weapons/awm.tres"))
	if event.is_action_pressed("weapon_two"):
		weapon.request_equip(preload("res://resources/weapons/m7.tres"))
	if event.is_action_pressed("fire_mode") and not event.is_echo():
		weapon.toggle_fire_mode()



# 使用未缩放的鼠标计数；独立入口支持无窗口环境验证转角数学。
func apply_mouse_motion(event: InputEventMouseMotion) -> void:
	var multiplier: float = aim_sensitivity_multiplier()
	raw_counts += event.screen_relative
	rotate_y(deg_to_rad(-event.screen_relative.x * sensitivity * yaw_coefficient * multiplier * horizontal_sensitivity))
	$Head.rotation.x = clampf($Head.rotation.x - deg_to_rad(event.screen_relative.y * sensitivity * yaw_coefficient * multiplier * vertical_sensitivity), -1.48, 1.48)



# 移动、蹲伏顶头检测、跳跃，以及可切换横向/纵向 FOV。
func sync_motion() -> void:
	walk_speed = motion.walk_speed
	sprint_speed = motion.sprint_speed
	crouch_speed = motion.crouch_speed
	jump_velocity = motion.jump_speed()
	gravity = motion.gravity_value()

func set_lean_toggle_mode(value: bool) -> void:
	lean_toggle_mode = value
	set_lean_target(0.0)

func reset_lean() -> void:
	locomotion_feedback.reset()
	feedback_air_seconds = 0.0
	pending_landing_speed = 0.0
	pending_landing_age = 0.0
	feedback_grounded_once = false
	lean_target = 0.0
	lean_value = 0.0
	lean_from = 0.0
	lean_elapsed = 0.0
	lean_duration = 0.0
	if is_node_ready():
		lean_pivot.position = Vector3(0.0, -motion.lean_neck_pivot, 0.0)
		camera_mount.position = Vector3(0.0, motion.lean_neck_pivot, 0.0)
		lean_pivot.rotation.z = 0.0
		viewmodel_lean.position = Vector3.ZERO
		viewmodel_lean.rotation.z = 0.0

func set_lean_target(value: float) -> void:
	value = clampf(value, -1.0, 1.0)
	if is_equal_approx(value, lean_target):
		return
	lean_from = lean_value
	lean_target = value
	lean_elapsed = 0.0
	lean_duration = motion.lean_seconds * absf(lean_target - lean_from)

func lean_ease_out(value: float) -> float:
	var normalized: float = clampf(value, 0.0, 1.0)
	var strength: float = maxf(0.001, motion.lean_curve_strength)
	return (1.0 - exp(-strength * normalized)) / (1.0 - exp(-strength))

func lean_camera_offset(value: float) -> Vector3:
	var roll: float = deg_to_rad(-motion.lean_angle_degrees * value)
	var neck: Vector3 = Vector3(0.0, motion.lean_neck_pivot, 0.0)
	var neck_arc: Vector3 = neck.rotated(Vector3.BACK, roll) - neck
	return Vector3(value * motion.lean_distance, -absf(value) * motion.lean_drop, 0.0) + neck_arc

func update_lean(delta: float) -> void:
	if controls_blocked and not is_equal_approx(lean_target, 0.0):
		set_lean_target(0.0)
	if not lean_toggle_mode:
		var held_target: float = 0.0
		if not controls_blocked:
			held_target = Input.get_axis("lean_left", "lean_right")
		if not is_equal_approx(held_target, lean_target):
			set_lean_target(held_target)
	if lean_duration <= 0.0001:
		lean_value = lean_target
	else:
		lean_elapsed = minf(lean_elapsed + delta, lean_duration)
		lean_value = lerpf(lean_from, lean_target, lean_ease_out(lean_elapsed / lean_duration))
	var effective_lean: float = lean_value
	var desired_offset: Vector3 = lean_camera_offset(effective_lean)
	lean_probe.target_position = desired_offset
	lean_probe.force_shapecast_update()
	if lean_probe.is_colliding():
		var desired_travel: float = desired_offset.length()
		if desired_travel > 0.0001:
			var safe_travel: float = desired_travel * lean_probe.get_closest_collision_safe_fraction()
			var safe_ratio: float = maxf(0.0, safe_travel - motion.lean_collision_margin) / desired_travel
			effective_lean *= clampf(safe_ratio, 0.0, 1.0)
	var camera_roll: float = deg_to_rad(-motion.lean_angle_degrees * effective_lean)
	lean_pivot.position = Vector3(
		effective_lean * motion.lean_distance,
		-motion.lean_neck_pivot - absf(effective_lean) * motion.lean_drop,
		0.0
	)
	lean_pivot.rotation.z = camera_roll
	# 腰射和开镜不是同一个肩部姿态。开镜时武器围绕瞄准轴产生更明显的
	# 反向肩部滚转；瞄具锚点由各武器渲染路径单独约束，不能把枪当作相机附件。
	var ads_weight: float = smoothstep(0.35, 0.95, weapon.ads_progress)
	var counter_roll: float = lerpf(
		motion.lean_viewmodel_counter_roll,
		motion.lean_ads_viewmodel_counter_roll,
		ads_weight
	)
	viewmodel_lean.rotation.z = camera_roll * counter_roll
	viewmodel_lean.position = Vector3(0.0, -absf(effective_lean) * motion.lean_viewmodel_drop, 0.0)

func can_stand() -> bool:
	# Query the whole standing volume: a central ray misses the capsule shoulder.
	var capsule := $CollisionShape3D.shape as CapsuleShape3D
	var margin: float = maxf(safe_margin * 2.0, 0.002)
	standing_clearance_shape.radius = maxf(0.01, capsule.radius - safe_margin)
	standing_clearance_shape.height = motion.stand_height - margin
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_clearance_shape
	query.transform = global_transform
	query.transform.origin += global_basis.y * (motion.stand_height / 2.0 + margin / 2.0)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func is_sprint_requested() -> bool:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return active and not controls_blocked and not crouched and not Input.is_action_pressed("crouch") \
		and input_dir.y < -0.1 and Input.is_action_pressed("sprint") \
		and not Input.is_action_pressed("fire") and not Input.is_action_pressed("aim") and not weapon.aiming

func movement_speed(aimed: bool, running: bool) -> float:
	var profile: WeaponProfile = weapon.profile
	var speed: float
	if crouched:
		speed = crouch_speed * (motion.ads_speed_multiplier if aimed else 1.0)
	elif aimed:
		speed = profile.ads_metres_per_second if profile.ads_metres_per_second > 0.0 else walk_speed * motion.ads_speed_multiplier * profile.ads_move_scale
	elif running:
		speed = profile.sprint_metres_per_second if profile.sprint_metres_per_second > 0.0 else sprint_speed * profile.sprint_move_scale
	else:
		speed = profile.walk_metres_per_second if profile.walk_metres_per_second > 0.0 else walk_speed * profile.walk_move_scale
	# Absolute weapon speeds already include their ADS/attachment scaling, but
	# equipment/passive multipliers apply equally to absolute and relative profiles.
	speed *= motion.equipment_speed_multiplier
	if abilities.passive_remaining > 0:
		speed *= motion.passive_speed_multiplier
	return speed

static func integrate_horizontal(current: Vector2, target: Vector2, acceleration: float, delta: float) -> Vector4:
	# Exact integral of move_toward's piecewise-linear velocity. Moving with the
	# endpoint velocity for the whole tick makes acceleration/braking distances
	# depend on physics frequency, even though the final speed looks correct.
	var change := target - current
	var distance := change.length()
	if distance <= 0.000001 or acceleration <= 0.0 or delta <= 0.0:
		return Vector4(current.x, current.y, current.x, current.y)
	var accelerating_seconds := minf(delta, distance / acceleration)
	var endpoint := current + change / distance * acceleration * accelerating_seconds
	var average := (current + endpoint) * (0.5 * accelerating_seconds / delta) \
		+ endpoint * (1.0 - accelerating_seconds / delta)
	return Vector4(endpoint.x, endpoint.y, average.x, average.y)

func _process(delta: float) -> void:
	if not active:
		return
	locomotion_feedback.motion = motion
	if pending_landing_speed > 0.0:
		# The impact happened at the end of a physics tick. Only advance the
		# impulse for elapsed ticks after it, not for the entire render interval.
		var after_impact := minf(delta, pending_landing_age)
		locomotion_feedback.advance(delta - after_impact, Vector2(velocity.x, velocity.z).length(), is_on_floor(), crouched)
		locomotion_feedback.land(pending_landing_speed)
		locomotion_feedback.advance(after_impact, Vector2(velocity.x, velocity.z).length(), is_on_floor(), crouched)
		pending_landing_speed = 0.0
		pending_landing_age = 0.0
	else:
		locomotion_feedback.advance(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), crouched)
	# A small translation at the neck mount, not an artificial pitch/roll shake.
	# The existing camera recoil and optic alignment remain their own owners.
	var aim_weight := 1.0 - smoothstep(0.0, 1.0, weapon.ads_progress) * 0.65
	camera_mount.position.y = motion.lean_neck_pivot + locomotion_feedback.camera_y * aim_weight

func _physics_process(delta: float) -> void:
	if not active:
		return
	if pending_landing_speed > 0.0:
		pending_landing_age += delta
	sync_motion()
	update_lean(delta)
	var wants_crouch: bool = Input.is_action_pressed("crouch") and not controls_blocked
	crouched = wants_crouch or (crouched and not can_stand())
	var shape := $CollisionShape3D.shape as CapsuleShape3D
	shape.height = motion.crouch_height if crouched else motion.stand_height
	$CollisionShape3D.position.y = shape.height / 2.0
	$Head.position.y = move_toward($Head.position.y, motion.crouch_eye if crouched else motion.stand_eye, delta * 5.0)
	var input_dir := Vector2.ZERO if controls_blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	# Resolve aiming from current input, not the previous render frame.
	weapon.aiming = weapon.wants_to_aim()
	sprinting = is_sprint_requested()
	var speed: float = movement_speed(weapon.aiming, sprinting)
	var grounded: bool = is_on_floor()
	var horizontal := Vector2(velocity.x, velocity.z)
	var desired := Vector2(direction.x, direction.z)
	var horizontal_integral := Vector4(horizontal.x, horizontal.y, horizontal.x, horizontal.y)
	if grounded:
		var acceleration: float = motion.braking if direction.is_zero_approx() else motion.acceleration
		horizontal_integral = integrate_horizontal(horizontal, desired * speed, acceleration, delta)
	elif not desired.is_zero_approx():
		# Preserve takeoff momentum when releasing Shift/aiming in flight.
		# No input means no ground friction applied in the air.
		horizontal_integral = integrate_horizontal(horizontal, desired * maxf(speed, horizontal.length()), motion.air_acceleration, delta)
	velocity.x = horizontal_integral.z
	velocity.z = horizontal_integral.w
	var endpoint_correction := Vector3(horizontal_integral.x - velocity.x, 0.0, horizontal_integral.y - velocity.z)
	if abilities.dash_remaining > 0:
		endpoint_correction = Vector3.ZERO
		abilities.dash_clock += minf(delta, abilities.dash_remaining)
		var fraction: float = minf(delta, abilities.dash_remaining) / delta
		abilities.dash_remaining = maxf(0, abilities.dash_remaining - delta)
		velocity.x = abilities.dash_vector.x * abilities.current_dash_speed * fraction
		velocity.z = abilities.dash_vector.z * abilities.current_dash_speed * fraction
	var jumping: bool = grounded and Input.is_action_just_pressed("jump") and not crouched and not controls_blocked
	if jumping:
		velocity.y = jump_velocity
	var swimming: bool = global_position.y < water_surface - 0.4
	var integrate_gravity: bool = (not grounded or jumping) and not swimming
	# move_and_slide integrates velocity over delta. Use midpoint velocity for
	# constant-gravity displacement, then retain the endpoint velocity for next tick.
	if integrate_gravity:
		velocity.y -= gravity * delta * 0.5
	elif grounded:
		velocity.y = 0.0
	if swimming:
		endpoint_correction = Vector3.ZERO
		velocity.x = direction.x * swimming_speed
		velocity.z = direction.z * swimming_speed
		velocity.y = clampf((water_surface - 0.7 - global_position.y) * 5.0, -2, 3)
		if Input.is_action_pressed("jump"):
			velocity.y = 4.0
	if not airborne and (velocity.y > 0 or not is_on_floor()):
		airborne = true
		jump_origin = global_position.y
		peak_y = jump_origin
		jump_clock = 0
	if airborne:
		jump_clock += delta
	if not grounded or jumping:
		feedback_air_seconds += delta
	var impact_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	# Keep the collision solver's slide velocity, then add only the admissible
	# endpoint correction. Never restore an into-wall component after a hit.
	for collision_index in get_slide_collision_count():
		var normal := get_slide_collision(collision_index).get_normal()
		if endpoint_correction.dot(normal) < 0.0:
			endpoint_correction = endpoint_correction.slide(normal)
	velocity += endpoint_correction
	if is_on_floor():
		if feedback_grounded_once and not grounded and feedback_air_seconds >= 0.1 and not swimming:
			if impact_speed >= pending_landing_speed:
				pending_landing_age = 0.0
			pending_landing_speed = maxf(pending_landing_speed, impact_speed)
		feedback_air_seconds = 0.0
		feedback_grounded_once = true
	if integrate_gravity and not is_on_floor():
		velocity.y -= gravity * delta * 0.5
	if airborne and global_position.y > peak_y:
		peak_y = global_position.y
		last_apex_seconds = jump_clock
	if abilities.was_dashing and abilities.dash_remaining <= 0:
		abilities.measured_dash_distance = Vector2(global_position.x - abilities.dash_start.x, global_position.z - abilities.dash_start.z).length()
		abilities.measured_dash_seconds = abilities.dash_clock
		abilities.was_dashing = false
	if airborne and is_on_floor():
		last_jump_height = peak_y - jump_origin
		last_air_seconds = jump_clock
		var fallen: float = peak_y - global_position.y
		if fallen >= motion.passive_fall_threshold:
			abilities.trigger_passive()
		if fallen > motion.fall_damage_threshold and combat_enabled:
			take_damage((fallen - motion.fall_damage_threshold) * motion.fall_damage_per_metre * (1.0 - motion.fall_damage_reduction))
		airborne = false
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var hip_vertical: float = vertical_fov()
	var zoom: float = lerpf(weapon.zoom_multiplier, weapon.profile.laser_zoom, smoothstep(0, 1, weapon.sight_blend))
	var zoom_vertical: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(hip_vertical * 0.5)) / zoom))
	camera.fov = lerpf(hip_vertical, zoom_vertical, smoothstep(0, 1, weapon.ads_progress))
	if global_position.y < -12:
		take_damage(100.0)



# 以 16:9 水平角为参照换算垂直视野，保持不同宽高比的投影一致。
func vertical_fov() -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov * 0.5)) / (16.0 / 9.0))) if horizontal_fov else base_fov



# 屏幕距离匹配随实际镜内 FOV 连续变化，倍镜和镭射倍率分别可调。
func aim_sensitivity_multiplier() -> float:
	if weapon.ads_progress <= 0:
		return 1.0
	var optic_key := "optic_" + str(weapon.zoom_multiplier).trim_suffix(".0")
	if measured_aim_ratios.has("laser") and measured_aim_ratios.has(optic_key):
		var measured_ratio: float = lerpf(measured_aim_ratios[optic_key], measured_aim_ratios["laser"], smoothstep(0, 1, weapon.sight_blend))
		return lerpf(1.0, measured_ratio, weapon.ads_progress)
	var key: String = "laser" if weapon.laser_mode else optic_key
	if measured_aim_ratios.has(key):
		return lerpf(1.0, measured_aim_ratios[key], weapon.ads_progress)
	var ratio: float = 1.0
	if monitor_match:
		var base_tan: float = tan(deg_to_rad(vertical_fov() * 0.5))
		var current_tan: float = tan(deg_to_rad(camera.fov * 0.5))
		ratio = current_tan / base_tan if monitor_distance < 0.001 else atan(monitor_distance * current_tan) / atan(monitor_distance * base_tan)
	var configured: float = laser_multiplier if weapon.laser_mode else ads_multiplier
	return ratio * lerpf(1.0, configured, weapon.ads_progress)



# 输出实际厘米/360，校准不再只比较两款游戏的同名显示数字。
func cm_per_360() -> float:
	return 914.4 / maxf(0.0001, mouse_dpi * sensitivity * horizontal_sensitivity * yaw_coefficient)



# NPC 命中反馈；无敌模式仍显示受击方向和音效。
func take_damage(amount: float) -> void:
	if not active:
		return
	$HurtSound.pitch_scale = randf_range(0.94, 1.06)
	$HurtSound.play()
	if amount > 0.0:
		weapon.recoil_pitch += deg_to_rad(0.5) * weapon.profile.flinch_scale
	if not invulnerable:
		health = maxf(0.0, health - amount)
	get_tree().call_group("session", "player_hurt")
	if health <= 0:
		get_tree().call_group("session", "finish", false)
