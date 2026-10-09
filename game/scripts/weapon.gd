extends Node3D

signal sight_changed(multiplier: float, is_laser: bool)
signal sight_notice_reset

const M7_PRESENTATION_SCALE_HIP := Vector3.ONE * 1.22
const M7_PRESENTATION_SCALE_ADS := Vector3.ONE * 1.05

@export var profile: WeaponProfile
@export var hip_position := Vector3(0.1475, -0.091, -0.500)
@export var hip_pitch_degrees: float = 0.34
@export var hip_roll_degrees: float = 0.0
@export var hip_yaw_degrees: float = 5.99
@export var scope_position := Vector3(0.0, -0.07144, -0.60)
@export var laser_position := Vector3(-0.0325, -0.088, -0.323)
@export var laser_cant_degrees: float = 38.0
@export var recoil_return: float = 8.0
var ammo: int = 5
var cooldown: float = 0.0
## Set when a menu click resumes play: the held button must be released before it can fire.
var trigger_hold_block: bool = false
var reload_time: float = 0.0
var reload_pose: float = 0.0
var aiming: bool = false
var laser_mode: bool = true
var ads_progress: float = 0.0
var recoil: float = 0.0
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0
var clock: float = 0.0
var shot_clock: float = 10.0
var shot_index: int = 0
var bolt_played: bool = true
var laser_target := Vector3.ZERO
var zoom_multiplier: float = 3.0
@export var bolt_pull: float = 0.0
@export var bolt_lift: float = 0.0
@export var magazine_drop: float = 0.0
var bolt_rotation_rest := Vector3.ZERO
var bolt_part: Node3D
var bolt_rest := Vector3.ZERO
var magazines: Array[Node3D] = []
var magazine_roots: Array[Node3D] = []
var magazine_rest: Array[Vector3] = []
var reload_total: float = 0.0
var breath_remaining: float = 0.0
var holding_breath: bool = false
var pending_profile: WeaponProfile
var switch_remaining: float = 0.0
var sight_blend: float = 1.0
var optic_center := Vector2(.5,.5)
var optic_radius := Vector2(.16,.28)
var sprint_recovery: float = 0.0
var single_fire: bool = false
var spread_bloom: float = 0.0
var frame_seconds: float = 0.0
const BULLET = preload("res://scenes/effects/bullet.tscn")
const AWM_ACTIONS = preload("res://resources/animations/awm_actions.tres")
const M7_ACTIONS = preload("res://resources/animations/m7_actions.tres")
const AWM_SHOT = preload("res://assets/audio/awm_20260922/shot.wav")
const AWM_BOLT = preload("res://assets/audio/awm_20260922/bolt.wav")
const AWM_RELOAD = preload("res://assets/audio/awm_20260922/reload_tactical.wav")
const AWM_RELOAD_EMPTY = preload("res://assets/audio/awm_20260922/reload_empty.wav")
const RIFLE_SHOT = preload("res://assets/audio/shot.wav")
const RIFLE_RELOAD = preload("res://assets/audio/reload.wav")
const M7_SHOT = preload("res://resources/audio/m7_reference/shot.wav")
const M7_RELOAD_EMPTY = preload("res://resources/audio/m7_reference/reload_empty.wav")
@onready var player: CharacterBody3D = find_parent("Player") as CharacterBody3D



# 缓存导出的活动零件，静态材质合批不影响枪栓和弹匣运动。
func _ready() -> void:
	$AnimationPlayer.add_animation_library(&"awm",AWM_ACTIONS)
	$AnimationPlayer.add_animation_library(&"m7",M7_ACTIONS)
	bolt_part = $Model/AWM.find_child("BoltAssembly", true, false) as Node3D
	if bolt_part:
		bolt_rest = bolt_part.position
		bolt_rotation_rest = bolt_part.rotation
	for model in [$Model/AWM, $Model/Rifle, $Model/M7]:
		var magazine := model.find_child("MagazineAssembly", true, false) as Node3D
		if magazine:
			magazine_roots.append(magazine)
			# Keep the public visible-mesh interface used by inspection consumers.
			if model != $Model/M7:
				magazines.append(magazine if magazine is MeshInstance3D else magazine.find_children("*", "MeshInstance3D", true, false)[0])
			magazine_rest.append(magazine.position)



# AWM 默认启用镭射瞄准，B 循环切换全部瞄具；第一帧忽略菜单点击。
func equip(data: WeaponProfile) -> void:
	$AnimationPlayer.stop()
	$AnimationPlayer.clear_queue()
	bolt_pull = 0
	bolt_lift = 0
	magazine_drop = 0
	$Model.position = Vector3.ZERO
	$Model.rotation = Vector3.ZERO
	$Model/Arms.left_offset = Vector3.ZERO
	$Model/Arms.right_offset = Vector3.ZERO
	$Model/Arms.position = Vector3.ZERO
	$Model/AWMArms.left_offset = Vector3.ZERO
	$Model/AWMArms.right_offset = Vector3.ZERO
	$Model/AWMArms.position = Vector3.ZERO
	profile = data
	$Model/Arms.visible = profile.weapon_id == "m7"
	$Model/AWMArms.visible = profile.weapon_id != "m7"
	single_fire = false
	spread_bloom = 0.0
	$Shot.stream = M7_SHOT if profile.weapon_id == "m7" else (RIFLE_SHOT if profile.automatic else AWM_SHOT)
	$Shot.volume_db = -9.0 if profile.weapon_id == "m7" else -5.0
	$WorldShot.stream = $Shot.stream
	$WorldShot.volume_db = -30.0
	$BoltSound.stream = AWM_BOLT
	$BoltSound.volume_db = -1.0
	pending_profile = null
	switch_remaining = 0.0
	breath_remaining = profile.breath_seconds
	$WorldShot.max_distance = maxf(1.0, profile.gunshot_audible_distance)
	$Muzzle.position = Vector3(0,0.021,-0.805 if profile.automatic else -0.877)
	$MuzzleFlash.position = Vector3(0,0.021,-0.82 if profile.automatic else -0.89)
	$LaserOrigin.position = Vector3(-0.058,0.018,-0.314) if profile.automatic else Vector3(-0.032,0.010,-0.584)
	if profile.weapon_id == "m7":
		$Muzzle.position = Vector3(0, 0.021, -0.510) * M7_PRESENTATION_SCALE_HIP
		$MuzzleFlash.position = $Muzzle.position
		$LaserOrigin.position = Vector3(0.0384, 0.0414, -0.2705) * M7_PRESENTATION_SCALE_HIP
	ammo = profile.magazine_size
	sprint_recovery = 0
	cooldown = profile.draw_seconds
	reload_time = 0
	ads_progress = 0
	recoil_pitch = 0
	recoil_yaw = 0
	recoil = 0
	shot_clock = 10
	shot_index = 0
	laser_mode = true
	sight_blend = 1.0
	zoom_multiplier = profile.scope_zoom
	$Model/AWM.visible = not profile.automatic
	$Model/Rifle.visible = profile.automatic and profile.weapon_id != "m7"
	$Model/M7.visible = profile.weapon_id == "m7"
	# Keep the M7 and both hands at the same first-person presentation scale.
	$Model.scale = M7_PRESENTATION_SCALE_HIP if profile.weapon_id == "m7" else Vector3.ONE
	$Model/M7.scale = Vector3.ONE
	for audio in [$Shot, $ReloadSound, $BoltSound, $WorldShot]:
		audio.stop()
	sight_notice_reset.emit()

func request_equip(data: WeaponProfile) -> void:
	if data == profile or pending_profile != null:
		return
	pending_profile = data
	switch_remaining = profile.stow_seconds
	if switch_remaining <= 0.0:
		equip(data)



func wants_to_aim() -> bool:
	return pending_profile == null and not player.controls_blocked and player.combat_enabled \
		and Input.is_action_pressed("aim") and reload_time <= 0 \
		and player.abilities.cast_time <= 0 and player.abilities.held_kind == ""

# 连续举枪、贴镜、侧倾、拉栓和换弹过渡，不在按右键瞬间替换画面。
func _process(delta: float) -> void:
	if not is_instance_valid(player) or not player.active:
		$LaserDot.hide()
		$LaserBeam.hide()
		return
	clock += delta
	if pending_profile != null:
		switch_remaining = maxf(0.0, switch_remaining - delta)
		if switch_remaining <= 0.0:
			equip(pending_profile)
	sprint_recovery = maxf(0, sprint_recovery - delta)
	if player.is_sprint_requested() and player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.1:
		sprint_recovery = profile.sprint_to_fire_seconds
	shot_clock += delta
	advance_fire_clock(delta)
	spread_bloom = maxf(0.0, spread_bloom - delta * profile.spread_recovery_degrees)
	if reload_time > 0:
		reload_time = maxf(0, reload_time - delta)
		if reload_time == 0:
			ammo = profile.magazine_size
	var using_skill: bool = (player.get_node("Abilities").cast_time > 0 or player.get_node("Abilities").held_kind != "")
	var cycling_bolt: bool = not profile.automatic and shot_clock > 0.50 and shot_clock < 1.70
	aiming = wants_to_aim()
	holding_breath = aiming and not laser_mode and Input.is_action_pressed("sprint") and breath_remaining > 0.0
	breath_remaining = maxf(0.0, breath_remaining - delta) if holding_breath else minf(profile.breath_seconds, breath_remaining + delta * 0.5)
	var ads_duration: float = profile.ads_seconds if profile.automatic or not laser_mode else profile.sight_switch_seconds
	ads_progress = move_toward(ads_progress, 1.0 if aiming else 0.0, delta / ads_duration)
	var blend: float = smoothstep(0.0, 1.0, ads_progress)
	sight_blend = move_toward(sight_blend, 1.0 if laser_mode else 0.0, delta / maxf(0.01,profile.sight_switch_seconds))
	if profile.weapon_id == "m7":
		var optic_blend: float = blend * (1.0 - smoothstep(0.0, 1.0, sight_blend))
		var presentation_scale: Vector3 = M7_PRESENTATION_SCALE_HIP.lerp(M7_PRESENTATION_SCALE_ADS, optic_blend)
		$Model.scale = presentation_scale
		$Muzzle.position = Vector3(0, 0.021, -0.510) * presentation_scale
		$MuzzleFlash.position = $Muzzle.position
		$LaserOrigin.position = Vector3(0.0384, 0.0414, -0.2705) * presentation_scale
	var optic_position: Vector3 = Vector3(0, -0.14, -0.43) if profile.automatic else scope_position
	if profile.weapon_id == "m7":
		optic_position = Vector3(0, -0.118, -0.35)
	var side_position: Vector3 = Vector3(0.14,-0.19,-0.40) if profile.automatic else laser_position
	if profile.weapon_id == "m7":
		side_position = Vector3(-0.01, -0.14, -0.34)
	var aimed_position: Vector3 = optic_position.lerp(side_position, smoothstep(0, 1, sight_blend))
	# Actual ground state drives a bounded, smoothed presentation layer. Weapon
	# stability affects handling stats, not unbounded world-space bob amplitude.
	var bob: Vector3 = player.locomotion_feedback.gun_offset * (1.0 - blend * 0.85)
	var lowered: float = 0.0
	if reload_time > 0:
		lowered = 0.0
	if using_skill:
		lowered = 0.27
	if pending_profile != null:
		lowered = 0.2 * (1.0 - switch_remaining / maxf(0.01, profile.stow_seconds))
	var resting_position: Vector3 = Vector3(0.24,-0.23,-0.50) if profile.automatic else hip_position
	if profile.weapon_id == "m7":
		resting_position = Vector3(0.115, -0.138, -0.50)
	position = resting_position.lerp(aimed_position, blend) + bob + Vector3(0, -lowered, recoil * 0.028)
	reload_pose = 0.0
	if reload_time > 0:
		var reload_progress: float = 1.0 - reload_time / maxf(0.01,reload_total)
		reload_pose = clampf(minf(reload_progress / 0.12, (1.0 - reload_progress) / 0.15), 0, 1)
	var reload_offset: Vector3 = Vector3(0.02,0.06,-0.08) if profile.weapon_id == "m7" else (Vector3(-0.12,0.18,-0.20) if profile.automatic else Vector3(-0.05,-0.07,-0.11))
	position += reload_offset * reload_pose
	var bolt_motion: float = sin(clampf((shot_clock - 0.70) / 1.0,0,1)*PI) if cycling_bolt else 0.0
	position += Vector3(-0.016,-0.007,-0.012)*bolt_motion
	if bolt_part:
		bolt_part.position = bolt_rest + Vector3(0, 0, -bolt_pull)
		bolt_part.rotation = bolt_rotation_rest + Vector3(0, 0, bolt_lift)
	for index in range(magazine_roots.size()):
		magazine_roots[index].position = magazine_rest[index] + Vector3(0, -magazine_drop, 0)
	var cant_degrees: float = 32.0 if profile.weapon_id == "m7" else (-32.0 if profile.automatic else laser_cant_degrees)
	var weapon_kick: float = 0.06 if profile.weapon_id == "m7" else (0.035 if profile.automatic else 0.105)
	rotation = Vector3(recoil * weapon_kick + bolt_motion * 0.012, 0, deg_to_rad(cant_degrees) * blend * smoothstep(0, 1, sight_blend))
	if profile.weapon_id == "m7":
		rotation.x += deg_to_rad(4.1) * (1.0 - blend) * (1.0 - reload_pose)
		rotation.y += deg_to_rad(3.0) * (1.0 - blend) * (1.0 - reload_pose)
	if not profile.automatic:
		# Locate the reference pose from the muzzle first, then level the full
		# muzzle-to-ocular axis. Fade this presentation roll out while aiming.
		rotation.z += deg_to_rad(hip_roll_degrees) * (1.0-blend) * (1.0-reload_pose)
	rotation.z += lowered*2.0 + bolt_motion*0.025
	if not profile.automatic:
		rotation.x += deg_to_rad(hip_pitch_degrees)*(1.0-blend)*(1.0-reload_pose)
		rotation.y += deg_to_rad(hip_yaw_degrees)*(1.0-blend)*(1.0-reload_pose)
		if blend>.01 and sight_blend>.5 and reload_time<=0:
			# Keep the rifle pose independent of nearby cover. The laser ray
			# still intersects the real surface in update_laser().
			var eye: Vector3=player.camera.global_position
			var aim_point: Vector3=eye-player.camera.global_basis.z*160.0
			var zeroed: Basis=global_basis
			var cant: Basis=Basis(Vector3.BACK,deg_to_rad(laser_cant_degrees)*blend*sight_blend)
			for pass_index in 2:
				var bore_origin: Vector3=global_position+zeroed*Vector3(0,.021,0)
				zeroed=Basis.looking_at(aim_point-bore_origin,player.camera.global_basis.y)*cant
			zeroed=zeroed*Basis(Vector3.RIGHT,recoil*.105+bolt_motion*.012)
			global_basis=global_basis.slerp(zeroed,blend*sight_blend)
	elif profile.weapon_id == "m7" and blend > 0.01 and sight_blend > 0.5 and reload_time <= 0:
		# The canted M7 barrel is zeroed on the camera target while the laser
		# remains attached to its right-side emitter. Its roll matches the video.
		var eye: Vector3 = player.camera.global_position
		var aim_query := PhysicsRayQueryParameters3D.create(eye, eye-player.camera.global_basis.z*160.0, 3, [player.get_rid()])
		aim_query.collide_with_areas = true
		var aim_hit := get_world_3d().direct_space_state.intersect_ray(aim_query)
		var aim_point: Vector3 = aim_hit.get("position", eye-player.camera.global_basis.z*160.0)
		var zeroed: Basis = Basis.looking_at(aim_point-$Muzzle.global_position, player.camera.global_basis.y)
		zeroed = zeroed * Basis(Vector3.BACK, deg_to_rad(cant_degrees) * blend * sight_blend)
		global_basis = global_basis.slerp(zeroed, blend*sight_blend)
	var fully_scoped: bool = ads_progress>0.97 and sight_blend<0.03 and not profile.automatic
	$Model.visible = not using_skill
	$Model/AWM.visible = not profile.automatic
	$Model/Arms.visible = profile.weapon_id == "m7" and (not fully_scoped or (cycling_bolt and shot_clock>.78))
	$Model/AWMArms.visible = profile.weapon_id != "m7" and (not fully_scoped or (cycling_bolt and shot_clock>.78))
	$Model/AWMArms.position = Vector3(0.18,-0.02,-0.10) if fully_scoped else Vector3.ZERO
	if not profile.automatic and bolt_part:
		var grip_weight: float = smoothstep(.67,.86,shot_clock)*(1.0-smoothstep(1.47,1.70,shot_clock)) if cycling_bolt else 0.0
		if reload_time>0 and reload_total>3.0:
			var reload_elapsed: float = reload_total-reload_time
			grip_weight = maxf(smoothstep(.05,.15,reload_elapsed)*(1.0-smoothstep(.38,.60,reload_elapsed)),smoothstep(2.75,3.0,reload_elapsed)*(1.0-smoothstep(3.40,3.65,reload_elapsed)))
		if grip_weight>0.0:
			# Handle endpoint and palm rest come from the editable AWM/arm sources.
			var handle: Vector3 = $Model.to_local(bolt_part.to_global(Vector3(-.05139,-.014275,-.04092)))
			var grip: Vector3 = handle-Vector3(.027,-.10,.085)-Vector3(0,.024,0)
			$Model/AWMArms.right_offset = $Model/AWMArms.right_offset.lerp(grip,grip_weight)
	if not bolt_played and shot_clock > 0.80:
		$BoltSound.play()
		bolt_played = true
	recoil = move_toward(recoil,0,delta*7.0) if profile.automatic else recoil*exp(-delta*11.0)
	recoil_pitch = lerpf(recoil_pitch, 0, 1.0 - exp(-delta * recoil_return))
	recoil_yaw = lerpf(recoil_yaw, 0, 1.0 - exp(-delta * recoil_return))
	var sway: float = deg_to_rad(profile.sway_degrees) * blend * (0.1 if holding_breath else 1.0)
	var firing_shake: float = sin(shot_clock * 85.0) * exp(-shot_clock * 18.0) * deg_to_rad(0.4) * profile.firing_camera_stability
	player.camera.rotation.x = recoil_pitch + sin(clock * 1.75) * sway + firing_shake
	player.camera.rotation.y = recoil_yaw + sin(clock * 1.13 + 0.4) * sway
	update_laser()
	if not player.controls_blocked and player.combat_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not using_skill and trigger_requests_shot():
		fire()
	else:
		cooldown = maxf(0.0, cooldown)

func advance_fire_clock(delta: float) -> void:
	frame_seconds = delta
	# Preserve fractional frame remainder during a burst; never accrue idle debt.
	cooldown = maxf(-delta, cooldown - delta)

func trigger_requests_shot() -> bool:
	if trigger_hold_block:
		if Input.is_action_pressed("fire"): return false
		trigger_hold_block = false
		return false
	return Input.is_action_pressed("fire") if profile.automatic and not single_fire else Input.is_action_just_pressed("fire")

func toggle_fire_mode() -> void:
	if profile.supports_single_fire and reload_time <= 0 and pending_profile == null:
		single_fire = not single_fire
		var session: Node = get_tree().current_scene
		if session != null and session.get("ability_message") != null:
			session.ability_message = "M7 · " + fire_mode_label() + "（N 切换）"
			session.ability_message_time = 2.0

func fire_mode_label() -> String:
	return "单发" if single_fire or not profile.automatic else "全自动"



# 准心弹道先校验枪口遮挡，再发射带重力的连续扫掠子弹。
func fire() -> void:
	if pending_profile != null or player.controls_blocked or not player.combat_enabled or sprint_recovery > 0 or cooldown > 0 or reload_time > 0 or not player.active or player.abilities.held_kind != "" or player.abilities.cast_time > 0:
		return
	if ammo <= 0:
		reload()
		return
	ammo -= 1
	cooldown = profile.shot_interval() + minf(0.0, cooldown)
	if shot_clock > 0.35:
		shot_index = 0
	shot_clock = 0
	recoil = profile.firing_weapon_stability
	bolt_played = profile.automatic
	$Shot.pitch_scale = randf_range(0.98,1.02) if profile.automatic else 1.0
	$Shot.play()
	# First-person fire used to play the same sample through both a dry player
	# and a 3D player. The phase/attenuation overlap produced the metallic ring.
	# WorldShot remains configured as the inspectable range carrier, but the
	# local weapon has one audible source, matching the reference sample.
	$WorldShot.stop()
	$MuzzleFlash.trigger()
	$AnimationPlayer.play(action_name("shoot"))
	if not profile.automatic:
		$AnimationPlayer.queue(action_name("bolt"))
	var camera: Camera3D = player.camera
	var spread: float = profile.hip_spread_degrees + spread_bloom
	if aiming:
		spread = lerpf(profile.hip_spread_degrees, profile.laser_spread_degrees if laser_mode else profile.ads_spread_degrees, ads_progress)
	if not player.is_on_floor():
		spread *= profile.jump_spread_multiplier
	elif player.crouched:
		spread *= profile.crouch_spread_multiplier
	if Vector2(player.velocity.x,player.velocity.z).length() > 0.5:
		spread *= profile.movement_spread_multiplier
	if not aiming and profile.hip_max_spread_degrees > 0:
		spread = minf(spread,profile.hip_max_spread_degrees)
	var angle: float = randf() * TAU
	var radial: float = sqrt(randf()) * deg_to_rad(spread)
	var direction: Vector3 = (-camera.global_basis.z + camera.global_basis.x * cos(angle) * radial + camera.global_basis.y * sin(angle) * radial).normalized()
	var bullet: Node3D = BULLET.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = camera.global_position
	var block_query := PhysicsRayQueryParameters3D.create(camera.global_position, $Muzzle.global_position, 1, [player.get_rid()])
	var blocked := get_world_3d().direct_space_state.intersect_ray(block_query)
	if not blocked.is_empty():
		direction = (blocked.position - camera.global_position).normalized()
	bullet.launch(direction, profile, player.get_rid())
	var recoil_factor: float = profile.recoil_scale * (profile.breath_recoil_scale if holding_breath else 1.0)
	var pitch_impulse: float = deg_to_rad(profile.recoil_degrees) * recoil_factor
	var yaw_impulse: float = deg_to_rad(sin(shot_index * 1.9) * profile.recoil_degrees * profile.horizontal_recoil_ratio) * recoil_factor
	if profile.persistent_recoil:
		# Recoil moves the same look axes as mouse input, so pulling down actually
		# compensates it. Camera-only exponential return erased automatic climb.
		player.get_node("Head").rotation.x = clampf(player.get_node("Head").rotation.x + pitch_impulse, -1.48, 1.48)
		player.rotation.y += yaw_impulse
	else:
		recoil_pitch += pitch_impulse
		recoil_yaw += yaw_impulse
	spread_bloom = minf(maxf(0.0, profile.hip_max_spread_degrees - profile.hip_spread_degrees), spread_bloom + profile.spread_growth_degrees)
	shot_index += 1
	get_tree().call_group("session", "shot_fired")



# 装填由资源时长驱动，期间退出镜瞄并播放可见的下枪动作。
func action_name(action: String) -> String:
	if profile.weapon_id == "m7":
		return "m7/" + action
	return action if profile.automatic else "awm/"+action

func reload() -> void:
	if reload_time > 0 or ammo == profile.magazine_size:
		return
	bolt_pull = 0
	bolt_lift = 0
	magazine_drop = 0
	bolt_played = true
	$BoltSound.stop()
	reload_total = profile.reload_duration(ammo == 0)
	reload_time = reload_total
	var animation: String = action_name("reload_empty" if (profile.weapon_id == "m7" or not profile.automatic) and ammo==0 else "reload")
	var animation_duration: float = $AnimationPlayer.get_animation(animation).length
	$AnimationPlayer.play(animation,0.08,animation_duration/reload_total)
	$ReloadSound.stream = M7_RELOAD_EMPTY if profile.weapon_id == "m7" else (RIFLE_RELOAD if profile.automatic else (AWM_RELOAD_EMPTY if ammo==0 else AWM_RELOAD))
	$ReloadSound.volume_db = -3.0 if profile.weapon_id == "m7" else (-7.0 if profile.automatic else 3.0)
	$ReloadSound.play()



# 镭射常亮并贴在真实碰撞表面，光束尺寸不受枪模缩放或转角影响。
func update_laser() -> void:
	# AWM's attached laser remains illuminated through the optic in the supplied
	# reference. Sight selection changes the aim pose, not attachment power.
	var visible_laser: bool = (laser_mode or not profile.automatic) and reload_time <= 0 and player.get_node("Abilities").cast_time <= 0 and player.get_node("Abilities").held_kind == ""
	$LaserDot.visible = visible_laser
	$LaserBeam.visible = visible_laser
	if not visible_laser:
		return
	var camera: Camera3D = player.camera
	var origin: Vector3 = camera.global_position
	var muzzle: Vector3 = $LaserOrigin.global_position
	var ray_start: Vector3 = origin if profile.automatic and profile.weapon_id != "m7" else muzzle
	var ray_direction: Vector3 = -camera.global_basis.z if profile.automatic and profile.weapon_id != "m7" else -$Model.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + ray_direction * 160, 3, [player.get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = hit.get("position", ray_start + ray_direction * 160)
	var obstacle_query := PhysicsRayQueryParameters3D.create(muzzle, point, 1, [player.get_rid()])
	var obstacle := get_world_3d().direct_space_state.intersect_ray(obstacle_query)
	if not obstacle.is_empty():
		point = obstacle.position
	laser_target = point
	$LaserDot.global_position = point + (origin - point).normalized() * 0.025
	$LaserDot.scale = Vector3.ONE * clampf(origin.distance_to(point) / 15.0, 0.45, 2.0)
	var beam_origin: Vector3 = muzzle
	# The AWM body uses its own presentation camera. Bridge that camera's emitter
	# projection into the world pass, while keeping both collision rays above at
	# the physical socket. Otherwise the beam starts halfway inside the lens.
	if not profile.automatic:
		var viewmodel: Node = get_node("Viewmodel")
		var presentation_camera: Camera3D = viewmodel.camera
		if presentation_camera != null and viewmodel.enabled:
			var emitter_uv: Vector2 = presentation_camera.unproject_position(muzzle) / Vector2(presentation_camera.get_viewport().size)
			var emitter_depth: float = (muzzle - origin).dot(-camera.global_basis.z)
			if emitter_depth > camera.near:
				beam_origin = camera.project_position(emitter_uv * camera.get_viewport().get_visible_rect().size, emitter_depth)
	$LaserBeam.global_position = (beam_origin + point) * 0.5
	if beam_origin.distance_to(point) > 0.03:
		$LaserBeam.look_at(point, Vector3.UP)
		$LaserBeam.scale = Vector3(1, 1, beam_origin.distance_to(point))



# B 顺序切换所有瞄具：镭射、主倍率、副倍率，再回到镭射。
func cycle_sight() -> void:
	if laser_mode:
		laser_mode = false
		zoom_multiplier = profile.scope_zoom
	elif not profile.automatic and is_equal_approx(zoom_multiplier, profile.scope_zoom):
		zoom_multiplier = profile.alternate_zoom
	else:
		laser_mode = true
	sight_changed.emit(profile.laser_zoom if laser_mode else zoom_multiplier, laser_mode)



# Alt 直接进入镜瞄并切换 AWM 的两档倍率，步枪进入 1.5 倍镜。
func switch_optic() -> void:
	if laser_mode or profile.automatic:
		zoom_multiplier = profile.scope_zoom
	else:
		zoom_multiplier = profile.alternate_zoom if is_equal_approx(zoom_multiplier, profile.scope_zoom) else profile.scope_zoom
	laser_mode = false
	sight_changed.emit(zoom_multiplier, false)
