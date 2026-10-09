extends Node3D

@export var level_number: int = 1
@export var respawn_delay: float = 1.3
@export var target_count: int = 0
@export var free_roam: bool = false
var enemy_scene: PackedScene = preload("res://scenes/actors/enemy.tscn")
var practice_action: int = -1
var difficulty: int = 1



# 关卡内所有敌人来自可单独编辑的 NPC 实例。
func _ready() -> void:
	for enemy in $Enemies.get_children():
		configure_enemy(enemy)



# 难度和单动作练习只覆盖 NPC 导出参数，不改变关卡节点结构。
func configure_enemy(enemy: Node) -> void:
	enemy.reaction_seconds = [0.9, 0.5, 0.25][difficulty]
	enemy.accuracy = [0.3, 0.6, 0.85][difficulty]
	if practice_action >= 0:
		enemy.enabled_actions = PackedInt32Array([practice_action])
	enemy.eliminated.connect(on_eliminated)



# 第一关持续补充假人；第二关保留三名敌人用于完整遭遇计时。
func on_eliminated(enemy: Node) -> void:
	if target_count > 0:
		return
	var spawn: Vector3 = enemy.origin
	var old_behavior: int = enemy.behavior
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(enemy):
		enemy.queue_free()
	var replacement: Node3D = enemy_scene.instantiate()
	replacement.position = spawn
	replacement.behavior = old_behavior
	$Enemies.add_child(replacement)
	configure_enemy(replacement)
