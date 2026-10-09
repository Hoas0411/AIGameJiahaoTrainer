extends SceneTree
## Scripted play-through used for repeatable evidence (screens, frame times,
## audio events, round results). It drives the shared player through the same
## look axes and input actions a human uses; it is NOT a substitute for human
## feel testing. Run (Windows):  Godot.exe --path game -s res://scripts/tests/scripted_playtest.gd -- --out=<dir> [--courses=0,19] [--seconds=20]
## Output: <dir>/<course>_*.png, report.json, audio.wav (master bus capture).

var out_dir := "user://playtest"
var course_ids: Array = []
var seconds_per_course := 20.0
var capture_audio := true
var game: Node
var report: Dictionary = {"courses": {}}
var audio_record: AudioEffectRecord
var sound_log: Array = []
var known_playing: Dictionary = {}
var t0_usec := 0
var bot_reaction := 0.22
var bot_speed_deg := 540.0
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--courses="):
			for part in a.trim_prefix("--courses=").split(","): course_ids.append(int(part))
		elif a.begins_with("--seconds="): seconds_per_course = float(a.trim_prefix("--seconds="))
		elif a == "--no-audio": capture_audio = false
	rng.seed = 20261009
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func now() -> float:
	return (Time.get_ticks_usec() - t0_usec) / 1000000.0

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		await process_frame
		return
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))

func frames(n: int) -> void:
	for i in n: await process_frame

func seconds(s: float) -> void:
	var end := now() + s
	while now() < end: await process_frame

func run() -> void:
	t0_usec = Time.get_ticks_usec()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	if capture_audio:
		audio_record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, audio_record)
		audio_record.set_recording_active(true)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(30)
	var registry = load("res://scripts/course_registry.gd")
	if course_ids.is_empty(): course_ids = registry.ACTIVE_IDS.duplicate()
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["window"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	for id in course_ids:
		await play_course(int(id))
	if capture_audio:
		audio_record.set_recording_active(false)
		var rec := audio_record.get_recording()
		if rec: rec.save_to_wav(out_dir.path_join("audio.wav"))
	report["sound_log"] = sound_log
	var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("PLAYTEST_DONE ", out_dir)
	quit(0)

# ---------------------------------------------------------------- sounds
func poll_sounds(tag: String) -> void:
	_poll_node(game, tag)

func _poll_node(node: Node, tag: String) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		var id := node.get_instance_id()
		var playing: bool = node.playing
		if playing and not known_playing.get(id, false) and node.stream != null:
			var entry := {"t": snappedf(now(), 0.001), "course": tag, "node": str(node.get_path()).get_file(), "stream": node.stream.resource_path.get_file(), "volume_db": node.volume_db, "pitch": node.pitch_scale, "bus": str(node.bus)}
			if node is AudioStreamPlayer3D and is_instance_valid(game.player):
				entry["distance_m"] = snappedf(node.global_position.distance_to(game.player.camera.global_position), 0.01)
			sound_log.append(entry)
		known_playing[id] = playing
	for child in node.get_children(): _poll_node(child, tag)

# ---------------------------------------------------------------- targets
func candidate_points() -> Array:
	var points: Array = []
	var level: Node = game.level
	if not is_instance_valid(level): return points
	if game.level_index == 19:
		for sphere in level.get_node("Targets").get_children():
			points.append({"node": sphere, "point": sphere.global_position, "radius": float(level.target_radius)})
		return points
	for enemy in level.find_children("*", "CharacterBody3D", true, false):
		if enemy.get("dead") == true or not enemy.visible: continue
		if enemy.get("enabled") == false: continue
		var head: Node3D = enemy.get_node_or_null("Hitboxes/Head")
		var body: Node3D = enemy.get_node_or_null("Hitboxes/Body")
		if head == null: continue
		if head.collision_layer == 0: continue
		points.append({"node": enemy, "point": head.global_position, "radius": 0.11, "body": body.global_position if body else head.global_position})
	for target in get_nodes_in_group("training_targets"):
		if not level.is_ancestor_of(target) or not target.enabled or not target.is_visible_in_tree(): continue
		var head: Node3D = target.get_node_or_null("Hitboxes/Head")
		var p: Vector3 = head.global_position if head else target.global_position + Vector3(0, 1.4, 0)
		points.append({"node": target, "point": p, "radius": 0.12})
	return points

func visible_from_eye(p: Vector3, target: Node) -> bool:
	var cam: Camera3D = game.player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1, [game.player.get_rid()])
	return root.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func pick_target() -> Dictionary:
	var best: Dictionary = {}
	var best_angle := 999.0
	var cam: Camera3D = game.player.camera
	for c in candidate_points():
		var aim_point: Vector3 = c.point
		if not visible_from_eye(aim_point, c.node):
			if c.has("body") and visible_from_eye(c.body, c.node): aim_point = c.body
			else: continue
		var ang := rad_to_deg((-cam.global_basis.z).angle_to((aim_point - cam.global_position).normalized()))
		if ang < best_angle:
			best_angle = ang
			best = c.duplicate()
			best["aim"] = aim_point
	return best

func aim_error_deg(p: Vector3) -> float:
	var cam: Camera3D = game.player.camera
	return rad_to_deg((-cam.global_basis.z).angle_to((p - cam.global_position).normalized()))

# Rotate the same axes as mouse input (body yaw, head pitch) with a capped
# angular speed, so viewmodel sway, recoil and sensitivity paths stay real.
func steer_towards(p: Vector3, delta: float, speed_deg: float) -> void:
	var player: Node3D = game.player
	var cam: Camera3D = player.camera
	var to: Vector3 = p - cam.global_position
	var desired_yaw := atan2(-to.x, -to.z)
	var horizontal := Vector2(to.x, to.z).length()
	var desired_pitch := atan2(to.y, horizontal) - cam.rotation.x
	var yaw_err := wrapf(desired_yaw - player.rotation.y, -PI, PI)
	var head: Node3D = player.get_node("Head")
	var pitch_err := desired_pitch - head.rotation.x
	var step := deg_to_rad(speed_deg) * delta
	var total := Vector2(yaw_err, pitch_err).length()
	var k := 1.0 if total <= step else step / total
	player.rotation.y += yaw_err * k
	head.rotation.x = clampf(head.rotation.x + pitch_err * k, -1.48, 1.48)

func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func click_fire() -> void:
	if headless():
		# Mouse capture is unavailable without a window; call the same owners directly.
		if game.level_index == 19: game.level.shoot_click()
		else: game.player.weapon.fire()
		return
	if game.level_index == 19:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		Input.parse_input_event(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		Input.call_deferred("parse_input_event", up)
	else:
		Input.action_press("fire")
		await process_frame
		await process_frame
		Input.action_release("fire")

# ---------------------------------------------------------------- courses
func play_course(id: int) -> void:
	var tag := "c%02d" % id
	var entry := {"id": id, "frame_ms": [], "events": []}
	game.start_session(id)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(10)
	if game.level.has_method("begin_training"):
		game.level.begin_training()
	await seconds(1.0)
	await shot(tag + "_00_start")
	entry["start_title"] = str(game.level.name)
	var hold_aim := id in [0, 15]
	var automatic := id in [13, 6]
	var engaged_since := -1.0
	var current: Node = null
	var last_shot := -10.0
	var shot_index := 1
	var next_capture := 2.0
	var started := now()
	var end := started + (6.0 if id == 12 else seconds_per_course)
	var last := now()
	while now() < end and game.running and game.level_index == id:
		await process_frame
		var t := now()
		var delta := t - last
		last = t
		entry.frame_ms.append(snappedf(delta * 1000.0, 0.01))
		poll_sounds(tag)
		if id == 12:
			game.player.rotation.y += deg_to_rad(60.0) * delta
		else:
			var target: Dictionary = pick_target()
			if OS.has_environment("PT_DEBUG") and Engine.get_process_frames() % 60 == 0: print("dbg cands=", candidate_points().size(), " target=", not target.is_empty(), " mouse=", Input.mouse_mode)
			if target.is_empty():
				current = null
				engaged_since = -1.0
				if hold_aim: Input.action_release("aim")
				if automatic: Input.action_release("fire")
			else:
				if target.node != current:
					current = target.node
					engaged_since = t
				if t - engaged_since >= bot_reaction:
					steer_towards(target.aim, delta, bot_speed_deg)
					if hold_aim:
						Input.action_press("aim")
						if headless(): game.player.weapon.aiming = true
					var err: float = aim_error_deg(target.aim)
					var dist: float = game.player.camera.global_position.distance_to(target.aim)
					var tolerance: float = rad_to_deg(atan(float(target.radius) / maxf(dist, 0.5))) * 0.8
					var weapon: Node = game.player.weapon
					var ready: bool = weapon.cooldown <= 0 and weapon.reload_time <= 0 and (not hold_aim or weapon.ads_progress > 0.9)
					if automatic:
						if err < tolerance * 2.5 and ready:
							if headless(): game.player.weapon.fire()
							else: Input.action_press("fire")
						else: Input.action_release("fire")
					elif err < tolerance and ready and t - last_shot > 0.12:
						last_shot = t
						entry.events.append({"t": snappedf(t - started, 0.001), "shot": true, "err_deg": snappedf(err, 0.01)})
						click_fire()
		if t - started >= next_capture:
			await shot("%s_%02d" % [tag, shot_index])
			shot_index += 1
			next_capture += 3.0
	Input.action_release("fire")
	Input.action_release("aim")
	entry["shots"] = game.shots
	entry["hits"] = game.hits
	entry["kills"] = game.kills
	entry["headshots"] = game.headshots
	var ms: Array = entry.frame_ms.duplicate()
	ms.sort()
	if not ms.is_empty():
		entry["frame_ms_median"] = ms[ms.size() / 2]
		entry["frame_ms_p95"] = ms[int(ms.size() * 0.95)]
		entry["frame_ms_p99"] = ms[int(ms.size() * 0.99)]
		entry["frame_ms_max"] = ms.back()
		entry["hitches_over_33ms"] = ms.filter(func(v): return v > 33.3).size()
	entry.erase("frame_ms")
	entry["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	entry["video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	entry["static_mem_mb"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	entry["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	if id != 12 and game.running:
		game.finish(true)
		await seconds(0.8)
		await shot(tag + "_99_result")
	if is_instance_valid(game.level) and game.level.has_method("metrics"):
		entry["metrics"] = _jsonable(game.level.metrics())
	report.courses[str(id)] = entry
	print("PLAYTEST_COURSE ", id, " shots=", entry.shots, " hits=", entry.hits, " p95=", entry.get("frame_ms_p95", -1))
	game.get_node("TrainingResults").hide_panel()
	if game.level.has_method("is_open") and is_instance_valid(game.level):
		pass

func _jsonable(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v: d[str(k)] = _jsonable(v[k])
		return d
	if v is Array:
		var a := []
		for x in v: a.append(_jsonable(x))
		return a
	if v is Vector3: return [v.x, v.y, v.z]
	if v is Vector2: return [v.x, v.y]
	if v is float or v is int or v is bool or v is String or v == null: return v
	return str(v)
