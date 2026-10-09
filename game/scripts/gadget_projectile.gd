extends Node3D

@export_enum("Magnetic charge", "Thumper") var kind: int = 0
@export var fuse_seconds: float = 3.0
@export var blast_radius: float = 5.0
@export var max_damage: float = 110.0
@export var stun_seconds: float = 4.0
@export var gravity: float = 12.0
@export var restitution: float = 0.38
var detonated: bool = false
var velocity := Vector3.ZERO
var shooter: Node3D
var attached: bool = false
var life: float = 0.0
var bounces: int = 0
const BLAST = preload("res://scenes/abilities/blast.tscn")



# 所有技能弹体加入会话清理组，重开时不会留下旧炸弹。
func _ready() -> void:
	add_to_group("projectiles")



# 磁吸炸弹遇到硬表面吸附；虎蹲弹碰撞后触发范围控制。
func _physics_process(delta: float) -> void:
	life += delta
	if not attached:
		var next: Vector3 = global_position + velocity * delta
		var ignored: Array[RID] = []
		if is_instance_valid(shooter):
			ignored.append(shooter.get_rid())
		var query := PhysicsRayQueryParameters3D.create(global_position, next, 5, ignored)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit.position + hit.normal * 0.035
			if kind == 0:
				attached = true
				velocity = Vector3.ZERO
				if absf(hit.normal.dot(Vector3.UP)) < 0.98:
					look_at(global_position - hit.normal)
			else:
				velocity = velocity.bounce(hit.normal) * restitution
				bounces += 1
				if velocity.length() < 1.2 or bounces >= 4:
					attached = true
					velocity = Vector3.ZERO
		else:
			global_position = next
			velocity.y -= gravity * delta
			$Model.rotate_x(delta * 5.0)
	$Indicator.visible = int(life * (5.0 if life < 2 else 14.0)) % 2 == 0
	if life >= fuse_seconds:
		detonate()



# 爆炸使用距离衰减与环境遮挡，虎蹲只控制而不冒充枪械命中。
func detonate() -> void:
	if detonated:
		return
	detonated = true
	set_physics_process(false)
	var blast: Node3D = BLAST.instantiate()
	blast.radius = blast_radius
	blast.control_only = kind == 1
	get_tree().current_scene.add_child(blast)
	blast.global_position = global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var chest: Vector3 = enemy.global_position + Vector3.UP
		var distance: float = chest.distance_to(global_position)
		if distance > blast_radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, chest, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		if kind == 1:
			enemy.apply_stun(stun_seconds, (chest - global_position).normalized() * 3.0)
		else:
			enemy.receive_hit(max_damage * lerpf(1.0, 0.25, clampf((distance - 1.0) / (blast_radius - 1.0), 0, 1)), "explosive")
	queue_free()
