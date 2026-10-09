extends SceneTree
## Fixed-camera visual + performance capture for before/after comparison.
## Windows: Godot.exe --path game [--rendering-method X] -s res://scripts/tests/visual_capture.gd -- --out=<dir> [--courses=0,19] [--tag=baseline]
## Per course: player-view shots at fixed yaw offsets, a high oblique orthographic
## overview and a top orthographic view of the whole site, then a 4 s pan for frame timing.

var out_dir := "user://visual_capture"
var tag := "run"
var course_ids: Array = []
var profile_mode := false
var game: Node
var report: Dictionary = {"courses": {}}
const VIEW_YAWS := [0.0, -32.0, 32.0]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		elif a == "--profile": profile_mode = true
		elif a.begins_with("--courses="):
			for part in a.trim_prefix("--courses=").split(","): course_ids.append(int(part))
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		await process_frame
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [tag, name]))

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(30)
	if course_ids.is_empty(): course_ids = load("res://scripts/course_registry.gd").ACTIVE_IDS.duplicate()
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["tag"] = tag
	for id in course_ids:
		if profile_mode: await profile_course(int(id))
		else: await capture_course(int(id))
	var f := FileAccess.open(out_dir.path_join("%s_report.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("VISUAL_CAPTURE_DONE ", out_dir)
	quit(0)

func settle(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end: await process_frame

func capture_course(id: int) -> void:
	var name := "c%02d" % id
	var entry := {}
	game.start_session(id)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(5)
	if game.level.has_method("begin_training"): game.level.begin_training()
	await settle(4.0 if id == 19 else 2.0)
	var player: Node3D = game.player
	var base_yaw: float = player.rotation.y
	var head: Node3D = player.get_node("Head")
	var base_pitch: float = head.rotation.x
	for i in VIEW_YAWS.size():
		player.rotation.y = base_yaw + deg_to_rad(VIEW_YAWS[i])
		await frames(8)
		await shot("%s_view%d" % [name, i])
	player.rotation.y = base_yaw
	head.rotation.x = base_pitch
	# Frame timing while panning: the shared camera path, no gameplay input.
	var ms: Array = []
	var last := Time.get_ticks_usec()
	var start := last
	while Time.get_ticks_usec() - start < 4000000:
		await process_frame
		var now := Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
		var t := (now - start) / 1000000.0
		player.rotation.y = base_yaw + deg_to_rad(30.0) * sin(t * TAU / 4.0)
	player.rotation.y = base_yaw
	ms.sort()
	entry["frame_ms_median"] = snappedf(ms[ms.size() / 2], 0.01)
	entry["frame_ms_p95"] = snappedf(ms[int(ms.size() * 0.95)], 0.01)
	entry["frame_ms_p99"] = snappedf(ms[int(ms.size() * 0.99)], 0.01)
	entry["frame_ms_max"] = snappedf(ms.back(), 0.01)
	entry["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	entry["primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	entry["objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	entry["video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	entry["lights"] = count_lights(game.level)
	await capture_overview(name, entry)
	report.courses[str(id)] = entry
	print("CAPTURE ", id, " ", entry)

func count_lights(node: Node) -> Dictionary:
	var d := {"omni": 0, "spot": 0, "directional": 0, "shadowed": 0}
	for l in node.find_children("*", "Light3D", true, false):
		if not l.is_visible_in_tree(): continue
		if l is OmniLight3D: d.omni += 1
		elif l is SpotLight3D: d.spot += 1
		else: d.directional += 1
		if l.shadow_enabled: d.shadowed += 1
	return d

func level_bounds(level: Node) -> AABB:
	var box := AABB()
	var first := true
	for v in level.find_children("*", "VisualInstance3D", true, false):
		if not v.is_visible_in_tree() or v is Light3D or v is GPUParticles3D or v is CPUParticles3D: continue
		var b: AABB = v.global_transform * v.get_aabb()
		if b.size.length() > 400.0: continue # skydomes / backdrops
		if first: box = b; first = false
		else: box = box.merge(b)
	return box

func capture_overview(name: String, entry: Dictionary) -> void:
	var box := level_bounds(game.level)
	entry["bounds"] = [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 2000.0
	var center := box.get_center()
	var extent := maxf(box.size.x, box.size.z)
	var hud_layers: Array = []
	for layer in game.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			hud_layers.append(layer)
			layer.visible = false
	# High oblique orthographic overview (45 deg down, 35 deg yaw).
	cam.size = extent * 1.15
	var dir := Vector3(sin(deg_to_rad(35.0)), 1.0, cos(deg_to_rad(35.0))).normalized()
	cam.global_position = center + dir * (extent * 2.0 + 50.0)
	cam.look_at(center, Vector3.UP)
	cam.current = true
	await frames(6)
	await shot("%s_ortho_oblique" % name)
	cam.size = extent * 1.1
	cam.global_position = center + Vector3.UP * (box.size.y + 80.0)
	cam.look_at(center, Vector3.FORWARD)
	await frames(6)
	await shot("%s_ortho_top" % name)
	for layer in hud_layers: layer.visible = true
	cam.queue_free()
	game.player.camera.current = true
	await frames(2)


# ---------------------------------------------------------------- cost breakdown
func measure(label: String, seconds: float = 2.0) -> Dictionary:
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await frames(20)
	var ms: Array = []
	var gpu: Array = []
	var cpu: Array = []
	var proc: Array = []
	var phys: Array = []
	var last := Time.get_ticks_usec()
	var start := last
	while Time.get_ticks_usec() - start < int(seconds * 1000000):
		await process_frame
		var now := Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var r := {"label": label, "frame_ms": _med(ms), "gpu_ms": _med(gpu), "render_cpu_ms": _med(cpu), "process_ms": _med(proc), "physics_ms": _med(phys), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	print("PROFILE ", r)
	return r

func _med(a: Array) -> float:
	if a.is_empty(): return -1.0
	var b := a.duplicate()
	b.sort()
	return snappedf(float(b[b.size() / 2]), 0.01)

func profile_course(id: int) -> void:
	game.start_session(id)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(5)
	if game.level.has_method("begin_training"): game.level.begin_training()
	await settle(2.5)
	var rows: Array = []
	rows.append(await measure("base"))
	# PCSS (angular distance > 0) versus filtered hard shadows, everything else unchanged.
	var suns: Array = []
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l.visible and l.shadow_enabled:
			suns.append([l, l.light_angular_distance, l.shadow_blur])
			l.light_angular_distance = 0.0
			l.shadow_blur = 1.5
	rows.append(await measure("sun_pcf_instead_of_pcss"))
	for e in suns:
		e[0].light_angular_distance = e[1]
		e[0].shadow_blur = e[2]
	var vp: Viewport = root.get_viewport()
	vp.mesh_lod_threshold = 2.0
	rows.append(await measure("mesh_lod_threshold_2"))
	vp.mesh_lod_threshold = 4.0
	rows.append(await measure("mesh_lod_threshold_4"))
	vp.mesh_lod_threshold = 1.0
	var dists: Array = []
	for e in suns:
		dists.append(e[0].directional_shadow_max_distance)
		e[0].directional_shadow_max_distance = minf(e[0].directional_shadow_max_distance, 35.0)
	rows.append(await measure("sun_shadow_distance_35"))
	for i in suns.size(): suns[i][0].directional_shadow_max_distance = dists[i]
	var atlas: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	rows.append(await measure("sun_atlas_2048"))
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	rows.append(await measure("sun_filter_very_low"))
	RenderingServer.directional_soft_shadow_filter_set_quality(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	var env: Environment = game.get_node("WorldEnvironment").environment
	var saved := {"ssr": env.ssr_enabled, "ssil": env.ssil_enabled, "ssao": env.ssao_enabled, "glow": env.glow_enabled, "sdfgi": env.sdfgi_enabled, "fog": env.volumetric_fog_enabled}
	env.ssr_enabled = false
	rows.append(await measure("no_ssr"))
	env.ssil_enabled = false
	rows.append(await measure("no_ssr_ssil"))
	env.ssao_enabled = false
	env.glow_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	rows.append(await measure("no_post"))
	var lights: Array = []
	for l in root.find_children("*", "Light3D", true, false):
		if l.visible and not l is DirectionalLight3D:
			lights.append(l)
			l.visible = false
	rows.append(await measure("no_post_no_local_lights"))
	var shadows: Array = []
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l.shadow_enabled:
			shadows.append(l)
			l.shadow_enabled = false
	rows.append(await measure("no_post_no_lights_no_sun_shadow"))
	var arch: Node3D = game.level.get_node_or_null("Architecture")
	if arch:
		arch.visible = false
		rows.append(await measure("plus_hidden_architecture"))
		arch.visible = true
	game.player.weapon.visible = false
	game.get_node("CompanionActor").visible = false
	rows.append(await measure("plus_hidden_viewmodel_companion"))
	game.player.weapon.visible = true
	for l in lights: l.visible = true
	for l in shadows: l.shadow_enabled = true
	env.ssr_enabled = saved.ssr; env.ssil_enabled = saved.ssil; env.ssao_enabled = saved.ssao; env.glow_enabled = saved.glow; env.sdfgi_enabled = saved.sdfgi; env.volumetric_fog_enabled = saved.fog
	report.courses[str(id)] = {"profile": rows, "env": saved}
