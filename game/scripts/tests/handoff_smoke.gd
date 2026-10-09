extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("HANDOFF_SMOKE main load failed")
		quit(1)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	for frame in 5: await process_frame
	var courses = load("res://scripts/course_registry.gd")
	for id in courses.ACTIVE_IDS:
		paused = false
		game.start_session(id)
		for frame in 5: await process_frame
		paused = false
		if not is_instance_valid(game.level) or game.level_index != id:
			push_error("HANDOFF_SMOKE bad course %s" % id)
			quit(1)
			return
		print("HANDOFF_COURSE_PASS ",id," ",game.level.scene_file_path)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stop_audio(game)
	game.queue_free()
	await create_timer(0.25).timeout
	print("HANDOFF_SMOKE_PASS nine active courses; initialization only")
	quit(0)

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		stop_audio(child)
