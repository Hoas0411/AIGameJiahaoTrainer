extends Node3D

signal struck(target: Node3D, zone: String, damage: float)

@export var health: float = 100.0
@export var persistent: bool = false
var remaining_health: float = 100.0
var enabled: bool = true
var flash_left: float = 0.0
var death_hide_left: float = 0.0
var dying: bool = false
var render_meshes: Array[MeshInstance3D] = []
var hit_flash_material: StandardMaterial3D
var rest_scale := Vector3.ONE

func _ready() -> void:
	remaining_health = health
	rest_scale = scale
	add_to_group("training_targets")
	for node in $Art.find_children("*", "MeshInstance3D", true, false):
		render_meshes.append(node as MeshInstance3D)
	hit_flash_material = StandardMaterial3D.new()
	hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hit_flash_material.albedo_color = Color(1.0, 0.72, 0.62, 0.34)
	hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_flash_material.emission_enabled = true
	hit_flash_material.emission = Color(1.0, 0.12, 0.025)
	hit_flash_material.emission_energy_multiplier = 1.65

func set_enabled(value: bool) -> void:
	if value: get_tree().call_group("session", "forget_target_hit", self)
	enabled = value
	visible = value
	scale = rest_scale
	dying = false
	death_hide_left = 0.0
	for hitbox in $Hitboxes.get_children():
		hitbox.collision_layer = 2 if value else 0
	remaining_health = health

func receive_hit(damage: float, zone: String) -> void:
	if not enabled:
		return
	get_tree().call_group("session", "begin_target_hit", self, zone)
	get_tree().call_group("session", "target_hit", zone, damage)
	flash_left = 0.055
	for mesh in render_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = hit_flash_material
	remaining_health -= damage
	struck.emit(self, zone, damage)
	if not persistent and remaining_health <= 0.0 and enabled:
		get_tree().call_group("session", "complete_target_kill", self)
		enabled = false
		dying = true
		death_hide_left = 0.16
		for hitbox in $Hitboxes.get_children():
			hitbox.collision_layer = 0
		get_tree().call_group("session", "enemy_down", false)

func _process(delta: float) -> void:
	flash_left = maxf(0.0, flash_left - delta)
	$HitIndicator.visible = flash_left > 0.0 and (enabled or dying)
	if flash_left <= 0.0:
		for mesh in render_meshes:
			if is_instance_valid(mesh):
				mesh.material_overlay = null
	if dying:
		death_hide_left = maxf(0.0, death_hide_left - delta)
		var death_progress := 1.0 - death_hide_left / 0.16
		scale = rest_scale * Vector3(1.0 - death_progress * 0.18, maxf(0.03, 1.0 - death_progress), 1.0 - death_progress * 0.18)
		if death_hide_left <= 0.0:
			dying = false
			hide()
