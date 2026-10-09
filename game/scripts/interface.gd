extends CanvasLayer

signal start_requested(index: int)
signal retry_requested
signal menu_requested
signal resume_requested
signal settings_changed
var hit_timer: float = 0.0
var hit_duration: float = 0.23
var hurt_timer: float = 0.0
var settings_return: String = "menu"
const TITLES = preload("res://scripts/course_registry.gd").NAMES
const OBJECTIVES: Array[String] = ["AWM 三人双掩体 · 击倒 → A/D + X 喷气入掩体 → 跳拉再出击", "", "", "", "", "", "10 / 25 / 50 米 · 单发、短点射与压枪分组", "随机亮靶 · 首次命中反应计时 · 90 秒", "不同高度目标 · 预瞄头线与垂直转火", "", "", "", "F 进入训练舱 / Tab 快选 / Enter 聊天 / F8 参数", "持续扫射移动目标 · F6 新训练目录", "", "等待目标通过门缝 · B 切瞄具 · F6 目录", "", "", "", "三球随机定位 · 左键单点 · F6 目录", "", "", ""]
@onready var sensitivity_slider: HSlider = $Root/Settings/Panel/Sensitivity
@onready var fov_slider: HSlider = $Root/Settings/Panel/FOV
@onready var ads_slider: HSlider = $Root/Settings/Panel/ADS
@onready var laser_slider: HSlider = $Root/Settings/Panel/Laser
@onready var yaw_slider: Range = $Root/Settings/Panel/Yaw
@onready var volume_slider: HSlider = $Root/Settings/Panel/Volume
@onready var fov_axis: OptionButton = $Root/Settings/Panel/FOVAxis
@onready var invincible: CheckButton = $Root/Settings/Panel/Invincible
@onready var action_choice: OptionButton = $Root/Menu/Actions
@onready var difficulty_choice: OptionButton = $Root/Menu/Difficulty



# 场景内按钮与滑块的信号集中连接，视觉布局完全保留在 .tscn。
func _ready() -> void:
	$Root/Pause/Panel/Finish.pressed.connect(func(): get_parent().finish(true))
	$Root/Menu/EnterHub.pressed.connect(func(): start_requested.emit(12))
	$Root/Settings/Panel/DisplayMode.item_selected.connect(func(_i): settings_changed.emit())
	$Root/Menu/StartOne.pressed.connect(func(): start_requested.emit(0))
	$Root/Menu/StartTwo.pressed.connect(func(): start_requested.emit(6))
	$Root/Menu/StartThree.pressed.connect(func(): start_requested.emit(7))
	$Root/Menu/StartFour.pressed.connect(func(): start_requested.emit(13))
	$Root/Menu/StartFive.pressed.connect(func(): start_requested.emit(8))
	$Root/Menu/StartSix.pressed.connect(func(): start_requested.emit(15))
	$Root/Settings/Panel/ProfilesButton.pressed.connect(func(): $InputProfiles.popup_centered())
	$InputProfiles.selected_profile.connect(apply_input_profile)
	$Root/Menu/SettingsButton.pressed.connect(func(): open_settings("menu"))
	$Root/Menu/Quit.pressed.connect(func(): get_tree().quit())
	$Root/Pause/Panel/Resume.pressed.connect(func(): resume_requested.emit())
	$Root/Pause/Panel/SettingsButton.pressed.connect(func(): open_settings("pause"))
	$Root/Pause/Panel/Restart.pressed.connect(func(): retry_requested.emit())
	$Root/Pause/Panel/MenuButton.pressed.connect(func(): menu_requested.emit())
	$Root/Results/Panel/Retry.pressed.connect(func(): retry_requested.emit())
	$Root/Results/Panel/MenuButton.pressed.connect(func(): menu_requested.emit())
	$Root/Settings/Panel/Back.pressed.connect(close_settings)
	$Root/Settings/Panel/KeySettings.pressed.connect(func(): $Keybindings.popup_centered())
	$Root/Settings/Panel/ConverterButton.pressed.connect(open_converter)
	$Calibration.calibrated.connect(func(value): $InputProfiles.current_id = "custom"; yaw_slider.value = value; settings_changed.emit())
	for slider in [sensitivity_slider, fov_slider, ads_slider, laser_slider, yaw_slider, volume_slider]:
		slider.value_changed.connect(func(_v): refresh_setting_labels(); settings_changed.emit())
	fov_axis.item_selected.connect(func(_i): settings_changed.emit())
	invincible.toggled.connect(func(_v): settings_changed.emit())
	for spin in [$Root/Settings/Panel/DPI, $Root/Settings/Panel/Horizontal, $Root/Settings/Panel/Vertical, $Root/Settings/Panel/MonitorDistance]:
		spin.value_changed.connect(func(_v): settings_changed.emit())
	$Root/Settings/Panel/MatchMode.item_selected.connect(func(_v): settings_changed.emit())
	$Root/Settings/Panel/Calibrate.pressed.connect(calibrate_from_cm)
	$Root/Settings/Panel/ImportMeasured.pressed.connect(import_measured_input)
	for pair in [["StartOne",0],["StartTwo",6],["StartThree",7],["StartFour",13],["StartFive",8],["StartSix",15]]:
		if has_node("Root/Menu/"+pair[0]): get_node("Root/Menu/"+pair[0]).text = TITLES[pair[1]]
	refresh_setting_labels()



# 时间驱动的命中提示和受伤边缘渐隐；暂停时 UI 仍响应。
func _process(delta: float) -> void:
	hit_timer = maxf(0.0, hit_timer - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	$Root/HUD/HitMarker.modulate.a = smoothstep(0.0,0.08,hit_timer)
	var game: Node = get_parent()
	if is_instance_valid(game.get("player")):
		var weapon: Node=game.player.weapon
		var center: Vector2=get_viewport().get_visible_rect().size*.5
		if not weapon.profile.automatic and weapon.ads_progress>.85 and weapon.sight_blend<.15:
			center=get_viewport().get_visible_rect().size*weapon.optic_center
			center.y-=18.0
		$Root/HUD/HitMarker.top_level=true
		$Root/HUD/HitMarker.position=center-Vector2(22,22)
		$Root/HUD/HitMarker.size=Vector2(44,44)
	$Root/HUD/Damage.modulate.a = minf(1.0, hit_timer * 3.0)
	$Root/HUD/Hurt.modulate.a = hurt_timer * 1.2



# 暂停和设置页支持 Esc 返回，避免鼠标捕获状态与菜单不同步。
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if $Root/Settings.visible:
		close_settings()
		get_viewport().set_input_as_handled()
	elif $Root/Pause.visible:
		resume_requested.emit()
		get_viewport().set_input_as_handled()



# 显示大厅与已保存的个人校准值。
func show_menu() -> void:
	hide_pages()
	$Root/Menu.show()
	$Root/Menu/Calibration.text = "个人配置  /  灵敏度 %.2f   ·   FOV %d\n国服 · 烽火地带   /   精确参数待实测校准" % [sensitivity_slider.value, fov_slider.value]



# 控制顶层页面可见性，避免隐藏菜单拦截游戏鼠标。
func hide_pages() -> void:
	for page in $Root.get_children():
		if page is Control:
			page.hide()



# 显示实时 HUD。
func show_game(index: int) -> void:
	hide_pages()
	$Root/HUD.show()
	$Root/HUD/Level.text = "%02d / %s" % [index + 1, TITLES[index]]
	$Root/HUD/Objective.text = OBJECTIVES[index]
	$Root/HUD/Action.position = Vector2(30, 235) if index >= 6 else Vector2(1005.5556, 83)
	$Root/HUD/Action.size = Vector2(950, 70) if index >= 6 else Vector2(364.4444, 35)
	$Root/HUD/Action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Root/HUD/TrainingActionPlate.visible = index >= 13 and index != 19
	$Root/HUD/Action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for item in ["Stats", "Time", "TimeCaption", "TimePlate", "Ammo", "AmmoPlate", "WeaponName", "Health", "HealthPlate", "HP", "Dash", "DashPlate", "Charge", "ChargePlate", "Thumper", "ThumperPlate", "Action", "Controls", "InputReadout"]:
		get_node("Root/HUD/" + item).visible = index != 12
	$Root/HUD/JetVignette.modulate.a = 0
	if index == 12:
		$Root/HUD/Level.text = "嘉豪训练中心 / 烽火地带"



# 暂停菜单使用独立节点，可直接在编辑器中替换视觉。
func show_pause() -> void:
	$Root/Pause.show()
	$Root/Pause/Panel/Finish.disabled = get_parent().level_index == 12



# 更新弹匣、动作提示、生命、反应训练统计和瞄准镜覆盖层。
func update_hud(session: Node) -> void:
	$Root/HUD/Controls.text = "%s/%s 侧头  T 语音  %s 瞄准  %s 瞄具  %s 倍率  %s 换弹  Esc 暂停 / 设置" % [binding_name("lean_left"), binding_name("lean_right"), binding_name("aim"), binding_name("laser"), binding_name("zoom"), binding_name("reload")]
	var player: Node = session.player
	var weapon: Node = player.weapon
	$Root/HUD/Stats.text = "%02d  击倒       %02d  爆头       %03d%%  命中" % [session.kills, session.headshots, int(100.0 * session.hits / maxi(1, session.shots))]
	if session.level.has_method("live_stats"):
		$Root/HUD/Stats.text = session.level.live_stats()
	var seconds: float = maxf(0, session.session_length - session.elapsed) if session.level.target_count == 0 and not session.level.free_roam else session.elapsed
	$Root/HUD/Time.text = "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	$Root/HUD/Ammo.text = "%02d  /  ∞" % weapon.ammo
	$Root/HUD/WeaponName.text = weapon.profile.display_name + (" / 镭射" if weapon.laser_mode else " / %sx" % str(weapon.zoom_multiplier)) + (" / " + weapon.fire_mode_label() if weapon.profile.supports_single_fire else "")
	$Root/HUD/Health.value = player.health
	$Root/HUD/HP.text = "%03d  HP" % int(player.health)
	$Root/HUD/Reload.text = "换弹中  %.1fs" % weapon.reload_time if weapon.reload_time > 0 else ("拉栓中…" if weapon.cooldown > 0 and not weapon.profile.automatic else "")
	$Root/HUD/Scope.visible = weapon.ads_progress > 0.85 and weapon.sight_blend < 0.15 and not weapon.profile.automatic
	$Root/HUD/Scope.modulate.a = clampf((weapon.ads_progress - 0.85) / 0.12, 0, 1) * clampf((0.15 - weapon.sight_blend) / 0.12, 0, 1)
	# The reticle follows the physical ocular projection; the gun supplies the frame.
	$Root/HUD/Scope.top_level=true
	$Root/HUD/Scope.position=Vector2.ZERO
	$Root/HUD/Scope.size=get_viewport().get_visible_rect().size
	$Root/HUD/Scope.material.set_shader_parameter("aperture_center",weapon.optic_center)
	$Root/HUD/Scope.material.set_shader_parameter("aperture_radius",weapon.optic_radius)
	$Root/HUD/Crosshair.visible = not $Root/HUD/Scope.visible
	var action_text: String = "保持架点，嘉豪随时探头"
	if session.level.target_count > 0:
		action_text = "区域清除  %d / %d" % [session.kills, session.level.target_count]
	else:
		for enemy in session.level.get_node("Enemies").get_children():
			if not enemy.dead:
				action_text = enemy.action_label
	if session.level.has_method("schedule_volley"):
		var remaining: int = 0
		for target in session.level.get_node("Enemies").get_children():
			if not target.dead:
				remaining += 1
		action_text = "第 %d 波 · 剩余 %d / 3 · %s" % [session.level.wave, remaining, "同步出击" if session.level.synchronized_volley else "错峰出击"]
	$Root/HUD/Action.text = session.level.progress_text() if session.level.has_method("progress_text") else action_text
	var kit: Node = player.abilities
	if kit.held_kind != "":
		$Root/HUD/Action.text = ("C4" if kit.held_kind == "charge" else "虎蹲炮") + " 已拿出 · " + binding_name("fire") + " 投掷 · " + binding_name("aim") + " 收起"
	$Root/HUD/Dash.text = binding_name("dash") + "  动力推进\n" + ("就绪" if kit.dash_cd <= 0 else "%.1fs" % kit.dash_cd)
	$Root/HUD/Charge.text = binding_name("charge") + "  磁吸 C4\n%d / %d" % [kit.charges, kit.charge_capacity]
	$Root/HUD/Thumper.text = binding_name("thumper") + "  虎蹲炮\n" + ("就绪" if kit.thumper_cd <= 0 else "%.1fs" % kit.thumper_cd)
	$Root/HUD/AbilityMessage.text = session.ability_message if session.ability_message_time > 0 else ("动能辅助 · 加速 %.1fs" % kit.passive_remaining if kit.passive_remaining > 0 else "")
	$Root/HUD/JetVignette.modulate.a = kit.effect_time * 0.3
	$Root/HUD/InputReadout.text = "%d DPI  /  %.1f cm/360  /  FOV %d" % [player.mouse_dpi, player.cm_per_360(), player.base_fov]



# 命中音和简短中文伤害数字。
func flash_hit(zone: String, damage: float) -> void:
	hit_duration = 0.30 if zone == "head" else 0.23
	hit_timer = hit_duration
	$HitSound.pitch_scale = 1.3 if zone == "head" else 1.0
	$HitSound.play()
	$Root/HUD/Damage.text = ("脑瓜嗡嗡！  " if zone == "head" else "命中  ") + str(int(damage))
	$Root/HUD/HitMarker.modulate = Color.WHITE
	$Root/HUD/HitMarker.material.set_shader_parameter("head_hit",zone == "head")



# 结果卡展示练习数据，并支持一键再来。
func show_results(success: bool, session: Node) -> void:
	hide_pages()
	$Root/Results.show()
	$Root/Results/Panel/Title.text = "嘉豪：下把一定。" if success else "这次轮到你当假人了。"
	$Root/Results/Panel/Subtitle.text = "训练完成 / SESSION COMPLETE" if success else "训练结束 / 再试一次"
	$Root/Results/Panel/Numbers.text = "%d  击倒     %d  爆头     %d%%  命中率\n\n%.2f 秒    ·    %d 发射击" % [session.kills, session.headshots, int(session.hits * 100.0 / maxi(1, session.shots)), session.elapsed, session.shots]



# 校准面板可以从大厅或暂停页打开。
func open_settings(origin: String) -> void:
	settings_return = origin
	$Root/Settings.show()



# 返回原页面并保存个人配置。
func close_settings() -> void:
	$Root/Settings.hide()
	if settings_return == "menu":
		show_menu()



# 数值直接反馈在滑块标题中，避免用户不确定实际设置。
func refresh_setting_labels() -> void:
	$Root/Settings/Panel/SensitivityLabel.text = "鼠标灵敏度    %.2f" % sensitivity_slider.value
	$Root/Settings/Panel/FOVLabel.text = "视野 FOV    %d°" % fov_slider.value
	$Root/Settings/Panel/ADSLabel.text = "瞄准镜灵敏度倍率    %.2f" % ads_slider.value
	$Root/Settings/Panel/LaserLabel.text = "镭射瞄准灵敏度倍率    %.2f" % laser_slider.value
	$Root/Settings/Panel/YawLabel.text = "输入校准系数    %.6f" % yaw_slider.value
	$Root/Settings/Panel/VolumeLabel.text = "主音量    %d%%" % int(volume_slider.value * 100)



# 用户设置存入 user://，不污染版本管理中的默认资源。
func save_settings() -> void:
	var config := ConfigFile.new()
	for key in ["sensitivity", "fov", "ads", "laser", "yaw", "volume"]:
		config.set_value("input", key, get(key + "_slider").value)
	config.set_value("input", "fov_axis", fov_axis.selected)
	config.set_value("training", "invincible", invincible.button_pressed)
	config.set_value("meta", "version", 6)
	config.set_value("display", "mode", $Root/Settings/Panel/DisplayMode.selected)
	config.set_value("input", "profile", $InputProfiles.current_id)
	for pair in [["dpi", "DPI"], ["horizontal", "Horizontal"], ["vertical", "Vertical"], ["monitor_distance", "MonitorDistance"]]:
		config.set_value("input", pair[0], get_node("Root/Settings/Panel/" + pair[1]).value)
	config.set_value("input", "match_mode", $Root/Settings/Panel/MatchMode.selected)
	config.save("user://settings.cfg")



# 启动读取设置，首次启动采用用户提供的 3.5 和 95。
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		$Root/Settings/Panel/DisplayMode.select(config.get_value("display", "mode", 0))
		$InputProfiles.current_id = config.get_value("input", "profile", "custom")
		for key in ["sensitivity", "fov", "ads", "laser", "yaw", "volume"]:
			get(key + "_slider").set_value_no_signal(config.get_value("input", key, get(key + "_slider").value))
		fov_axis.select(config.get_value("input", "fov_axis", 0))
		invincible.set_pressed_no_signal(config.get_value("training", "invincible", false))
		if config.get_value("meta", "version", 1) < 2:
			config.save("user://settings_v1_backup.cfg")
			yaw_slider.set_value_no_signal(0.005555)
			ads_slider.set_value_no_signal(1.0)
			laser_slider.set_value_no_signal(1.0)
		for pair in [["dpi", "DPI"], ["horizontal", "Horizontal"], ["vertical", "Vertical"], ["monitor_distance", "MonitorDistance"]]:
			var spin: Range = get_node("Root/Settings/Panel/" + pair[1])
			spin.set_value_no_signal(config.get_value("input", pair[0], spin.value))
		$Root/Settings/Panel/MatchMode.select(config.get_value("input", "match_mode", 0))
		if config.get_value("meta", "version", 1) < 3:
			config.save("user://settings_before_input_fix.cfg")
			sensitivity_slider.set_value_no_signal(3.5)
			fov_slider.set_value_no_signal(95)
			$Root/Settings/Panel/DPI.set_value_no_signal(800)
			$Root/Settings/Panel/Horizontal.set_value_no_signal(1)
			$Root/Settings/Panel/Vertical.set_value_no_signal(1)
			$Root/Settings/Panel/MonitorDistance.set_value_no_signal(1.33)
		if config.get_value("meta", "version", 1) < 4 and absf(yaw_slider.value - 0.005555) < 0.000001:
			config.save("user://settings_before_converter_fix.cfg")
			yaw_slider.set_value_no_signal(0.010685713351)
	refresh_setting_labels()



# 把高级输入设置同步到玩家，DPI 仅用于物理距离换算，不重复乘到鼠标转角。
func apply_advanced_settings(player: Node) -> void:
	player.mouse_dpi = $Root/Settings/Panel/DPI.value
	player.horizontal_sensitivity = $Root/Settings/Panel/Horizontal.value
	player.vertical_sensitivity = $Root/Settings/Panel/Vertical.value
	player.monitor_distance = $Root/Settings/Panel/MonitorDistance.value
	player.monitor_match = $Root/Settings/Panel/MatchMode.selected == 0
	player.measured_aim_ratios = read_measured_ratios() if $InputProfiles.current_id == "custom" else {}
	$Root/Settings/Panel/CurrentCM.text = "当前腰射：%.2f cm / 360°" % player.cm_per_360()



# 用目标游戏实测的转圈距离反求系数，得到可验证的腰射物理灵敏度。
func calibrate_from_cm() -> void:
	$InputProfiles.current_id = "custom"
	var cm: float = $Root/Settings/Panel/TargetCM.value
	yaw_slider.value = 914.4 / ($Root/Settings/Panel/DPI.value * sensitivity_slider.value * $Root/Settings/Panel/Horizontal.value * cm)



# 导入本体原始计数实测，直接反求腰射系数，避免继续猜测游戏内部常数。
func import_measured_input() -> void:
	var path := "user://delta_measurements/hip.json"
	if not FileAccess.file_exists(path):
		$Root/Settings/Panel/CMNote.text = "先运行 measure_delta_input.cmd，在本体按 F8 / F9 测量。"
		return
	var sample = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not sample is Dictionary or float(sample.get("counts", 0)) <= 100:
		$Root/Settings/Panel/CMNote.text = "实测文件无效，未改变设置。"
		return
	$InputProfiles.current_id = "custom"
	var coefficient: float = 360.0 / float(sample.counts) / sensitivity_slider.value / $Root/Settings/Panel/Horizontal.value
	yaw_slider.max_value = maxf(yaw_slider.max_value, coefficient * 1.1)
	yaw_slider.value = coefficient
	$Root/Settings/Panel/CMNote.text = "已导入腰射实测；镜瞄与镭射分别测量后再次导入。"
	settings_changed.emit()



# 每个瞄准模式单独读取实测转角比；缺失模式不伪装成已校准。
func read_measured_ratios() -> Dictionary:
	var values: Dictionary = {}
	var base_path := "user://delta_measurements/hip.json"
	if not FileAccess.file_exists(base_path):
		return values
	var hip = JSON.parse_string(FileAccess.get_file_as_string(base_path))
	if not hip is Dictionary or float(hip.get("counts", 0)) <= 100:
		return values
	for key in ["laser", "optic_1.5", "optic_3", "optic_7"]:
		var path: String = "user://delta_measurements/" + key + ".json"
		if FileAccess.file_exists(path):
			var sample = JSON.parse_string(FileAccess.get_file_as_string(path))
			if sample is Dictionary and float(sample.get("counts", 0)) > 100:
				values[key] = float(hip.counts) / float(sample.counts)
	return values



# 将当前参数传给在线转换器，重新计算后只更新腰射系数。
func open_converter() -> void:
	$Calibration.configure(sensitivity_slider.value, $Root/Settings/Panel/DPI.value, fov_slider.value, $Root/Settings/Panel/MonitorDistance.value, $Root/Settings/Panel/Horizontal.value)
	$Calibration.popup_centered()



# 操作提示读取当前绑定，改键后提示同步更新。
func binding_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	return events[0].as_text().replace(" (Physical)", "").replace(" - Physical", "").replace("Left Mouse Button", "左键").replace("Right Mouse Button", "右键") if not events.is_empty() else "未绑定"



# 三方案切换备份旧配置，明确覆盖所有参与计算的字段，避免倍率叠乘。
func apply_input_profile(data: Dictionary) -> void:
	var backup := ConfigFile.new()
	if backup.load("user://settings.cfg") == OK:
		backup.save("user://settings_before_profile.cfg")
	sensitivity_slider.set_value_no_signal(data.mouse)
	fov_slider.set_value_no_signal(data.fov)
	yaw_slider.set_value_no_signal(data.yaw)
	ads_slider.set_value_no_signal(1.0)
	laser_slider.set_value_no_signal(1.0)
	fov_axis.select(0)
	$Root/Settings/Panel/DPI.set_value_no_signal(data.dpi)
	$Root/Settings/Panel/Horizontal.set_value_no_signal(data.horizontal)
	$Root/Settings/Panel/Vertical.set_value_no_signal(data.vertical)
	$Root/Settings/Panel/MonitorDistance.set_value_no_signal(data.md)
	$Root/Settings/Panel/MatchMode.select(0)
	refresh_setting_labels()
	settings_changed.emit()
