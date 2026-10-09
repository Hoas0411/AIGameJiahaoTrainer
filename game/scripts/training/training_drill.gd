extends "res://scripts/level.gd"

@export_enum("定位", "平滑跟枪", "变向跟枪", "中门缝", "目标切换", "移动停枪", "预瞄清角") var mode: int = 1
@export var random_seed: int = 9132026
@export var target_speed: float = 3.0
@export var rail_half_width: float = 6.0
@export var gap_width: float = 0.75
@export var door_panel_width: float = 6.0
@export var target_depth: float = -10.0
@export var round_seconds: float = 60.0
@export var target_sequence: PackedInt32Array = PackedInt32Array([2,3,1,4,0,5,4,1,3,2])
@export_enum("any", "head", "body") var required_zone: String = "any"
@export var alternating_strafe: bool = false
@export_enum("瞄过目标", "瞄不足目标") var movement_variant: int = 0
var rng := RandomNumberGenerator.new()
var clock: float = 0.0
var direction: float = 1.0
var current_speed: float = 0.0
var turn_at: float = 1.0
var trial_at: float = 1.5
var crossing: bool = false
var exposed: bool = false
var exposure_at: float = -1.0
var trial_shot: bool = false
var trial_hit: bool = false
var opportunities: int = 0
var successful_trials: int = 0
var false_starts: int = 0
var reaction_ms: Array[float] = []
var hit_times: Array[float] = []
var shot_speeds: Array[float] = []
var shot_grounded: Array[bool] = []
var weapon_shots: Dictionary = {}
var on_target_seconds: float = 0.0
var continuous_seconds: float = 0.0
var longest_seconds: float = 0.0
var visible_seconds: float = 0.0
var active_target: int = 0
var switch_at: float = 0.0
var switch_latencies: Array[float] = []
var wrong_target_hits: int = 0
var respawn_pending: Dictionary = {}
var overaim_ready: bool = false
var movement_ready: bool = false
var movement_start := Vector3.ZERO
var movement_successes: int = 0
var movement_invalid_hits: int = 0
var movement_expires: float = 0.0
var movement_opportunities: int = 0
var sequence_cursor: int = -1
var direction_mode: int = 0
var completed_crossings: int = 0
var missed_crossings: int = 0
var exposure_duration: float = 0.0
var exposure_windows_ms: Array[float] = []
var reversal_at: float = -1.0
var reacquisition_ms: Array[float] = []
var angular_error_sum: float = 0.0
var angular_error_samples: int = 0
var clearance_seen: Dictionary = {}
var clearance_hit_delays: Array[float] = []
var multiple_exposure_seconds: float = 0.0
var maximum_visible_targets: int = 0
var movement_trial_accepted: bool = false
var parameter_changes: Array[Dictionary] = []
var actual_heading: float = 1.0
var reversal_count: int = 0
var unresolved_reversals: int = 0
var switch_pending: bool = false
var invalid_zone_hits: int = 0
var invalid_strafe_hits: int = 0
var last_strafe_sign: float = 0.0
var movement_axis := Vector3.RIGHT
var required_movement_sign: float = 1.0
var movement_invalidated: bool = false
var session_context: RefCounted = preload("res://scripts/training/training_session_context.gd").new()
var visibility_offsets: Array[Vector3] = []
var initial_target_layout: Array = []
var outside_movement_lane_seconds: float = 0.0
@onready var game: Node = get_parent()
@onready var targets: Node3D = $Targets

func _ready() -> void:
	set_meta("training_focus",true)
	if mode == 3:
		# At the minimum 4 cm gap, sparse centre/edge rays leave false holes
		# between visible body fragments. 2.3125 cm silhouette spacing keeps
		# the projected opening covered throughout a continuous crossing.
		for i in 33:
			visibility_offsets.append(Vector3(lerpf(-0.37,0.37,i/32.0),1.2,0))
		visibility_offsets.append(Vector3(0,1.7,0))
	else:
		visibility_offsets.assign([Vector3(-0.37,1.2,0),Vector3(0,1.2,0),Vector3(0.37,1.2,0),Vector3(0,1.7,0)])
	if mode == 3 and game.training_options.has(game.level_index):
		var options: Dictionary = game.training_options[game.level_index]
		gap_width = options.gap_width
		target_speed = options.target_speed
		direction_mode = options.direction_mode
	rng.seed = random_seed
	for target in targets.get_children():
		initial_target_layout.append([target.position.x,target.position.y,target.position.z])
		target.struck.connect(_on_struck)
		target.persistent = mode in [1, 2, 3, 4, 5]
	if mode == 3:
		targets.get_child(0).set_enabled(false)
		update_gap(gap_width)
		parameter_changes.append({"time":0.0,"gap_width":gap_width,"target_speed":target_speed,"direction_mode":direction_mode})
	if mode == 4:
		for target in targets.get_children():
			target.health = 1.0
			target.remaining_health = 1.0
		_select_switch_target()
	if mode == 5:
		_start_movement_trial()
	call_deferred("_configure_round")

func _configure_round() -> void:
	game.session_length = round_seconds
	# Session-only UI state: Enter still opens the companion conversation.
	var bubble = game.get_node("BubbleUI")
	if Time.get_ticks_msec() >= bubble.operation_receipt_until:
		bubble.manually_folded = true
		bubble.bubble_time = 0.0
	var action_label: Label = game.ui.get_node("Root/HUD/Action")
	action_label.position = Vector2(320, 158)
	action_label.size = Vector2(960, 58)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mode == 3:
		game.player.weapon.equip(preload("res://resources/weapons/awm.tres"))
		game.player.weapon.cycle_sight()
	else:
		game.player.weapon.equip(preload("res://resources/weapons/m7.tres"))
	session_context.begin(game.player)

func _physics_process(delta: float) -> void:
	if not game.running or game.level != self:
		return
	clock += delta
	if not session_context.initial.is_empty():
		session_context.observe(game.player,delta,clock)
	for target in respawn_pending.keys():
		if clock >= float(respawn_pending[target]):
			if is_instance_valid(target):
				target.set_enabled(true)
			respawn_pending.erase(target)
	if mode in [1, 2]:
		_move_tracking(delta)
	elif mode == 3:
		_move_crossing(delta)
	elif mode == 5:
		if not _in_movement_lane():
			outside_movement_lane_seconds += delta
		_update_movement_trial()
	elif mode == 6:
		_measure_clearance(delta)
	_measure_tracking(delta)

func _move_tracking(delta: float) -> void:
	var target: Node3D = targets.get_child(0)
	var speed: float = target_speed * [0.7, 1.0, 1.35][difficulty]
	if mode == 2 and clock >= turn_at:
		direction = -direction
		turn_at = clock + rng.randf_range(0.55, 1.8)
	if absf(target.position.x) >= rail_half_width:
		direction = -signf(target.position.x)
	current_speed = move_toward(current_speed, direction * speed, delta * 14.0)
	if absf(current_speed) > 0.05 and signf(current_speed) != actual_heading:
		actual_heading = signf(current_speed)
		reversal_count += 1
		if reversal_at >= 0.0:
			unresolved_reversals += 1
		reversal_at = clock
	target.position.x = clampf(target.position.x + current_speed * delta, -rail_half_width, rail_half_width)

func _move_crossing(delta: float) -> void:
	var target: Node3D = targets.get_child(0)
	if not crossing:
		# A fresh opportunity starts only after the shared weapon is ready.
		if clock < trial_at or game.player.weapon.cooldown > 0 or game.player.weapon.reload_time > 0:
			return
		direction = (1.0 if rng.randi_range(0, 1) == 0 else -1.0) if direction_mode == 0 else (1.0 if direction_mode == 1 else -1.0)
		target.position = Vector3(-direction * rail_half_width, 0, target_depth)
		target.set_enabled(true)
		crossing = true
		exposed = false
		exposure_at = -1.0
		trial_hit = false
		trial_shot = false
		exposure_duration = 0.0
	target.position.x += direction * target_speed * [0.7, 1.0, 1.3][difficulty] * delta
	var now_visible: bool = _target_visible(target)
	if now_visible and exposure_at < 0:
		exposure_at = clock
		opportunities += 1
	exposed = now_visible
	if exposed:
		exposure_duration += delta
	if absf(target.position.x) > rail_half_width:
		if exposure_at >= 0.0:
			completed_crossings += 1
			missed_crossings += 0 if trial_hit else 1
			exposure_windows_ms.append(exposure_duration * 1000.0)
		target.set_enabled(false)
		crossing = false
		exposed = false
		trial_at = clock + rng.randf_range(1.0, 2.8)

func _target_visible(target: Node3D) -> bool:
	var eye: Vector3 = game.player.camera.global_position
	# Sample the silhouette, including its leading edge, through real door collision.
	for offset in visibility_offsets:
		var point: Vector3 = target.global_position + offset
		var ray := PhysicsRayQueryParameters3D.create(eye, point, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return true
	return false

func _measure_tracking(delta: float) -> void:
	if mode not in [1, 2]:
		return
	var camera: Camera3D = game.player.camera
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 150.0, 3)
	ray.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	visible_seconds += delta
	var toward: Vector3 = (targets.get_child(0).global_position + Vector3(0,1.15,0) - camera.global_position).normalized()
	angular_error_sum += pow(rad_to_deg((-camera.global_basis.z).angle_to(toward)), 2.0)
	angular_error_samples += 1
	if not hit.is_empty() and targets.is_ancestor_of(hit.collider):
		if reversal_at >= 0.0:
			reacquisition_ms.append((clock-reversal_at) * 1000.0)
			reversal_at = -1.0
		on_target_seconds += delta
		continuous_seconds += delta
		longest_seconds = maxf(longest_seconds, continuous_seconds)
	else:
		continuous_seconds = 0.0

func record_shot() -> void:
	shot_speeds.append(Vector2(game.player.velocity.x, game.player.velocity.z).length())
	shot_grounded.append(game.player.is_on_floor())
	var weapon_key: String = game.player.weapon.profile.resource_path + ("|laser" if game.player.weapon.laser_mode else "|optic_%.1f" % game.player.weapon.zoom_multiplier)
	weapon_shots[weapon_key] = int(weapon_shots.get(weapon_key,0))+1
	if mode == 3:
		if not crossing or not exposed:
			false_starts += 1
		elif not trial_shot:
			trial_shot = true
			reaction_ms.append((clock - exposure_at) * 1000.0)

func _on_struck(target: Node3D, _zone: String, _damage: float) -> void:
	hit_times.append(clock)
	if mode == 5:
		if movement_trial_accepted:
			return
		var stopped: bool = Vector2(game.player.velocity.x, game.player.velocity.z).length() <= 0.15
		if _zone == "head" and overaim_ready and movement_ready and stopped and not movement_invalidated and game.player.is_on_floor() and _in_movement_lane():
			movement_successes += 1
			movement_trial_accepted = true
			get_tree().call_group("session", "enemy_down", false)
			call_deferred("_start_movement_trial")
		else:
			movement_invalid_hits += 1
		return
	if mode == 3 and not trial_hit:
		trial_hit = true
		successful_trials += 1
		if trial_shot and not reaction_ms.is_empty():
			get_tree().call_group("companion_reaction_observers", "observe_reaction_sample", reaction_ms.back(), get_instance_id())
	elif mode == 4:
		if target.get_index() != active_target:
			wrong_target_hits += 1
			return
		if required_zone != "any" and _zone != required_zone:
			invalid_zone_hits += 1
			return
		var strafe_speed: float = game.player.velocity.dot(game.player.global_basis.x)
		if alternating_strafe and (absf(strafe_speed) < 0.3 or signf(strafe_speed) == last_strafe_sign or not game.player.is_on_floor()):
			invalid_strafe_hits += 1
			return
		if not switch_pending:
			last_strafe_sign = signf(strafe_speed)
			switch_pending = true
			switch_latencies.append((clock - switch_at) * 1000.0)
			get_tree().call_group("session", "enemy_down", false)
			call_deferred("_select_switch_target")
	elif mode == 6 and clearance_seen.has(str(target.name)) and target.remaining_health <= 0:
		clearance_hit_delays.append((clock - float(clearance_seen[str(target.name)].time)) * 1000.0)
	if mode not in [1, 2, 3, 4, 6] and target.remaining_health <= 0:
		respawn_pending[target] = clock + 0.6

func _select_switch_target() -> void:
	switch_pending = false
	sequence_cursor = (sequence_cursor + 1) % target_sequence.size()
	active_target = target_sequence[sequence_cursor]
	switch_at = clock
	targets.get_child(active_target).remaining_health = 1.0
	$PriorityMarker.position = targets.get_child(active_target).position + Vector3(0, 2.25, 0)

func _start_movement_trial() -> void:
	var target: Node3D = targets.get_child(0)
	var lateral: float = to_local(game.player.global_position).x - $PlayerSpawn.position.x if movement_opportunities > 0 else 0.0
	var target_side: float = -1.0 if rng.randi_range(0,1) == 0 else 1.0
	var distance: float = rng.randf_range(2.0,5.0)
	# Keep repeated camera-relative A/D practice near the station centre.
	# This changes only task presentation, never player movement parameters.
	if absf(lateral) > 1.5:
		target_side = signf(lateral) if movement_variant == 0 else -signf(lateral)
		if movement_variant == 0:
			distance = rng.randf_range(minf(7.2,absf(lateral)+1.0),7.2)
	target.position = Vector3($PlayerSpawn.position.x+distance*target_side,0,target_depth)
	target.set_enabled(true)
	overaim_ready = false
	movement_ready = false
	movement_trial_accepted = false
	movement_invalidated = false
	movement_expires = clock + [8.0, 6.0, 4.0][difficulty]
	movement_opportunities += 1

func _in_movement_lane() -> bool:
	var local: Vector3 = to_local(game.player.global_position) - $PlayerSpawn.position
	return absf(local.x) <= 6.1 and absf(local.z) <= 0.9

func _update_movement_trial() -> void:
	if clock >= movement_expires:
		_start_movement_trial()
		return
	if not _in_movement_lane():
		movement_invalidated = true
		return
	var toward: Vector3 = (targets.get_child(0).global_position + Vector3(0,1.7,0) - game.player.camera.global_position).normalized()
	var side: float = signf(targets.get_child(0).global_position.x - game.player.global_position.x)
	var horizontal_error: float = game.player.camera.global_basis.x.dot(toward)
	var correct_error_side: bool = horizontal_error * side < -sin(deg_to_rad(1.0)) if movement_variant == 0 else horizontal_error * side > sin(deg_to_rad(1.0))
	var near_head: bool = absf(horizontal_error) < sin(deg_to_rad(8.0)) and absf(game.player.camera.global_basis.y.dot(toward)) < sin(deg_to_rad(4.0)) and (-game.player.camera.global_basis.z).dot(toward) > 0.0
	if not overaim_ready and correct_error_side and near_head:
		overaim_ready = true
		movement_start = game.player.global_position
		movement_axis = game.player.global_basis.x
		required_movement_sign = -side if movement_variant == 0 else side
	if overaim_ready and (not game.player.is_on_floor() or game.player.abilities.dash_remaining > 0.0):
		movement_invalidated = true
	var displacement: float = (game.player.global_position-movement_start).dot(movement_axis)
	if overaim_ready and displacement*required_movement_sign >= 0.25 and not movement_invalidated:
		movement_ready = true

func update_gap(value: float) -> void:
	gap_width = clampf(value, 0.04, 1.2)
	$Doors/Left.position.x = -(door_panel_width/2.0 + gap_width/2.0)
	$Doors/Right.position.x = door_panel_width/2.0 + gap_width/2.0

func save_round_options() -> void:
	var options: Dictionary = {"gap_width":gap_width,"target_speed":target_speed,"direction_mode":direction_mode}
	game.training_options[game.level_index] = options.duplicate()
	options["time"] = clock
	parameter_changes.append(options)

func _measure_clearance(delta: float) -> void:
	var count: int = 0
	for target in targets.get_children():
		if not target.enabled or not _target_visible(target):
			continue
		count += 1
		var head: Vector3 = target.global_position + Vector3(0,1.7,0)
		if not clearance_seen.has(str(target.name)) and game.player.camera.is_position_in_frustum(head):
			var toward: Vector3 = (head-game.player.camera.global_position).normalized()
			clearance_seen[str(target.name)] = {"time":clock,"angular_error_deg":rad_to_deg((-game.player.camera.global_basis.z).angle_to(toward)),"position":game.player.global_position}
	maximum_visible_targets = maxi(maximum_visible_targets,count)
	if count > 1:
		multiple_exposure_seconds += delta

func metrics() -> Dictionary:
	var stopped_shots: int = 0
	for i in shot_speeds.size():
		if shot_speeds[i] <= 0.15 and shot_grounded[i]:
			stopped_shots += 1
	return {"schema": 1, "mode": mode, "seed": random_seed, "on_target_seconds": on_target_seconds,
		"tracking_ratio": on_target_seconds / maxf(visible_seconds, 0.001), "longest_tracking_seconds": longest_seconds,
		"opportunities": opportunities, "successful_trials": successful_trials, "false_starts": false_starts,
		"reaction_ms": reaction_ms, "shot_speeds": shot_speeds, "stopped_shots": stopped_shots,
		"switch_latencies_ms": switch_latencies, "wrong_target_hits": wrong_target_hits, "hit_times": hit_times,
		"movement_successes": movement_successes, "movement_opportunities": movement_opportunities,
		"movement_invalid_hits": movement_invalid_hits,
		"completed_crossings":completed_crossings,"missed_crossings":missed_crossings,"direction_mode":direction_mode,
		"exposure_windows_ms":exposure_windows_ms,"gap_width_m":gap_width,
		"reacquisition_ms":reacquisition_ms,"rms_angular_error_deg":sqrt(angular_error_sum/maxi(1,angular_error_samples)),
		"clearance_first_seen":clearance_seen,"clearance_hit_delays_ms":clearance_hit_delays,
		"multiple_exposure_seconds":multiple_exposure_seconds,"maximum_visible_targets":maximum_visible_targets,
		"parameter_changes":parameter_changes,"reversal_count":reversal_count,
		"unresolved_reversals":unresolved_reversals + (1 if reversal_at >= 0.0 else 0),
		"required_zone":required_zone,"alternating_strafe":alternating_strafe,"target_sequence":Array(target_sequence),"initial_target_layout":initial_target_layout,
		"invalid_zone_hits":invalid_zone_hits,"invalid_strafe_hits":invalid_strafe_hits,
		"movement_variant":movement_variant,"outside_movement_lane_seconds":outside_movement_lane_seconds,"movement_layout_revision":2,"session_context":session_context.report(game.player),
		"difficulty":difficulty,"base_target_speed_mps":target_speed,"actual_target_speed_mps":target_speed*([0.7,1.0,1.3][difficulty] if mode == 3 else [0.7,1.0,1.35][difficulty]),
		"rail_half_width_m":rail_half_width,"target_depth_m":target_depth,"weapon_shots":weapon_shots,"shot_grounded":shot_grounded}

func progress_text() -> String:
	if mode in [1, 2]:
		return "准心在靶 %.1f%%  ·  最长连续 %.2f 秒\n持续扫射移动目标；右键瞄准，R 换弹。准心覆盖与子弹命中分开计算。" % [100.0 * on_target_seconds / maxf(visible_seconds, 0.001), longest_seconds]
	if mode == 3:
		return "穿越机会 %d  ·  命中机会 %d  ·  空窗开枪 %d\n架住门缝，等待横穿；使用共享 AWM，B 切换瞄具。" % [opportunities, successful_trials, false_starts]
	if mode == 4:
		if alternating_strafe:
			return "交替 A / D 横移期间，命中优先目标头部\n非头部 %d · 脚步未满足 %d · 误打其他靶 %d" % [invalid_zone_hits,invalid_strafe_hits,wrong_target_hits]
		if required_zone == "head":
			return "只命中优先目标头部才进入下一靶\n非头部 %d · 误打其他靶 %d" % [invalid_zone_hits,wrong_target_hits]
		return "左组 2 → 1 → 3，再右组 5 → 6 → 4；当前优先靶 %d\n跟随标记命中后转移；误打非优先目标 %d 次。" % [active_target+1,wrong_target_hits]
	if mode == 5:
		if not _in_movement_lane():
			return "请回到中央射击带，再等待下一靶。\n本关练习横向修正；离开射击带的命中不算完整动作。"
		if movement_invalidated:
			return "本次跳跃或推进不算横移修正，等待下一靶。\n保持地面横移，再停稳射击。"
		return "%s %s → %s横移 %s → 停稳爆头 | 有效 %d / %d\n只移动到正确方向才算修正，身体命中不算完整动作。" % ["瞄过目标" if movement_variant == 0 else "瞄不足目标","✓" if overaim_ready else "○","反向" if movement_variant == 0 else "同向","✓" if movement_ready else "○",movement_successes,movement_opportunities]
	return "逐角预瞄 · 最多同时暴露 %d 靶 · 多角暴露 %.2fs\n沿挡墙清除三靶；F5 重开，F6 专项目录。" % [maximum_visible_targets,multiple_exposure_seconds]

func live_stats() -> String:
	var accuracy: String = "—" if game.shots == 0 else "%.1f%%" % (game.hits*100.0/game.shots)
	if mode in [1,2]:
		return "%d 命中 / %d 发    %s 命中率" % [game.hits,game.shots,accuracy]
	if mode == 3:
		return "%d / %d 命中机会    %s 命中率" % [successful_trials,opportunities,accuracy]
	if mode == 4:
		return "%d 有效转移    %s 命中率" % [switch_latencies.size(),accuracy]
	if mode == 5:
		return "%d 完整动作    %s 命中率" % [movement_successes,accuracy]
	return "%d / 3 清除    %s 命中率" % [game.kills,accuracy]
