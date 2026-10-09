extends Node

var game: Node
var out := "D:/Codex/临时产物/jiahao-visual-20260930/before"
var report: Dictionary = {}
var failures: Array[String] = []
var root: Window

func _ready() -> void:
	root = get_tree().root
	game = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="): out = arg.trim_prefix("--visual-out=")
	call_deferred("run")

func settle(frames: int = 50) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("VISUAL_CAPTURE ", label)

func run() -> void:
	seed(930)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	await settle(90)
	for sample in [[12,"lobby"],[0,"awm"],[6,"range"],[19,"gridshot"]]:
		game.start_session(sample[0])
		await settle(90)
		game.player.invulnerable = true
		game.player.set_physics_process(false)
		game.player.set_process(false)
		game.player.controls_blocked = true
		game.running = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
		await settle(40)
		await capture(sample[1])
		var env_count := 0
		for world in game.find_children("*","WorldEnvironment",true,false):
			if world.environment != null: env_count += 1
		if env_count != 1: failures.append("Multiple active environments: " + str(sample[1]))
		var materials: Array = []
		for mesh in game.level.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			for s in mesh.mesh.get_surface_count():
				var mat = mesh.get_active_material(s)
				if mat is StandardMaterial3D and materials.size() < 80:
					materials.append({"node":str(game.level.get_path_to(mesh)),"name":mat.resource_name,"color":str(mat.albedo_color),"metallic":mat.metallic,"roughness":mat.roughness,"textured":mat.albedo_texture != null})
		var frame_ms: Array[float] = []
		var last := Time.get_ticks_usec()
		for frame in 120:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frame_ms.append(float(now-last)/1000.0)
			last = now
		frame_ms.sort()
		report[sample[1]] = {"materials":materials,"frame_ms_p50":frame_ms[60],"frame_ms_p95":frame_ms[114],"camera":str(root.get_camera_3d().global_transform)}
	game.start_session(6)
	await settle(60)
	game.running = false
	game.player.set_physics_process(false)
	game.player.controls_blocked = true
	var camera: Camera3D = root.get_camera_3d()
	var fx: Node3D = load("res://scenes/abilities/blast.tscn").instantiate()
	fx.radius = 3.0
	game.add_child(fx)
	fx.global_position = camera.global_position - camera.global_basis.z * 7.0 - Vector3(0,1,0)
	await get_tree().create_timer(0.12).timeout
	await capture("blast-early")
	await get_tree().create_timer(0.35).timeout
	await capture("blast-late")
	await get_tree().create_timer(3.0).timeout
	report["fx_freed"] = not is_instance_valid(fx)
	if is_instance_valid(fx): failures.append("Blast did not free itself")
	# Exercise normal movement, fire, reload, pause, and return through production methods.
	game.player.set_physics_process(true)
	game.player.set_process(true)
	game.player.controls_blocked = false
	game.running = true
	var initial_position: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(0.45).timeout
	Input.action_release("move_forward")
	var moved: float = game.player.global_position.distance_to(initial_position)
	if moved < 0.2: failures.append("Player movement failed")
	game.player.weapon.equip(game.RIFLE)
	var weapon: Node = game.player.weapon
	await get_tree().create_timer(weapon.profile.draw_seconds + 0.15).timeout
	var ammo_before: int = weapon.ammo
	weapon.fire()
	await settle(6)
	if weapon.ammo != ammo_before-1: failures.append("Weapon did not fire once")
	weapon.reload()
	await get_tree().create_timer(0.3).timeout
	if weapon.reload_pose <= 0.0: failures.append("Reload pose not exposed to arms")
	await get_tree().create_timer(4.0).timeout
	if weapon.reload_pose != 0.0: failures.append("Reload pose did not reset")
	get_tree().paused = true
	game.resume()
	if get_tree().paused: failures.append("Resume failed")
	game.enter_hub()
	await settle(45)
	if game.level_index != 12: failures.append("Return to hub failed")
	report["movement_metres"] = moved
	report["failures"] = failures
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["gpu"] = RenderingServer.get_video_adapter_name()
	report["user_dir"] = OS.get_user_data_dir()
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("VISUAL_CAPTURE_COMPLETE ", out)
	get_tree().quit(0 if failures.is_empty() else 2)
