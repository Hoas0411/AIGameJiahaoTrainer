extends Node3D

@export var level_number := 21
@export var target_count := 6
@export var free_roam := false
var practice_action := -1
var difficulty := 1
var mode := 20
var player: Node3D
var game: Node
var current_bay := -1
var completed_bays: Array[int] = []
var exposure := 0.0
var max_exposure := 0.0
var exposure_count := 0
var exposure_total := 0.0
var dangerous_exposures := 0
var previous_visible := false
var failure_reason := ""
var observing_enemy := ""
var elapsed_time := 0.0
var drill_shots := 0
var drill_hits := 0
var ended := false
var hud: Label
var hud_state: Label
var hud_bar: ColorRect
var hud_bar_back: ColorRect
const ArtUI = preload("res://ui/approved/skin.gd")
const BAR_W := 268.0
var warning: AudioStreamPlayer
var warned := false
const LIMIT := 0.5
const BAY_NAMES := ["A 左右探头", "B 跳射", "C 大拉推进"]

func _ready() -> void:
	game = get_parent()
	player = get_tree().get_first_node_in_group("player")
	process_physics_priority = 30
	for body in $Architecture.get_children():
		var surface: Material
		if str(body.name).begins_with("F_"):
			surface = preload("res://assets/models/segmented_cover_gridshot_v2_20261005/floor_world.tres")
		else:
			# Classify structural modules by their imported scene, not cover names.
			var model: Node3D = body.get_node("Model")
			if model.scene_file_path.ends_with("wall.glb") or model.scene_file_path.ends_with("doorway.glb"):
				surface = preload("res://assets/models/segmented_cover_gray_v3_20261005/wall_world.tres")
			elif model.scene_file_path.ends_with("white.glb"):
				surface = preload("res://assets/models/segmented_cover_gridshot_v2_20261005/white_grid.tres")
			elif model.scene_file_path.ends_with("blue.glb"):
				surface = preload("res://assets/models/segmented_cover_gridshot_v2_20261005/blue_grid.tres")
			elif model.scene_file_path.ends_with("dark.glb"):
				surface = preload("res://assets/models/segmented_cover_gridshot_v2_20261005/dark_grid.tres")
		if surface != null:
			for mesh in body.get_node("Model").find_children("*", "MeshInstance3D", true, false):
				mesh.material_override = surface
	for enemy in $Enemies.get_children():
		enemy.eliminated.connect(on_eliminated)
		enemy.active = not enemy.dead
	_build_hud()
	warning = AudioStreamPlayer.new()
	warning.stream = preload("res://assets/audio/hit.wav")
	warning.pitch_scale = 1.5
	warning.volume_db = -12
	add_child(warning)
	update_hud()

func _physics_process(delta: float) -> void:
	if ended or not is_instance_valid(player) or not player.active: return
	elapsed_time += delta
	# Bays label training positions; they do not lock enemy AI or perception.
	current_bay = clampi(floori(player.global_position.x / 8.0), 0, 2)
	var visible := false
	observing_enemy = ""
	for enemy in $Enemies.get_children():
		if enemy.active and not enemy.dead and enemy_sees_player(enemy):
			visible = true
			observing_enemy = enemy.name
			break
	advance_exposure(visible, delta)
	update_hud()
	if exposure + 0.000001 >= LIMIT:
		failure_reason = "连续暴露达到0.5秒 · " + observing_enemy
		ended = true
		for enemy in $Enemies.get_children(): enemy.active = false
		game.finish(false)
	elif player.global_position.y < -3 or player.global_position.x < -0.4 or player.global_position.x > 24.4 or player.global_position.z > 0.4 or player.global_position.z < -27.4:
		failure_reason = "离开训练边界"
		ended = true
		game.finish(false)

func advance_exposure(visible: bool, delta: float) -> void:
	if visible:
		if not previous_visible: exposure_count += 1
		exposure += delta
		max_exposure = maxf(max_exposure, exposure)
		if exposure >= 0.30 and not warned:
			warned = true
			if is_instance_valid(warning): warning.play()
	else:
		close_exposure()
	previous_visible = visible

func close_exposure() -> void:
	if exposure > 0:
		exposure_total += exposure
		if exposure >= 0.40: dangerous_exposures += 1
	exposure = 0.0
	warned = false

func player_samples() -> Array[Vector3]:
	var eye: Vector3 = player.camera.global_position
	var base: Vector3 = player.global_position
	var up := Vector3.UP
	var right: Vector3 = player.global_basis.x.normalized()
	var chest: Vector3 = base + up * (0.77 if player.crouched else 1.25)
	# Lean affects head and upper torso, even though the player capsule stays centered.
	var lateral := eye - base
	lateral.y = 0
	chest += lateral * 0.65
	return [eye, chest, chest + right * 0.23, chest - right * 0.23, base + up * (0.50 if player.crouched else 0.82)]

func enemy_sees_player(enemy: Node3D) -> bool:
	if not is_instance_valid(player): return false
	var eye: Vector3 = enemy.eye_position()
	for point in player_samples():
		var offset: Vector3 = point - eye
		if offset.length() > 50: continue
		# Enemy faces the player; require a forward hemisphere to prevent back vision.
		if offset.normalized().dot(enemy.get_node("Doll").global_basis.z.normalized()) < 0.15: continue
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false

func point_visible_from_player(point: Vector3) -> bool:
	if not is_instance_valid(player): return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func on_eliminated(enemy: Node) -> void:
	var remaining := 0
	for other in $Enemies.get_children():
		if other.bay == enemy.bay and not other.dead: remaining += 1
	if remaining == 0 and not completed_bays.has(enemy.bay):
		completed_bays.append(enemy.bay)
		completed_bays.sort()
		current_bay = -1
		# Clearing a bay must not reset visibility from another surviving enemy.

func _build_hud() -> void:
	# Compact drill panel under the course title: bay + progress, exposure meter, one key line.
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var f := ArtUI.frame(root, "CoverDrill", Rect2(40, 88, 300, 112), true)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = ArtUI.label(f, "", Rect2(16, 8, 270, 28), 19)
	hud_state = ArtUI.label(f, "", Rect2(16, 38, 270, 24), 16, Color("a8bbb6"))
	hud_bar_back = ColorRect.new()
	hud_bar_back.color = Color(1, 1, 1, 0.12)
	hud_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(hud_bar_back)
	ArtUI.rect(hud_bar_back, 16, 66, BAR_W, 8)
	hud_bar = ColorRect.new()
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(hud_bar)
	ArtUI.rect(hud_bar, 16, 66, 0, 8)
	var tick := ColorRect.new()
	tick.color = Color(0.95, 0.72, 0.32, 0.9)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(tick)
	ArtUI.rect(tick, 16 + BAR_W * 0.30 / LIMIT, 62, 2, 16)
	var keys := ArtUI.label(f, "Q/E 探头 · Ctrl 蹲 · Space 跳射 · A/D 大拉", Rect2(16, 80, 280, 22), 13, Color("7f938f"))
	keys.name = "Keys"

func update_hud() -> void:
	var title: String = BAY_NAMES[current_bay] if current_bay >= 0 else ("前往 " + BAY_NAMES[mini(2, completed_bays.size())])
	var count := 0
	for enemy in $Enemies.get_children():
		if enemy.dead: count += 1
	hud.text = "%s   清除 %d / 6" % [title, count]
	var state := "立即收回！" if exposure >= 0.30 else ("暴露" if exposure > 0 else "安全 · 连续暴露 0.5 秒失败")
	hud_state.text = state if exposure <= 0 else "%s  %.2f / 0.50 秒" % [state, minf(exposure, LIMIT)]
	var danger := Color(1, 0.35, 0.22) if exposure >= 0.42 else (Color(1, 0.78, 0.3) if exposure >= 0.30 else Color(0.55, 0.85, 0.82))
	hud_state.add_theme_color_override("font_color", danger if exposure > 0 else Color("a8bbb6"))
	hud_bar.color = danger
	hud_bar.size.x = BAR_W * clampf(exposure / LIMIT, 0.0, 1.0)

func record_shot() -> void: drill_shots += 1
func record_hit(_zone: String) -> void: drill_hits += 1
func session_time() -> float: return elapsed_time
func progress_text() -> String:
	return "%s\n最大连续暴露 %.2f 秒 · 探出 %d 次 · 命中 %d / 射击 %d" % [failure_reason if not failure_reason.is_empty() else "三个分区已完成", max_exposure, exposure_count, drill_hits, drill_shots]
func metrics() -> Dictionary:
	var total := exposure_total + exposure
	return {"drill":"segmented_cover","mode":20,"max_exposure_seconds":max_exposure,"exposure_count":exposure_count,"mean_exposure_seconds":total/maxi(1,exposure_count),"dangerous_exposures":dangerous_exposures + (1 if exposure >= 0.40 else 0),"hits_per_exposure":float(drill_hits)/maxi(1,exposure_count),"completed_bays":completed_bays.duplicate(),"failure_reason":failure_reason,"limit_seconds":LIMIT}

func _process(_delta: float) -> void:
	# Keep this level's result instruction aligned with its own limit.
	var notes: Label = game.get_node_or_null("TrainingResults/Panel/Notes")
	if is_instance_valid(notes) and notes.is_visible_in_tree():
		notes.text = notes.text.replace("达到1秒即失败", "达到0.5秒即失败")

## Three live values for the minimal HUD: exposure discipline instead of takedown time.
func hud_stats() -> Array:
	var count := 0
	for enemy in $Enemies.get_children():
		if enemy.dead: count += 1
	var accuracy: String = "—" if drill_shots == 0 else "%.0f%%" % (drill_hits * 100.0 / drill_shots)
	return [["清除", "%d / 6" % count], ["最长暴露", "%.2f s" % max_exposure], ["命中率", accuracy]]
