extends SceneTree

# This entry is only valid in the adapter's disposable copy, before the real main is loaded.
func _initialize() -> void:
	call_deferred("_start_checked_game")


func _start_checked_game() -> void:
	var allowed: String = OS.get_environment("JIAHAO_TEST_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	var actual: String = OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/")
	if allowed.is_empty() or not actual.to_lower().begins_with(allowed.to_lower() + "/") or not project.to_lower().begins_with(allowed.to_lower() + "/"):
		push_error("Workbench runner requires an isolated project and user directory")
		quit(2)
		return
	if not "--smoke" in OS.get_cmdline_user_args():
		push_error("Workbench runner requires the existing offline --smoke suite")
		quit(2)
		return
	print("WORKBENCH_ISOLATION_PASS user_dir=", actual)
	Engine.set_meta("jiahao_workbench_finish", _finish_checked_game)
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var packed: PackedScene = load(main_path)
	if packed == null:
		push_error("Main scene did not load")
		quit(2)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	current_scene = game
	if game.get_node("Companion").ai_enabled:
		push_error("Network companion must remain disabled in offline regression")
		quit(2)


func _finish_checked_game(exit_code: int) -> void:
	Engine.remove_meta("jiahao_workbench_finish")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused = false
	var finished_game: Node = current_scene
	_stop_audio(finished_game)
	current_scene = null
	finished_game.queue_free()
	# Dummy audio mixing runs independently of fast render-disabled process frames.
	# Drain stopped playbacks, including the final death-test player_hurt.wav, before shutdown.
	await create_timer(0.12).timeout
	print("WORKBENCH_CLEANUP_DONE")
	quit(exit_code)


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)
