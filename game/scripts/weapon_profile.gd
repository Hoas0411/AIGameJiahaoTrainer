@tool
extends Resource
class_name WeaponProfile

@export var display_name: String = "AWM"
@export_multiline var calibration_note: String = "训练原型参数；未通过三角洲指定版本实测校准。"
@export var damage: float = 100.0
@export var head_multiplier: float = 2.0
@export var limb_multiplier: float = 0.65
@export var rpm: float = 35.0
@export var magazine_size: int = 5
@export var reload_seconds: float = 2.8
@export var muzzle_velocity: float = 900.0
@export var bullet_gravity: float = 9.8
@export var effective_range: float = 100.0
@export var distant_damage_multiplier: float = 0.6
@export var recoil_degrees: float = 2.0
@export var hip_spread_degrees: float = 1.6
@export var laser_spread_degrees: float = 0.18
@export var ads_spread_degrees: float = 0.01
@export var ads_seconds: float = 0.28
@export var scope_fov: float = 20.0
@export var scope_zoom: float = 3.0
@export var alternate_zoom: float = 7.0
@export var laser_zoom: float = 1.12
@export var automatic: bool = false
@export var movement_spread_multiplier: float = 1.35
@export var jump_spread_multiplier: float = 1.8
@export var crouch_spread_multiplier: float = 0.85
@export var sprint_to_fire_seconds: float = 0.18
@export var horizontal_recoil_ratio: float = 0.18

# Per-weapon calibration; defaults retain the existing rifle behaviour.
@export var abdomen_multiplier: float = 1.0
@export var empty_reload_seconds: float = 0.0
@export var recoil_control: int = 0
@export var handling: int = 0
@export var stability: int = 0
@export var hip_accuracy: int = 0
@export var recoil_scale: float = 1.0
@export var firing_weapon_stability: float = 1.0
@export var firing_camera_stability: float = 1.0
@export var moving_stability: float = 1.0
@export var sway_degrees: float = 0.0
@export var breath_seconds: float = 0.0
@export var breath_recoil_scale: float = 1.0
@export var flinch_scale: float = 1.0
@export var hip_max_spread_degrees: float = 0.0
@export var gunshot_audible_distance: float = 0.0
@export var stow_seconds: float = 0.0
@export var draw_seconds: float = 0.18
@export var walk_move_scale: float = 1.0
@export var sprint_move_scale: float = 1.0
@export var ads_move_scale: float = 1.0
@export var sight_switch_seconds: float = 0.20
@export var weapon_id: String = ""
@export var armor_damage: float = 0.0
@export var falloff_distances: PackedFloat32Array = PackedFloat32Array()
@export var falloff_multipliers: PackedFloat32Array = PackedFloat32Array()
@export var supports_single_fire: bool = false
@export var persistent_recoil: bool = false
@export var walk_metres_per_second: float = 0.0
@export var sprint_metres_per_second: float = 0.0
@export var ads_metres_per_second: float = 0.0
@export var spread_growth_degrees: float = 0.0
@export var spread_recovery_degrees: float = 0.0

func distance_multiplier(distance: float) -> float:
	if falloff_distances.is_empty():
		return distant_damage_multiplier if distance > effective_range else 1.0
	var result: float = 1.0
	for index in mini(falloff_distances.size(), falloff_multipliers.size()):
		if distance > falloff_distances[index]:
			result = falloff_multipliers[index]
	return result

func damage_at(zone: String, distance: float) -> float:
	var multiplier: float = 1.0
	match zone:
		"head": multiplier = head_multiplier
		"abdomen": multiplier = abdomen_multiplier
		"arm", "limb", "leg": multiplier = limb_multiplier
	return damage * multiplier * distance_multiplier(distance)

func shot_interval() -> float:
	return 60.0 / maxf(1.0, rpm)

func reload_duration(empty: bool) -> float:
	return empty_reload_seconds if empty and empty_reload_seconds > 0.0 else reload_seconds
