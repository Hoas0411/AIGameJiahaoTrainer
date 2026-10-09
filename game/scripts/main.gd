extends Node3D

const COURSES = preload("res://scripts/course_registry.gd")
const LEVELS = COURSES.SCENES
const LEVEL_IDS: Array[int] = [0,6,7,8,12,13,15,19]
const AWM: WeaponProfile = preload("res://resources/weapons/awm.tres")
const RIFLE: WeaponProfile = preload("res://resources/weapons/m7.tres")
const RECORD_MUSIC: Script = preload("res://scripts/record_music.gd")
var level: Node3D
var level_index: int = 0
var running: bool = false
var elapsed: float = 0.0
var last_takedown_seconds: float = -1.0
var target_first_hits: Dictionary = {}
var shots: int = 0
var hits: int = 0
var kills: int = 0
var headshots: int = 0
var session_length: float = 90.0
var best: float = 0.0
var ability_message: String = ""
var ability_message_time: float = 0.0
var ability_uses: int = 0
var training_options: Dictionary = {}
var training_recorded: bool = false
@onready var player: CharacterBody3D = $Player
@onready var ui: CanvasLayer = $Interface



# 连接独立界面场景并读取本地设置；主菜单也保留可编辑 3D 展台。
func _ready() -> void:
	_install_master_limiter()
	var record_music: Node = RECORD_MUSIC.new()
	record_music.name = "RecordMusic"
	add_child(record_music)
	var approved_ui := preload("res://scripts/approved_ui.gd").new()
	approved_ui.name = "ApprovedUI"
	add_child(approved_ui)
	var minimal_hud := preload("res://scripts/minimal_hud.gd").new()
	minimal_hud.name = "MinimalHUD"
	add_child(minimal_hud)
	DisplayServer.window_set_title("嘉豪训练器 · 精简训练版")
	add_to_group("session")
	ui.start_requested.connect(start_session)
	ui.retry_requested.connect(func(): start_session(level_index))
	ui.menu_requested.connect(enter_hub)
	ui.resume_requested.connect(resume)
	ui.settings_changed.connect(apply_settings)
	ui.load_settings()
	ui.get_node("InputProfiles").apply_launch_argument()
	apply_settings()
	$Lobby/Doll.play_pose("stand")
	show_menu()
	call_deferred("enter_hub")
	for argument in OS.get_cmdline_user_args():
		if argument == "--training-menu": call_deferred("enter_training_catalog")
		if argument.begins_with("--training-drill="):
			call_deferred("start_session", int(argument.get_slice("=", 1)))
	if "--verify-reduced-catalog" in OS.get_cmdline_user_args():
		call_deferred("_verify_reduced_catalog")

func _verify_reduced_catalog() -> void:
	add_child(preload("res://scripts/tests/reduced_catalog_validation.gd").new())

func start_session(index: int, fixture: PackedScene = null) -> void:
	if not LEVELS.has(index): return
	if fixture == null and not LEVELS.has(index):
		push_warning("训练关卡 %d 已移除或不存在" % index)
		enter_hub()
		return
	if has_node("ApprovedUI") and $ApprovedUI.is_open(): $ApprovedUI.close_catalog()
	$CompanionRoutes.on_manual_session()
	$TrainingResults.hide_panel()
	session_length = 90.0
	$BubbleUI.reset_session()
	$HubUI.close_catalog()
	$Companion.reset_session()
	get_tree().paused = false
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	for bullet in get_tree().get_nodes_in_group("projectiles"):
		bullet.queue_free()
	level_index = index
	level = (fixture if fixture != null else LEVELS[index] as PackedScene).instantiate()
	level.practice_action = ui.action_choice.selected - 1
	level.difficulty = ui.difficulty_choice.selected
	add_child(level)
	$RecordMusic.bind_station(level.get_node_or_null("PhonographStation"))
	player.global_transform = level.get_node("PlayerSpawn").global_transform
	player.velocity = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	player.reset_lean()
	player.health = 100
	player.active = true
	player.controls_blocked = false
	player.combat_enabled = true
	player.weapon.visible = true
	player.airborne = false
	player.show()
	player.weapon.equip(AWM if index == 0 else RIFLE)
	player.abilities.reset()
	player.camera.rotation = Vector3.ZERO
	player.raw_counts = Vector2.ZERO
	apply_settings()
	player.camera.current = true
	$Lobby.hide()
	last_takedown_seconds = -1.0
	target_first_hits.clear()
	shots = 0
	hits = 0
	kills = 0
	headshots = 0
	elapsed = 0
	training_recorded = false
	ability_uses = 0
	running = true
	ui.show_game(index)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$CompanionActor.reset_position()
	if level.has_node("CompanionStand"):
		$CompanionActor.global_position = level.get_node("CompanionStand").global_position



# 每帧更新训练统计。
func _process(delta: float) -> void:
	if not running:
		return
	elapsed = level.session_time() if level.has_method("session_time") else elapsed + delta
	ability_message_time = maxf(0, ability_message_time - delta)
	ui.update_hud(self)
	if $CompanionRoutes.owns_session():
		var remaining: float = maxf(0, float($CompanionRoutes.active.steps[$CompanionRoutes.step_index].seconds) - $CompanionRoutes.step_elapsed)
		ui.get_node("Root/HUD/Time").text = "%02d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	if not $CompanionRoutes.owns_session() and not level.free_roam and level.target_count == 0 and elapsed >= session_length:
		finish(true)



# Esc 打开暂停菜单，F5 快速重开当前关卡。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and running:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.show_pause()
	elif event.is_action_pressed("restart") and running:
		start_session(level_index)



# 从暂停菜单恢复鼠标捕获与物理模拟。
func resume() -> void:
	# The click that pressed 继续 must not also become a shot.
	if is_instance_valid(player) and player.get("weapon") != null:
		player.weapon.trigger_hold_block = true
	get_tree().paused = false
	ui.show_game(level_index)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



# 返回可交互的训练大厅。
func show_menu() -> void:
	$RecordMusic.bind_station(null)
	$CompanionRoutes.stop("已返回菜单")
	$Companion.reset_session()
	get_tree().paused = false
	running = false
	player.active = false
	player.reset_lean()
	player.hide()
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	$Lobby.show()
	$Lobby/MenuCamera.current = true
	ui.show_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE



# 应用设置同时保存，灵敏度和 FOV 无需重启。
func apply_settings() -> void:
	player.sensitivity = ui.sensitivity_slider.value
	player.base_fov = ui.fov_slider.value
	player.ads_multiplier = ui.ads_slider.value
	player.laser_multiplier = ui.laser_slider.value
	player.yaw_coefficient = ui.yaw_slider.value
	player.horizontal_fov = ui.fov_axis.selected == 0
	player.invulnerable = ui.invincible.button_pressed
	ui.apply_advanced_settings(player)
	ui.get_node("DisplaySettings").apply_mode(ui.get_node("Root/Settings/Panel/DisplayMode").selected)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, ui.volume_slider.value)))
	ui.save_settings()



# 开火统计与命中统计分别记录，命中率不受伤害倍率影响。
func shot_fired() -> void:
	shots += 1
	if is_instance_valid(level) and level.has_method("record_shot"):
		level.record_shot()



# 显示伤害、命中音效及爆头标记。
func target_hit(zone: String, damage: float) -> void:
	if not running:
		return
	if zone != "explosive":
		hits += 1
	if zone == "head":
		headshots += 1
	ui.flash_hit(zone, damage)
	if level.has_method("record_hit"):
		level.record_hit(zone)



# 有固定目标数量的关卡在清除全部目标后结算。
func enemy_down(operator_target: bool = true) -> void:
	if not running:
		return
	kills += 1
	$Companion.observe("kill", elapsed)
	player.abilities.refund_dash(operator_target)
	if level.target_count > 0 and kills >= level.target_count:
		finish(true)



# 受击视觉反馈由 HUD 独立负责。
func player_hurt() -> void:
	ui.hurt_timer = 0.3



# 结算本轮并保留可复练的结果卡。
func finish(success: bool) -> void:
	if not running:
		return
	$CompanionRoutes.stop("本轮结束 · 可在路线页重新开始")
	get_tree().paused = false
	$BubbleUI.reset_session()
	running = false
	player.active = false
	player.reset_lean()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	ui.show_results(success, self)
	if level.has_method("progress_text"):
		ui.get_node("Root/Results/Panel/Numbers").text += "\n\n" + level.progress_text()
	if level.has_method("show_session_results"):
		ui.get_node("Root/Results").hide()
		level.show_session_results()
	elif level.has_method("metrics") and level_index >= 13:
		ui.get_node("Root/Results").hide()
		$TrainingResults.show_for_session()
	record_training(success)
	$Companion.training_finished(success, kills, shots, hits)

func open_ui_preview() -> void:
	enter_hub()
	$HubUI.open_catalog()
	print("UI_PREVIEW_READY lobby=", $HubUI.get_node("Root/Catalog").visible, " style=", UIAppearance.IDS[UIAppearance.selected])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-launch-evidence="):
			for frame in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--ui-launch-evidence="))
			print("UI_PREVIEW_SCREENSHOT result=", result)

func _run_ui_release_validation() -> void:
	add_child(preload("res://scripts/ui_release_validation.gd").new())

func record_training(success: bool) -> void:
	if training_recorded: return
	training_recorded = true
	var path: String = $Companion.history_path()
	var history: Array = []
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			history = parsed
	history.append({"level": level_index + 1, "success": success, "seconds": elapsed, "shots": shots, "hits": hits, "headshots": headshots, "kills": kills, "abilities": ability_uses, "unix_time": Time.get_unix_time_from_system(), "drill_metrics": level.metrics() if level.has_method("metrics") else {}})
	if history.size() > 100:
		history.pop_front()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history, "\t"))
		file.close()



# 技能使用和冷却反馈进入 HUD，同时计入本次训练记录。
func ability_used(label: String) -> void:
	ability_feedback(label)
	ability_uses += 1
	if label == "动力推进":
		$Companion.observe("dash", elapsed)



# 自动化运行真实关卡和弹道，用于检查生命周期与计分。
func run_smoke() -> void:
	add_child(preload("res://scripts/tests/reduced_catalog_validation.gd").new())



# 捕获游戏本身渲染的画面，作为界面和场景验收证据。
func capture_after_frames(path: String) -> void:
	var frame_ms: Array[float] = []
	for frame in range(90):
		var started: int = Time.get_ticks_usec()
		await get_tree().process_frame
		if frame >= 30:
			frame_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	frame_ms.sort()
	print("RENDER SAMPLE median_ms=", frame_ms[30], " p95_ms=", frame_ms[57], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("CAPTURE ", path)
	get_tree().quit()



# 独立验证在线校准的真实 HTTP 响应与弹窗布局。
func capture_converter() -> void:
	ui.open_settings("menu")
	ui.open_converter()
	ui.get_node("Calibration").calculate()
	await ui.get_node("Calibration/Request").request_completed
	print("CONVERTER RESULT ", ui.get_node("Calibration/Status").text)
	capture_after_frames("res://evidence/converter.png")



# 固定在真实动画中段渲染，避免截图等待时间把拉栓或换弹动作漏掉。
func capture_weapon_action(rifle: bool, bolt: bool) -> void:
	start_session(0)
	player.invulnerable = true
	player.weapon.equip(RIFLE if rifle else AWM)
	await get_tree().create_timer(0.3).timeout
	if bolt:
		player.weapon.laser_mode = false
		Input.action_press("aim")
		await get_tree().create_timer(0.6).timeout
		player.weapon.fire()
	else:
		player.weapon.ammo = 1
		player.weapon.reload()
	await get_tree().create_timer(0.67 if bolt else 0.95).timeout
	get_tree().paused = true
	capture_after_frames("res://evidence/bolt_action.png" if bolt else ("res://evidence/rifle_reload_action.png" if rifle else "res://evidence/awm_reload_action.png"))



# 冷却刷新提示不计作玩家再次使用技能。
func ability_feedback(label: String) -> void:
	ability_message = label
	ability_message_time = 1.5

func enter_hub() -> void:
	start_session(12)

func enter_training_catalog() -> void:
	enter_hub()
	$TrainingCatalog.open()

func _run_training_release_validation() -> void:
	add_child(preload("res://scripts/tests/reduced_catalog_validation.gd").new())


func begin_target_hit(target: Node, zone: String) -> void:
	if running and zone != "explosive" and not target_first_hits.has(target.get_instance_id()):
		target_first_hits[target.get_instance_id()] = elapsed

func complete_target_kill(target: Node) -> void:
	var id := target.get_instance_id()
	if running and target_first_hits.has(id):
		last_takedown_seconds = maxf(0.0, elapsed - float(target_first_hits[id]))
	target_first_hits.erase(id)

func forget_target_hit(target: Node) -> void:
	target_first_hits.erase(target.get_instance_id())


# Overlapping shots, explosions and music could clip the master bus. A transparent hard
# limiter (ceiling -1 dB) on Master keeps peaks below full scale; it does nothing below that.
func _install_master_limiter() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter: return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	limiter.pre_gain_db = 0.0
	AudioServer.add_bus_effect(0, limiter)
