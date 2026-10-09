extends Node3D

var velocity: Vector3
var profile: WeaponProfile
var excluded: Array[RID] = []
var life: float = 3.0
var traveled: float = 0.0
var hit_player: bool = false
var visual_skip_remaining: float = 0.75
var shot_epoch := 0
var score_source: WeakRef
const TRAIL = preload("res://scenes/effects/tracer.tscn")
const IMPACT = preload("res://scenes/effects/impact.tscn")



# 初始化一颗可检查的独立弹道场景。
func launch(direction: Vector3, data: WeaponProfile, shooter: RID) -> void:
	profile = data
	velocity = direction * data.muzzle_velocity
	excluded.append(shooter)
	look_at(global_position + direction)
	var session := get_tree().get_first_node_in_group("session")
	if not hit_player and is_instance_valid(session):
		score_source = weakref(session)
		var level: Variant = session.get("level")
		if is_instance_valid(level): shot_epoch = level.get_instance_id()

func score_hits() -> int:
	var session: Variant = score_source.get_ref() if score_source != null else null
	return int(session.get("hits")) if is_instance_valid(session) else 0

func report_result(scored: bool) -> void:
	if not hit_player and shot_epoch != 0:
		get_tree().call_group("companion_reaction_observers", "observe_shot_result", scored, shot_epoch)
		shot_epoch = 0



# 每个物理帧扫掠整段轨迹，避免高速穿过头部或薄墙。
func _physics_process(delta: float) -> void:
	if profile == null:
		return
	var next: Vector3 = global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 5 if hit_player else 3, excluded)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var segment_end: Vector3 = hit.position if not hit.is_empty() else next
	var segment_length := global_position.distance_to(segment_end)
	var visual_start := global_position
	if visual_skip_remaining > 0.0:
		var skipped := minf(visual_skip_remaining, segment_length)
		visual_start += velocity.normalized() * skipped
		visual_skip_remaining -= skipped
	if visual_start.distance_to(segment_end) > 0.02:
		var trail := TRAIL.instantiate()
		get_tree().current_scene.add_child(trail)
		trail.setup(visual_start, segment_end)
	traveled += segment_length
	if not hit.is_empty():
		var hits_before := score_hits()
		var target: Node = hit.collider
		var zone: String = str(target.get_meta("zone", "body"))
		var character_hit := false
		if hit_player:
			if target.has_method("take_damage"):
				target.take_damage(profile.damage)
				character_hit = true
		else:
			while target != null and not target.has_method("receive_hit"):
				target = target.get_parent()
			if target != null:
				character_hit = true
				var damage: float = profile.damage_at(zone, traveled)
				target.receive_hit(damage, zone)
		var impact: Node3D = IMPACT.instantiate()
		get_tree().current_scene.add_child(impact)
		impact.global_position = hit.position + hit.normal * 0.02
		impact.setup(hit.normal, character_hit)
		report_result(score_hits() > hits_before)
		queue_free()
		return
	global_position = next
	velocity.y -= profile.bullet_gravity * delta
	life -= delta
	if life <= 0:
		report_result(false)
		queue_free()
