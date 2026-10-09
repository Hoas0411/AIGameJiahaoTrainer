extends "res://scripts/level.gd"

const PORTAL_LEVELS: Array[int] = [0, 19, 7, 8, 15, 6]
const PORTAL_NAMES: Array[String] = ["AWM镭射", "三球定位", "Valorant随机反应", "高低差转移", "架门缝", "距离与控枪"]
const INTERACT_DISTANCE: float = 3.5
const PHONOGRAPH_DISTANCE: float = 2.05

var selected: int = -1
var phonograph_near: bool = false
@onready var game: Node = get_parent()


func _process(_delta: float) -> void:
	if not is_instance_valid(game.player):
		return
	var offset: Vector3 = game.player.global_position - $PhonographStation.global_position
	phonograph_near = Vector2(offset.x, offset.z).length() <= PHONOGRAPH_DISTANCE and absf(offset.y) < 1.4
	selected = -1
	var nearest: float = INTERACT_DISTANCE
	for station in $Stations.get_children():
		var distance: float = game.player.global_position.distance_to(station.global_position)
		if distance < nearest:
			nearest = distance
			selected = int(station.get_meta("station_id", -1))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F and not game.player.controls_blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not phonograph_near and selected >= 0:
			get_viewport().set_input_as_handled()
			activate(selected)


func is_phonograph_near() -> bool:
	return phonograph_near


func receive_hit(_damage: float, zone: String) -> void:
	if zone.begins_with("portal_"):
		activate(int(zone.trim_prefix("portal_")))
	elif zone.begins_with("weapon_"):
		activate(6 + int(zone.trim_prefix("weapon_")))


func activate(station_id: int) -> void:
	if station_id >= 0 and station_id < PORTAL_LEVELS.size():
		var target: int = PORTAL_LEVELS[station_id]
		if target >= 0:
			game.call_deferred("start_session", target)
	elif station_id == 6:
		game.player.weapon.equip(game.AWM)
	elif station_id == 7:
		game.player.weapon.equip(game.RIFLE)
	elif station_id == 8:
		game.call_deferred("start_session", 13)
	elif station_id == 9:
		game.call_deferred("start_session", 20)


func progress_text() -> String:
	if phonograph_near and game.has_node("RecordMusic"):
		return "唱片台 · %s · F 播放/暂停 · +/- 切歌 · 0 全局开关" % game.get_node("RecordMusic").status_text()
	if selected >= 0 and selected < PORTAL_LEVELS.size():
		if PORTAL_LEVELS[selected] < 0:
			return "此训练窗口尚未解锁 · 继续探索大厅"
		return "%s · 按 F 或射击靶牌进入" % PORTAL_NAMES[selected]
	if selected == 6:
		return "AWM 武器屏 · 按 F 或射击屏幕切换"
	if selected == 7:
		return "M7 武器屏 · 按 F 或射击屏幕切换"
	if selected == 8:
		return "跟随移动射击 · 按 F 或射击屏幕进入"
	if selected == 9:
		return "掩体分段射击 · 按 F 或射击屏幕进入"
	return "大厅八项训练 · F / 射击面板进入 · 平滑跟枪请按 Tab / F6 选择"
