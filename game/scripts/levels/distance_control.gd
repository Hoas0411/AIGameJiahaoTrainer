extends "res://scripts/special_drill.gd"

const STATION_X := [-8.0, 0.0, 8.0]
const TARGET_Z := [-10.0, -25.0, -50.0]

func nearest_lane() -> int:
	var best := 0
	for index in range(1, 3):
		if absf(game.player.global_position.x - STATION_X[index]) < absf(game.player.global_position.x - STATION_X[best]):
			best = index
	return best

func _unhandled_input(event: InputEvent) -> void:
	if game.running and not game.player.controls_blocked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
			game.player.global_transform = get_node("Stations/Station%d" % nearest_lane()).global_transform
			game.player.velocity = Vector3.ZERO
			game.player.abilities.reset()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func configure_enemy(enemy: Node) -> void:
	super.configure_enemy(enemy)
	var target_material := StandardMaterial3D.new()
	target_material.albedo_color = Color(0.66, 0.22, 0.105)
	target_material.roughness = 0.85
	for mesh in enemy.get_node("Doll").find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = target_material

func progress_text() -> String:
	var lane := nearest_lane()
	var player_position: Vector3 = game.player.global_position
	var target_horizontal := Vector2(STATION_X[lane], TARGET_Z[lane])
	var distance := Vector2(player_position.x, player_position.z).distance_to(target_horizontal)
	var at_station := Vector2(player_position.x-STATION_X[lane], player_position.z).length() < 0.25
	return "%s · %d 米车道 · 实际水平距 %.1f 米\nJ 回当前车道站位 · 1 狙击 / 2 步枪 · 自由射击与控枪" % ["标准站位" if at_station else "自由位置", int(-TARGET_Z[lane]), distance]
