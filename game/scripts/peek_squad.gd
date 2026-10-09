extends "res://scripts/level.gd"

@export_range(0, 1) var synchronized_chance: float = 0.30
@export var volley_interval: float = 4.2
@export var wave_delay: float = 2.0
var volley_clock: float = 1.0
var wave_clock: float = -1.0
var wave: int = 1
var synchronized_volley: bool = false
var spawn_transforms: Array[Transform3D] = []
var spawn_settings: Array[Dictionary] = []



# 三名持久化 NPC 从两个掩体后出击，保存初始摆放作为下一波出生点。
func _ready() -> void:
	for enemy in $Enemies.get_children():
		spawn_transforms.append(enemy.transform)
		var settings: Dictionary = {}
		for property in enemy.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				settings[property.name] = enemy.get(property.name)
		spawn_settings.append(settings)
		configure_enemy(enemy)
		enemy.externally_scheduled = true
		enemy.state_time = 999
	volley_clock = 1.0
	# Flat terrace floor/apron/drain modules never cast a visible shadow.
	var architecture: Node = get_node_or_null("Architecture")
	if architecture:
		print("SHADOW_POLICY awm ", preload("res://scripts/presentation/shadow_policy.gd").ground_receives_only(architecture, ["Floor_", "Apron_", "Drain_"]))



# 整组击倒后才补充下一波，避免玩家杀一个就立刻多出第四个威胁。
func on_eliminated(_enemy: Node) -> void:
	var alive: int = 0
	for target in $Enemies.get_children():
		if not target.dead:
			alive += 1
	if alive == 0:
		wave_clock = wave_delay



# 每轮抽取同步或错峰时间，四种动作仍由各敌人独立选择。
func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not player.active:
		return
	if wave_clock >= 0:
		wave_clock -= delta
		if wave_clock <= 0:
			restart_wave()
		return
	volley_clock -= delta
	if volley_clock <= 0:
		schedule_volley(randf() < synchronized_chance)
		volley_clock = volley_interval



# 同步时使用相同起步时刻；错峰时提供互异延迟，不重置仍在掩体外的 NPC。
func schedule_volley(synchronized: bool) -> void:
	synchronized_volley = synchronized
	var index: int = 0
	for enemy in $Enemies.get_children():
		if not enemy.dead and enemy.phase == 0:
			enemy.state_time = 0.12 if synchronized else 0.12 + index * 0.47 + randf_range(0, 0.25)
		index += 1



# 一波三人清除后恢复相同编辑器出生点，不改变场景里设置的掩体距离。
func restart_wave() -> void:
	for enemy in $Enemies.get_children():
		$Enemies.remove_child(enemy)
		enemy.queue_free()
	for index in range(spawn_transforms.size()):
		var enemy: Node3D = enemy_scene.instantiate()
		enemy.transform = spawn_transforms[index]
		enemy.externally_scheduled = true
		for property in spawn_settings[index]:
			enemy.set(property, spawn_settings[index][property])
		$Enemies.add_child(enemy)
		configure_enemy(enemy)
		enemy.state_time = 999
	wave += 1
	wave_clock = -1
	volley_clock = 0.8
