extends Node

func _ready() -> void:
	call_deferred("verify")

func verify() -> void:
	var game: Node = get_parent()
	var failures: Array[String] = []
	var expected := [0,6,7,8,12,13,15,19]
	if not InputMap.has_action("fire_mode"): failures.append("fire mode input")
	game.start_session(12)
	await get_tree().process_frame
	var lobby: Node = game.level
	if lobby.PORTAL_LEVELS != [0,19,7,8,15,6]: failures.append("six lobby courses")
	for slot in 6:
		if not lobby.has_node("Stations/Portal_%d" % slot) or not lobby.has_node("DisplayPanels/PortalDisplay_%d" % slot): failures.append("lobby window %d" % slot)
		var target: int = lobby.PORTAL_LEVELS[slot]
		lobby.receive_hit(0.0,"portal_%d" % slot)
		for frame in 3: await get_tree().process_frame
		if game.level_index != target: failures.append("lobby activation %d" % slot)
		game.start_session(12)
		await get_tree().process_frame
		lobby = game.level
	if game.LEVELS.keys() != expected: failures.append("scene registry")
	var commands = game.get_node("Companion").commands
	if commands.catalog().size() != 8: failures.append("companion catalog")
	if game.get_node("TrainingCatalog").courses.size() != 7: failures.append("training catalog")
	for style in 3:
		UIAppearance.choose(style)
		await get_tree().process_frame
		game.get_node("TrainingCatalog").open()
		await get_tree().process_frame
		game.get_node("TrainingCatalog").close()
		game.get_node("HubUI").show_course_drawer(true)
		for index in game.get_node("HubUI").HUB_LEVEL_IDS:
			var button: Button = game.get_node("HubUI/Root/Catalog/Course%d" % index)
			if index not in [0,6,7,8] and button.visible: failures.append("legacy selector %d" % index)
	for index in expected:
		game.start_session(index)
		for frame in 12: await get_tree().process_frame
		if not is_instance_valid(game.level) or game.level.scene_file_path != game.LEVELS[index].resource_path:
			failures.append("load %d" % index)
		if game.player.weapon.profile == null: failures.append("weapon %d" % index)
		print("REDUCED_SCENE_OK ",index," ",game.level.scene_file_path)
	game.start_session(12)
	for index in 23:
		if index in expected: continue
		var result: Dictionary = commands.execute({"kind":"switch_level","level":index},game)
		if result.ok or game.level_index != 12: failures.append("removed switch %d" % index)
		game.start_session(index)
		if game.level_index != 12: failures.append("removed entry %d" % index)
		var custom: Dictionary = game.get_node("CompanionRoutes").install_custom([{"level":index,"seconds":60}],"removed",false)
		if custom.ok: failures.append("removed route %d" % index)
	for focus in ["laser","tracking","mixed"]:
		for route in game.get_node("CompanionRoutes").build(focus,3):
			for step in route.steps:
				if not game.LEVELS.has(int(step.level)): failures.append("preset route")
	UIAppearance.choose(2)
	if "--verify-pack" in OS.get_cmdline_user_args():
		for path in ["03_corner_entry.tscn","04_tracking.tscn","05_jet_breach.tscn","06_space_city2.tscn","10_gadgets.tscn","11_audio.tscn","12_motion.tscn","24_crate_test_arena.tscn","training/15_reactive_tracking.tscn","training/17_apex_switch.tscn","training/18_valorant_movement.tscn","training/19_cs2_clearance.tscn","training/21_apex_strafe_heads.tscn","training/22_valorant_microflick.tscn","training/23_valorant_underaim.tscn","centrifuge_rebuilt/centrifuge_full.tscn"]:
			if ResourceLoader.exists("res://scenes/levels/"+path): failures.append("retired scene in pack "+path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lobby-evidence="):
			for slot in 6:
				game.start_session(12)
				for frame in 3: await get_tree().process_frame
				var display: Node3D = game.level.get_node("DisplayPanels/PortalDisplay_%d" % slot)
				var target: Vector3 = display.global_position + Vector3(0,3.55,0)
				var position: Vector3 = display.global_position * 0.55
				position.y = game.player.global_position.y
				game.player.global_position = position
				game.player.look_at(Vector3(target.x,position.y,target.z),Vector3.UP)
				var direction: Vector3 = target - game.player.camera.global_position
				game.player.get_node("Head").rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
				for frame in 30: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--lobby-evidence=")+"/window_%d.png" % slot)
		if arg.begins_with("--catalog-screenshot="):
			game.get_node("ApprovedUI").open_catalog()
			for frame in 30: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--catalog-screenshot="))
	print("REDUCED_CATALOG_RESULT ",JSON.stringify({"ok":failures.is_empty(),"failures":failures,"scenes":8,"training":7}))
	get_tree().quit(0 if failures.is_empty() else 1)
