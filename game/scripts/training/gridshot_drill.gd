extends "res://scripts/level.gd"

@export var seed_value: int = 9132026
@export var grid_columns: int = 5
@export var grid_rows: int = 5
@export var grid_spacing: float = 1.0
@export var target_radius: float = 0.42
@export var target_distance: float = 8.0
@export var grid_center_height: float = 2.6
var precision_variant: bool = false
var show_viewmodel: bool = true
var rng := RandomNumberGenerator.new()
var occupied: Dictionary = {}
var clock: float = -3.0
var last_hit_at: float = 0.0
var intervals_ms: Array[float] = []
var click_positions: Array[Vector2] = []
var click_count: int = 0
var successful_clicks: int = 0
var ready_to_score: bool = false
var shot_flash: float = 0.0
var session_context: RefCounted = preload("res://scripts/training/training_session_context.gd").new()
@onready var game: Node = get_parent()

func _ready() -> void:
	set_meta("training_focus",true)
	if game.training_options.has(game.level_index):
		var options: Dictionary = game.training_options[game.level_index]
		precision_variant = options.get("precision_variant",false)
		show_viewmodel = options.get("show_viewmodel",true)
	if precision_variant:
		target_radius = 0.24
	rng.seed = seed_value
	for sphere in $Targets.get_children():
		sphere.mesh = sphere.mesh.duplicate()
		sphere.mesh.radius = target_radius
		sphere.mesh.height = target_radius * 2.0
		sphere.get_node("Hitbox/Shape").shape = sphere.get_node("Hitbox/Shape").shape.duplicate()
		sphere.get_node("Hitbox/Shape").shape.radius = target_radius
		_relocate(sphere)
	call_deferred("configure")

func configure() -> void:
	game.session_length = 60.0
	game.elapsed = 0.0
	# A course-owned, zero-recoil click tool uses the original player's camera.
	# It does not edit any player motion/input or shared firearm Resource.
	game.player.combat_enabled = false
	game.player.weapon.hide()
	game.player.get_node("Head").rotation.x = atan2(grid_center_height-game.player.camera.global_position.y,target_distance)
	session_context.begin(game.player)
	game.ui.get_node("Root/HUD/Level").text = "Gridshot / " + ("精度加强" if precision_variant else "参考基准")
	var bubble = game.get_node("BubbleUI")
	if Time.get_ticks_msec() >= bubble.operation_receipt_until:
		bubble.manually_folded = true
		bubble.bubble_time = 0.0
	for name in ["Ammo", "AmmoPlate", "WeaponName", "Health", "HealthPlate", "HP", "Dash", "DashPlate", "Charge", "ChargePlate", "Thumper", "ThumperPlate", "Action", "Controls"]:
		game.ui.get_node("Root/HUD/"+name).hide()

func _relocate(sphere: Node3D) -> void:
	var previous: int = int(sphere.get_meta("cell", -1))
	occupied.erase(previous)
	var choices: Array[int] = []
	for cell in grid_columns * grid_rows:
		if not occupied.has(cell) and cell != previous:
			choices.append(cell)
	var selected: int = choices[rng.randi_range(0, choices.size()-1)]
	occupied[selected] = sphere
	sphere.set_meta("cell", selected)
	sphere.position = Vector3((selected % grid_columns - (grid_columns-1)/2.0)*grid_spacing,
		grid_center_height + (floori(float(selected) / grid_columns) - (grid_rows-1)/2.0)*grid_spacing,
		10.0-target_distance)

func _process(delta: float) -> void:
	if not game.running or game.level != self:
		$Countdown.hide()
		$ClickTool.hide()
		return
	$Countdown.show()
	$ClickTool.visible = show_viewmodel
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = minf(viewport_size.x/1600.0,viewport_size.y/900.0)
	$Countdown/Label.scale = Vector2.ONE * ui_scale
	$Countdown/Label.position = Vector2(viewport_size.x/2.0-180.0*ui_scale,viewport_size.y/2.0-220.0*ui_scale)
	$Countdown/Instruction.scale = Vector2.ONE * ui_scale
	$Countdown/Instruction.position = Vector2(viewport_size.x/2.0-650.0*ui_scale,viewport_size.y-85.0*ui_scale)
	$Countdown/Instruction.size = Vector2(1300,55)
	$Countdown/Instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock += delta
	ready_to_score = clock >= 0.0 and clock < 60.0
	if ready_to_score and not session_context.initial.is_empty():
		session_context.observe(game.player,delta,clock)
	$Countdown/Label.visible = clock < 0.0
	$Countdown/Label.text = str(ceili(-clock))
	$ClickTool.global_transform = game.player.camera.global_transform
	shot_flash = maxf(0.0, shot_flash-delta)
	$ClickTool/Muzzle.visible = shot_flash > 0.0
	$ClickTool/Art/Slide.position.z = -0.62 + shot_flash * 0.8
	$Countdown/Instruction.text = "三个球 · 命中立即补位 · 左键单点 / F5重开 / F6目录 / F9训练选项"
	if not ready_to_score and clock >= 60:
		game.elapsed = 60.0
		game.finish(true)

func session_time() -> float:
	return clampf(clock,0.0,60.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if game.player.controls_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not ready_to_score:
			return
		shoot_click()
		get_viewport().set_input_as_handled()

func shoot_click() -> bool:
	if not ready_to_score:
		return false
	click_count += 1
	game.shot_fired()
	var camera: Camera3D = game.player.camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 100.0, 3)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	shot_flash = 0.055
	$ClickSound.play()
	if not result.is_empty() and $Targets.is_ancestor_of(result.collider):
		var sphere: Node3D = result.collider.get_parent()
		successful_clicks += 1
		game.target_hit("body", 1.0)
		# Do not award combat ability refunds or companion kill barks for every ball.
		game.kills += 1
		intervals_ms.append((clock-last_hit_at)*1000.0)
		last_hit_at = clock
		_relocate(sphere)
		get_tree().call_group("companion_reaction_observers", "observe_shot_result", true, get_instance_id())
		return true
	get_tree().call_group("companion_reaction_observers", "observe_shot_result", false, get_instance_id())
	return false

func metrics() -> Dictionary:
	return {"task":"gridshot_reference", "seed":seed_value, "clicks":click_count,
		"successful_clicks":successful_clicks, "intervals_ms":intervals_ms,
		"grid_columns":grid_columns, "grid_rows":grid_rows, "grid_spacing":grid_spacing,
		"target_radius":target_radius, "target_distance":target_distance,
		"variant":"precision" if precision_variant else "reference", "show_viewmodel":show_viewmodel,
		"session_context":session_context.report(game.player),
		"score_note":"Reports raw successful clicks; proprietary Aim Lab score formula not asserted."}

func progress_text() -> String:
	return "有效命中 %d / 点击 %d · %.2f 次/秒\n三球立即补位；无后坐力点击工具；输入与视角仍由共享玩家控制。" % [successful_clicks,click_count,successful_clicks/maxf(clock,0.001)]

func live_stats() -> String:
	var accuracy: String = "—" if click_count == 0 else "%.1f%%" % (successful_clicks*100.0/click_count)
	return "%d 有效命中    %s 准确率" % [successful_clicks,accuracy]

## Three live values for the minimal HUD (replaces takedown/headshot rows that do not apply here).
func hud_stats() -> Array:
	var accuracy: String = "—" if click_count == 0 else "%.0f%%" % (successful_clicks * 100.0 / click_count)
	var remaining: String = "%.0f s" % (60.0 - clampf(clock, 0.0, 60.0)) if clock >= 0.0 else "准备"
	return [["有效命中", str(successful_clicks)], ["准确率", accuracy], ["剩余时间", remaining]]
