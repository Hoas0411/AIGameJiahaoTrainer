extends Node3D
## Owns only companion affection. Existing player combat/visibility gates are leased
## for one level epoch and never restored over a replacement session's state.
enum Phase { NONE, APPROACH, REQUEST, PICKUP, HELD, CHEEK, RELEASE }
const MOUSE := preload("res://assets/models/companions/hug_precision_20260930/mouse_hug.glb")
const ARMS := preload("res://assets/models/companions/hug_precision_20260930/support_arms.glb")
const HOLD_OFFSET := Vector3(0, -0.98, -1.48)
var phase := Phase.NONE
var elapsed := 0.0
var idle_time := 0.0
var invitation_cooldown := 25.0
var epoch := 0
var combat_before := false
var weapon_before := false
var start_pose := Transform3D.IDENTITY
var release_pose := Transform3D.IDENTITY
var model: Node3D
var arms: Node3D
var left_support: Node3D
var right_support: Node3D
var left_support_rest := Vector3.ZERO
var right_support_rest := Vector3.ZERO
var animation: AnimationPlayer
var animation_name: StringName
var label: Label
var cloth: AudioStreamPlayer
@onready var actor: CharacterBody3D = get_parent()
@onready var game: Node = actor.get_parent()

func _ready() -> void:
	process_priority = 100
	register_action("companion_hug", [KEY_O, KEY_U, KEY_L])
	register_action("companion_cheek", [KEY_P, KEY_I])
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC-Medium.ttf"))
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(label)
	cloth = AudioStreamPlayer.new()
	cloth.volume_db = -16
	cloth.stream = cloth_sound()
	add_child(cloth)

func register_action(action: String, candidates: Array) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action)
	for key in candidates:
		var event := InputEventKey.new()
		event.physical_keycode = key
		var used := false
		for other in InputMap.get_actions():
			if not str(other).begins_with("ui_") and InputMap.event_is_action(event, other): used = true
		if not used:
			InputMap.action_add_event(action, event)
			return

func key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	return OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() and events[0] is InputEventKey else "未绑定"

func current_epoch() -> int:
	var level: Variant = game.get("level")
	return level.get_instance_id() if is_instance_valid(level) else 0

func player_node() -> Node3D:
	return game.get("player") as Node3D

func available() -> bool:
	var player := player_node()
	return is_instance_valid(player) and game.get("running") == true and player.get("active") == true and player.visible and game.get_node("Companion").enabled

func carrying() -> bool:
	return phase in [Phase.PICKUP, Phase.HELD, Phase.CHEEK, Phase.RELEASE]

func owns_motion() -> bool:
	return phase != Phase.NONE

func ensure_visual() -> void:
	if is_instance_valid(model): return
	model = MOUSE.instantiate()
	model.scale = Vector3.ONE * 0.67
	add_child(model)
	arms = ARMS.instantiate()
	arms.scale = Vector3.ONE * 0.67
	add_child(arms)
	left_support = arms.find_child("LeftSupport", true, false)
	right_support = arms.find_child("RightSupport", true, false)
	assert(left_support != null and right_support != null)
	left_support_rest = left_support.position
	right_support_rest = right_support.position
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(animation != null)
	for name in animation.get_animation_list():
		if "HugSequence" in str(name): animation_name = name
	assert(not animation_name.is_empty())
	animation.play(animation_name)
	animation.pause()

func sample(seconds: float) -> void:
	animation.seek(seconds, true)

func support_pose(progress: float) -> void:
	# Enter from the sides after the knees fold; never slide a palm through a leg.
	var forward := 0.18 * (1-progress)
	left_support.position = left_support_rest + Vector3(-0.60*(1-smoothstep(0.66,1,progress)),-0.08*sin(PI*progress),forward)
	right_support.position = right_support_rest + Vector3(0.32*(1-smoothstep(0.2,1,progress)),0,forward)

func can_pickup() -> bool:
	if not available() or carrying(): return false
	var player := player_node()
	if player.get("controls_blocked") == true: return false
	var abilities: Variant = player.get("abilities")
	if is_instance_valid(abilities) and (abilities.get("held_kind") != "" or float(abilities.get("cast_time")) > 0 or float(abilities.get("dash_remaining")) > 0): return false
	return actor.global_position.distance_to(player.global_position) < 2.2 and actor.clear_path(player.global_position, actor.global_position)

func pickup() -> bool:
	if not can_pickup(): return false
	var player := player_node()
	ensure_visual()
	epoch = current_epoch()
	combat_before = player.combat_enabled
	weapon_before = player.weapon.visible
	player.combat_enabled = false
	player.weapon.hide()
	phase = Phase.PICKUP
	elapsed = 0
	start_pose = actor.global_transform
	actor.velocity = Vector3.ZERO
	actor.get_node("Body").hide()
	actor.get_node("PlayerBulletHitArea").collision_layer = 0
	model.show()
	arms.show()
	support_pose(0)
	actor.get_node("Responses").on_hug()
	cloth.play()
	return true

func kiss_cheek() -> bool:
	if phase != Phase.HELD: return false
	phase = Phase.CHEEK
	elapsed = 0
	actor.emotion_response.emit(2, "嘿嘿～脸脸痒痒的！")
	cloth.play()
	return true

func safe_floor() -> Dictionary:
	var player := player_node()
	for offset in [Vector3(-0.85,0,-1.3), Vector3(0.85,0,-1.3), Vector3(0,0,-1.7), Vector3(-1.2,0,0), Vector3(1.2,0,0)]:
		var candidate: Vector3 = player.global_position + player.global_basis * offset
		var floor_hit: Dictionary = actor.ground_at(candidate)
		if not floor_hit.is_empty() and floor_hit.normal.y > 0.7 and actor.clear_path(player.global_position, candidate):
			return floor_hit
	return {}

func put_down() -> bool:
	if phase != Phase.HELD: return false
	var floor_hit := safe_floor()
	if floor_hit.is_empty():
		actor.emotion_response.emit(2, "这里站不稳，找块空地再放我下来吧～")
		return false
	start_pose = actor.global_transform
	release_pose = Transform3D(Basis(Vector3.UP, player_node().global_rotation.y), floor_hit.position + Vector3.UP * 0.05)
	phase = Phase.RELEASE
	elapsed = 0
	cloth.play()
	return true

func cancel(restore_player: bool = true) -> void:
	var was_carrying := carrying()
	var player := player_node()
	# Session setup may already have installed its own weapon and combat gates.
	if was_carrying and restore_player and is_instance_valid(player) and epoch == current_epoch():
		player.combat_enabled = combat_before
		player.weapon.visible = weapon_before
	phase = Phase.NONE
	elapsed = 0
	idle_time = 0
	invitation_cooldown = 60
	if is_instance_valid(model): model.hide()
	if is_instance_valid(arms): arms.hide()
	actor.get_node("Body").show()
	actor.velocity = Vector3.ZERO
	actor.get_node("Body").transform = Transform3D.IDENTITY
	if was_carrying:
		actor.rotation = Vector3(0, actor.rotation.y, 0)
		# Hug presentation is temporary, not a permanent standing smile.
		actor.get_node("Responses").remaining = 0
		actor.get_node("Responses").priority = 0
		actor.set_expression(0)

func _input(event: InputEvent) -> void:
	# Also blocks course-owned click tools that do not use the firearm gate.
	if carrying() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (event.is_action("fire") or event.is_action("aim")):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not available() or player_node().get("controls_blocked") == true or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or event.is_echo(): return
	if event.is_action_pressed("companion_hug"):
		if phase == Phase.HELD: put_down()
		elif not carrying(): pickup()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("companion_cheek") and carrying():
		kiss_cheek()
		get_viewport().set_input_as_handled()

func step(delta: float) -> void:
	if not available():
		if phase != Phase.NONE: cancel(epoch == current_epoch())
		return
	if phase != Phase.NONE and epoch != current_epoch():
		cancel(false)
		return
	var player := player_node()
	invitation_cooldown = maxf(0, invitation_cooldown - delta)
	if phase == Phase.NONE:
		var calm: bool = player.velocity.length() < 0.15 and not Input.is_action_pressed("fire") and not player.controls_blocked
		idle_time = idle_time + delta if calm else 0.0
		if idle_time > 18 and invitation_cooldown == 0 and can_pickup():
			epoch = current_epoch()
			phase = Phase.APPROACH
			elapsed = 0
		return
	elapsed += delta
	if phase in [Phase.APPROACH, Phase.REQUEST]:
		if player.velocity.length() > 0.4 or Input.is_action_pressed("fire") or elapsed > 7 or player.controls_blocked:
			cancel()
			return
		var direction: Vector3 = actor.flat(player.global_position - actor.global_position)
		actor.rotation.y = atan2(direction.x, direction.z)
		if phase == Phase.APPROACH:
			if direction.length() > 0.85:
				var heading: Vector3 = actor.steer(direction.normalized())
				actor.velocity = heading * 0.6 + Vector3.DOWN * 0.5
				actor.move_and_slide()
			else:
				phase = Phase.REQUEST
				elapsed = 0
				# An invitation is still an ordinary standing character.
				if is_instance_valid(model): model.hide()
				if is_instance_valid(arms): arms.hide()
				actor.get_node("Body").show()
				actor.emotion_response.emit(2, "歇一会儿，抱抱？按 %s 就好～" % key_label("companion_hug"))
		return
	var camera: Camera3D = player.camera
	var held := Transform3D(camera.global_basis, camera.to_global(HOLD_OFFSET))
	if phase == Phase.PICKUP:
		var weight := smoothstep(0, 1, elapsed / 0.95)
		actor.global_transform = start_pose.interpolate_with(held, weight)
		sample(1.4 * weight)
		support_pose(weight)
		if elapsed >= 0.95: phase = Phase.HELD; elapsed = 0
	elif phase == Phase.HELD:
		actor.global_transform = actor.global_transform.interpolate_with(held, 1-exp(-delta*16))
		sample(2.0)
		support_pose(1)
	elif phase == Phase.CHEEK:
		var affection := sin(clampf(elapsed / 1.2, 0, 1) * PI)
		held.origin += camera.global_basis * Vector3(0.13*affection, 0.025*affection, 0.30*affection)
		actor.global_transform = actor.global_transform.interpolate_with(held, 1-exp(-delta*16))
		sample(2.0 + 0.8 * affection)
		if elapsed >= 1.2: phase = Phase.HELD; elapsed = 0
	elif phase == Phase.RELEASE:
		var weight := smoothstep(0, 1, elapsed / 0.85)
		actor.global_transform = start_pose.interpolate_with(release_pose, weight)
		sample(3.6 + 0.8 * weight)
		support_pose(1-weight)
		if elapsed >= 0.85:
			actor.global_transform = release_pose
			cancel()
	if carrying():
		actor.get_node("PlayerBulletHitArea").collision_layer = 0
		if actor.expression != 2: actor.set_expression(2)

func _process(_delta: float) -> void:
	if carrying() and is_instance_valid(game.get("level")):
		var click_tool: Node3D = game.level.get_node_or_null("ClickTool")
		if is_instance_valid(click_tool): click_tool.hide()
	label.visible = available() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player_node().controls_blocked
	if not label.visible: return
	label.size = Vector2(get_viewport().get_visible_rect().size.x, 36)
	label.position = Vector2(0, get_viewport().get_visible_rect().size.y - 60)
	label.text = "%s 放下  ·  %s 亲亲脸脸" % [key_label("companion_hug"), key_label("companion_cheek")] if carrying() else ("%s 抱起麦小鼠" % key_label("companion_hug") if can_pickup() else "")

func cloth_sound() -> AudioStreamWAV:
	# Quiet procedural cloth movement only, NOT a substitute or imitation voice.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	var pcm := PackedByteArray()
	pcm.resize(6000*2)
	var random := RandomNumberGenerator.new()
	random.seed = 930
	var filtered := 0.0
	for i in range(6000):
		filtered = lerpf(filtered, random.randf_range(-1,1), 0.2)
		var envelope := sin(PI * float(i)/6000)
		pcm.encode_s16(i*2, int(filtered*envelope*envelope*9000))
	stream.data = pcm
	return stream
