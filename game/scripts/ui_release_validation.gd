extends Node

var game: Node
var checks: Array[Dictionary] = []
var output := "user://ui-release-evidence"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-evidence="): output = argument.trim_prefix("--ui-evidence=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func settle(count := 10) -> void:
	for frame in count: await get_tree().process_frame

func check(value: bool, title: String) -> void:
	checks.append({"check": title, "pass": value})
	print("UI_RELEASE_CHECK ", "PASS " if value else "FAIL ", title)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await settle(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await settle(3)

func run() -> void:
	game.get_node("Companion").set_ai_enabled(false)
	check(UIAppearance.IDS.size() == 2, "two_rebuilt_styles_only")
	for old in ["paper", "terminal", "theatre"]:
		check(not ResourceLoader.exists("res://ui/appearance/" + old + "_hub.tscn"), "rejected_%s_absent_from_package" % old)
	var ui: Node = game.get_node("CompanionUI")
	for index in UIAppearance.IDS.size():
		UIAppearance.choose(index)
		await settle()
		var name: String = UIAppearance.IDS[index]
		game.enter_hub()
		game.get_node("HubUI").open_catalog()
		await settle()
		check(game.get_node("HubUI/Root/Catalog").visible, name + "_packaged_lobby")
		if index == 1:
			await click(game.get_node("HubUI/Root/Catalog/TrainingSelect"))
		await click(game.get_node("HubUI/Root/Catalog/Course2"))
		await click(game.get_node("HubUI/Root/Catalog/Start"))
		check(game.level_index == 2 and game.running and not get_tree().paused, name + "_packaged_start_input")
		ui.open_panel()
		await settle()
		check(ui.chat_box.has_node("Latest") and ui.chat_box.has_node("History"), name + "_packaged_chat_resources")
		await click(ui.chat_box.get_node("Tools"))
		check(is_instance_valid(ui.tools_workspace) and ui.tools_workspace.visible, name + "_packaged_tools_input")
		if not is_instance_valid(ui.tools_workspace):
			finish()
			return
		check(ui.tools_workspace.get_node("Root/Steps").get_parsed_text().length() > 30, name + "_packaged_real_plan")
		if DisplayServer.get_name() != "headless":
			await settle()
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(output + "/" + name + "-tools.png") == OK, name + "_packaged_render")
		await click(ui.tools_workspace.get_node("Root/BackChat"))
		await click(ui.chat_box.get_node("Close"))
		check(not get_tree().paused, name + "_packaged_return")
	finish()

func finish() -> void:
	var failed := checks.filter(func(item): return not item.pass)
	var file := FileAccess.open(output + "/validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failed, "scope": "Exported release executable: packaged resources, real pointer navigation, course start and rendered tool plans. Local isolated capture mode; no model request."}, "\t"))
	file.close()
	print("UI_RELEASE_RESULT checks=", checks.size(), " failures=", failed.size())
	get_tree().quit(0 if failed.is_empty() else 1)
