extends CharacterBody3D

signal player_bullet_hit
signal emotion_response(face: int, text: String)

enum FaceExpression { NEUTRAL, CRYING, HAPPY, EXCITED, SMUG, ANGRY, SCARED }

# World-space breadcrumbs belong to locomotion, never to the camera or AI response loop.
const START_DISTANCE := 3.8
const STOP_DISTANCE := 2.2
var reaction: float = 0
var time: float = 0
var stalled: float = 0
var following := false
var departure_delay := 0.0
var stride := 0.0
var trail: Array[Vector3] = []
var hidden_time := 0.0
var crying_time := 0.0
var expression := FaceExpression.NEUTRAL
@onready var game: Node = get_parent()

func _ready() -> void:
	# Keep legacy UI and gesture anchors even if an importer strips empty nodes.
	ensure_anchor("Head", Vector3(0, 1.08, 0))
	ensure_anchor("ArmLeft", Vector3(-0.29, 0.7, 0))
	ensure_anchor("ArmRight", Vector3(0.29, 0.7, 0))
	set_expression(FaceExpression.NEUTRAL)
	$PlayerBulletHitArea.collision_layer = 0
	var responses := preload("res://scripts/companion_reactions.gd").new()
	responses.name = "Responses"
	add_child(responses)
	var hug := preload("res://scripts/companion_hug_candidate.gd").new()
	hug.name = "Hug"
	add_child(hug)

func set_expression(next_expression: int) -> void:
	expression = clampi(next_expression, FaceExpression.NEUTRAL, FaceExpression.SCARED)
	$Body/MouseVisual.visible = expression == FaceExpression.NEUTRAL
	$Body/CryExpression.visible = expression == FaceExpression.CRYING
	$Body/Expressions.show_expression(expression)

func receive_hit(_damage: float, _zone: String) -> void:
	# A companion hit is feedback, not enemy damage or a scored training hit.
	if not visible or not game.get_node("Companion").enabled:
		return
	$Responses.on_hurt()
	reaction = 0.6
	player_bullet_hit.emit()

func ensure_anchor(anchor_name: String, offset: Vector3) -> void:
	if $Body.has_node(anchor_name):
		return
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	anchor.position = offset
	$Body.add_child(anchor)

func react(action: String) -> void:
	reaction = 1.4 if action == "cheer" else (0.6 if action == "nod" else 0.0)

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func clear_path(a: Vector3, b: Vector3) -> bool:
	var side := flat(b - a).normalized().cross(Vector3.UP) * 0.28
	for offset in [Vector3.ZERO, side, -side]:
		var ray := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.65 + offset, b + Vector3.UP * 0.65 + offset, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return false
	return true

func ground_at(point: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point - Vector3.UP * 1.5, 1))

func reset_position() -> void:
	if has_node("Hug"):
		$Hug.cancel($Hug.epoch == $Hug.current_epoch())
	visible = game.get_node("Companion").enabled
	crying_time = 0.0
	set_expression(FaceExpression.NEUTRAL)
	if not game.player.visible:
		global_position = Vector3(3.45, 0.18, 0.7)
		return
	# In the base she spawns in view so the player can find her. In a training
	# course she starts beside/behind the player, outside the aiming view, so she
	# never covers the lane or the lower-left HUD at the start of a round.
	var origin: Vector3 = game.player.global_position
	global_position = origin + Vector3.UP * 0.05
	var in_base: bool = game.get("level_index") == 12
	var offsets: Array = [Vector3(-1.25,0,-2.5), Vector3(1.25,0,-2.5), Vector3(-1.1,0,-1.3)] if in_base else [Vector3(-1.5,0,0.9), Vector3(1.5,0,0.9), Vector3(-0.6,0,1.6), Vector3(0.6,0,1.6)]
	for offset in offsets:
		var candidate: Vector3 = origin + game.player.global_basis * offset
		var ground := ground_at(candidate)
		if clear_path(origin, candidate) and not ground.is_empty():
			global_position = ground.position + Vector3.UP * 0.05
			break
	velocity = Vector3.ZERO
	rotation.y = atan2(origin.x - global_position.x, origin.z - global_position.z)
	trail.clear()
	trail.append(origin)
	following = false
	departure_delay = 0
	stalled = 0
	hidden_time = 0

func reversed_trail() -> Array[Vector3]:
	var points := trail.duplicate()
	points.reverse()
	return points

func steer(direction: Vector3) -> Vector3:
	# Capsule-width probes and a floor probe prevent wall sliding and walking off ledges.
	for angle in [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35]:
		var heading := direction.rotated(Vector3.UP, angle)
		var ahead := global_position + heading * 0.85
		if clear_path(global_position, ahead) and not ground_at(ahead).is_empty():
			return heading
	return Vector3.ZERO

func _physics_process(delta: float) -> void:
	visible = game.get_node("Companion").enabled
	# The floating name tag is a base-hall wayfinding aid; in courses it sits in the aim view.
	$Name.visible = game.get("level_index") == 12
	$PlayerBulletHitArea.collision_layer = 2 if visible else 0
	$Hug.step(delta)
	if $Hug.owns_motion():
		return
	if not visible:
		velocity = Vector3.ZERO
		return
	if crying_time > 0.0:
		crying_time = maxf(0.0, crying_time - delta)
		if crying_time <= 0.0:
			set_expression(FaceExpression.NEUTRAL)
	if not game.player.visible:
		global_position = Vector3(3.45, 0.18, 0.7)
		rotation.y = -0.35
		return
	time += delta
	reaction = maxf(0, reaction - delta)
	var player_pos: Vector3 = game.player.global_position
	if trail.is_empty():
		trail.append(player_pos)
	if flat(player_pos - trail.back()).length() > 0.65 and game.player.is_on_floor():
		trail.append(player_pos)
		if trail.size() > 160: trail.pop_front()
	var distance := flat(player_pos - global_position).length()
	var on_screen: bool = game.player.camera.is_position_in_frustum(global_position + Vector3.UP)
	hidden_time = 0.0 if on_screen else hidden_time + delta
	# Recovery is deliberately off-screen, never an orbiting, visible three-second teleport.
	if hidden_time > 2.0 and (distance > 28 or stalled > 8 or global_position.y < -10):
		for point in reversed_trail():
			if flat(point-player_pos).length() < 4 or flat(point-player_pos).length() > 12 or game.player.camera.is_position_in_frustum(point + Vector3.UP): continue
			var ground := ground_at(point)
			if not ground.is_empty():
				global_position = ground.position + Vector3.UP * 0.05
				velocity = Vector3.ZERO
				stalled = 0
				hidden_time = 0
				break
	if not following:
		departure_delay = departure_delay + delta if distance > START_DISTANCE else 0.0
		if departure_delay > 0.4: following = true
	elif distance < STOP_DISTANCE and clear_path(global_position, player_pos):
		following = false
		departure_delay = 0
	var desired := Vector3.ZERO
	if following:
		# Consume only reachable breadcrumbs: do not cut straight through a corner.
		while trail.size() > 1 and flat(trail[0]-global_position).length() < 0.85:
			trail.pop_front()
		var target: Vector3 = trail[0]
		for i in range(mini(trail.size(), 7) - 1, -1, -1):
			if clear_path(global_position, trail[i]):
				target = trail[i]
				for j in range(i): trail.pop_front()
				break
		var direction := flat(target-global_position)
		var speed := 3.2 if distance < 5.5 else (6.5 if distance < 10 else 9.0)
		speed = minf(speed, maxf(0.0, distance - 1.5) * 2.0)
		desired = steer(direction.normalized()) * speed
	elif distance < 1.05:
		# Yield personal space only when approached, never when the camera turns or aims.
		desired = steer(flat(global_position-player_pos).normalized()) * 1.3
	velocity.x = move_toward(velocity.x, desired.x, delta * 7)
	velocity.z = move_toward(velocity.z, desired.z, delta * 7)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18 * delta
	var before := global_position
	move_and_slide()
	var traveled := flat(global_position-before).length()
	stalled = stalled + delta if following and traveled < delta * 0.15 else 0.0
	var walking := traveled / maxf(delta, 0.001)
	stride += traveled * 5.0
	if walking > 0.2:
		# Back away while still facing the nearby player, ready for a waist grip.
		var facing := player_pos-global_position if not following and distance < 1.05 else velocity
		rotation.y = rotate_toward(rotation.y, atan2(facing.x, facing.z), delta * (7.0 if not following and distance < 1.05 else 3.5))
	elif reaction > 0:
		rotation.y = rotate_toward(rotation.y, atan2(player_pos.x-global_position.x, player_pos.z-global_position.z), delta * 1.6)
	# The imported figures are single meshes. Animate only their shared root so
	# no body part is stretched by the old primitive walk cycle.
	$Body.position.y = absf(sin(stride)) * 0.035 if walking > 0.2 else sin(time * 2) * 0.012
	$Body.rotation.z = sin(time * 9) * 0.07 if reaction > 0 else 0.0
	$Body.rotation.x = 0.0
	$Body/ArmLeft.rotation.z = -0.8 - sin(time * 16) * 0.2 if reaction > 0 else 0.12
	$Body/ArmRight.rotation.z = 0.8 + sin(time * 16) * 0.2 if reaction > 0 else -0.12
	var mind: Variant = game.get_node("Companion").get("mind")
	if mind == null:
		return
	var mood: String = mind.emotion
	var strength: float = mind.intensity
	if walking < 0.2:
		if mood in ["不开心", "生气"]:
			$Body.rotation.x = lerpf(0.0, 0.08, strength)
		elif mood in ["激动", "极其激动"]:
			$Body.position.y += absf(sin(time * 7)) * 0.08 * strength
		elif mood in ["喜欢", "爱慕", "钦佩", "渴望"]:
			$Body.rotation.z += sin(time * 1.5) * 0.05 * strength
		elif mood == "震惊":
			$Body.rotation.x = -0.07 * strength
		else:
			$Body.rotation.x = 0

