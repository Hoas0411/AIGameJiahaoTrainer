extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	print("ITERATION_004_CAPTURE_ARGS ", args)
	if args.size() != 2:
		quit(2)
		return
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	if scene.has_node("Catalog"):
		scene.get_node("Catalog").show()
	elif scene.has_node("Panel"):
		scene.get_node("Panel").show()
		if scene.has_node("Shade"): scene.get_node("Shade").show()
	RenderingServer.force_draw(true)
	var result := root.get_texture().get_image().save_png(args[1])
	print("ITERATION_004_CAPTURE_RESULT ", result, " ", args[1])
	quit(result)
