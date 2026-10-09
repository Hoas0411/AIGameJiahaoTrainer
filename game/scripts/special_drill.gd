extends "res://scripts/level.gd"

@export_enum("Range", "Reaction", "Elevation", "Gadgets", "Audio", "Motion") var drill_kind: int = 0
var clock: float = 0
var next_at: float = 1
var exposed_at: float = -1
var first_hit: bool = false
var picked: Node3D
var reactions: Array[float] = []
var opportunities: int = 0
var audio_correct: int = 0
var audio_attempts: int = 0
var explosive_hits: int = 0
var reveal_until: float = 0
@onready var game: Node = get_parent()

func configure_enemy(enemy: Node) -> void:
	super.configure_enemy(enemy)
	enemy.attack_damage = 0
	enemy.attack_interval = 999
	enemy.attack_time = 999
	enemy.active = drill_kind == 3
	enemy.action_label = "专项靶"
	if drill_kind == 1 or drill_kind == 4:
		set_exposed(enemy, false)
	else:
		enemy.call_deferred("update_hitboxes")

func set_exposed(enemy: Node3D, show_target: bool) -> void:
	enemy.visible = show_target
	for area in enemy.get_node("Hitboxes").get_children():
		area.collision_layer = 2 if show_target and not enemy.dead else 0
	if show_target:
		enemy.update_hitboxes()

func _process(delta: float) -> void:
	if not game.running:
		return
	clock += delta
	if drill_kind not in [1, 4]:
		return
	if clock >= next_at:
		for enemy in $Enemies.get_children():
			set_exposed(enemy, false)
		var candidates: Array = $Enemies.get_children().filter(func(e): return not e.dead)
		if candidates.is_empty():
			next_at = clock + 0.5
			return
		picked = candidates.pick_random()
		opportunities += 1
		first_hit = false
		exposed_at = clock
		if drill_kind == 1:
			set_exposed(picked, true)
			next_at = clock + [2.4, 1.8, 1.2][difficulty] + randf_range(0.2, 0.8)
		else:
			$Cue.global_position = picked.global_position + Vector3.UP
			$Cue.play()
			next_at = clock + 5
	if drill_kind == 4 and reveal_until > 0 and clock > reveal_until:
		reveal_until = 0
		if is_instance_valid(picked):
			set_exposed(picked, false)

func _unhandled_input(event: InputEvent) -> void:
	if not game.running or game.player.controls_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if drill_kind in [0,5] and event.physical_keycode == KEY_J:
			game.player.global_transform = $PlayerSpawn.global_transform
			game.player.velocity = Vector3.ZERO
			game.player.abilities.reset()
		elif drill_kind == 4 and event.physical_keycode == KEY_F and is_instance_valid(picked) and not first_hit:
			first_hit = true
			audio_attempts += 1
			var facing: Vector3 = -game.player.global_basis.z
			var toward: Vector3 = picked.global_position - game.player.global_position
			toward.y = 0
			if facing.dot(toward.normalized()) >= cos(deg_to_rad(15)):
				audio_correct += 1
			set_exposed(picked, true)
			reveal_until = clock + 1.5
			next_at = clock + 2.2
			get_viewport().set_input_as_handled()

func record_hit(zone: String) -> void:
	if zone == "explosive":
		explosive_hits += 1
	if drill_kind == 1 and not first_hit and exposed_at >= 0 and zone != "explosive":
		reactions.append((clock - exposed_at) * 1000)
		first_hit = true

func on_eliminated(enemy: Node) -> void:
	var spawn: Vector3 = enemy.origin
	var behavior: int = enemy.behavior
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(enemy):
		enemy.queue_free()
	var replacement: Node3D = enemy_scene.instantiate()
	replacement.position = spawn
	replacement.behavior = behavior
	$Enemies.add_child(replacement)
	configure_enemy(replacement)

func metrics() -> Dictionary:
	var average: float = 0
	for value in reactions:
		average += value
	return {"drill": drill_kind, "reaction_ms": average / maxi(1, reactions.size()), "reaction_hits": reactions.size(), "opportunities": opportunities, "audio_correct": audio_correct, "audio_attempts": audio_attempts, "explosive_hits": explosive_hits, "jump_height": game.player.last_jump_height, "apex_seconds": game.player.last_apex_seconds, "dash_distance": game.player.abilities.measured_dash_distance}

func progress_text() -> String:
	match drill_kind:
		0: return "起点至靶 10 / 25 / 50 米 · J 回起点 · 1 狙击 / 2 步枪"
		1: return "首发命中平均 %.0f ms · 命中窗口 %d / %d" % [metrics().reaction_ms, reactions.size(), opportunities]
		2: return "先移动准心到下一层头线，再开枪 · 垂直转火不只练水平甩枪"
		3: return "爆炸有效命中 %d 次 · G / V 拿出 · 左键投出 · 控制后接枪" % explosive_hits
		4: return "听声后转向，按 F 确认 · 正确 %d / %d · 耳机左右声道" % [audio_correct, audio_attempts]
		5:
			var p: Node = game.player
			return "速度 %.2f m/s · 上次跳高 %.2f m / 到顶 %.3f s / 滞空 %.3f s\n喷气实移 %.2f m · F8 改参数 / J 重置" % [Vector2(p.velocity.x,p.velocity.z).length(),p.last_jump_height,p.last_apex_seconds,p.last_air_seconds,p.abilities.measured_dash_distance]
	return ""
