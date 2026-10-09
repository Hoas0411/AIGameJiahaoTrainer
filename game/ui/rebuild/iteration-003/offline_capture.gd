extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: -- scene-path output-path")
		quit(2)
		return
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	if scene.has_node("Catalog"):
		scene.get_node("Catalog").show()
	elif scene.has_node("Panel"):
		scene.get_node("Panel").show()
		scene.get_node("Shade").show()
	await process_frame
	await process_frame
	var result := root.get_viewport().get_texture().get_image().save_png(args[1])
	quit(result)
