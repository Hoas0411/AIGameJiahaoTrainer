class_name MotionProfile
extends Resource

# Units: metres, seconds. Defaults are trainer baselines, not certified game data.
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.1
@export var ads_speed_multiplier: float = 0.65
@export var equipment_speed_multiplier: float = 1.0
@export var acceleration: float = 30.0
@export var braking: float = 30.0
@export var air_acceleration: float = 30.0
# Video candidate: 0.62 standing-eye heights and 0.35 s to apex. Metre scale
# maps to our 1.7 m eye; it is not a certified extraction of original physics.
@export var jump_height: float = 1.06
@export var jump_apex_seconds: float = 0.352
@export var landing_camera_omega: float = 14.8
@export var landing_camera_damping: float = 0.5
@export var landing_camera_impulse: float = 1.04
@export var landing_camera_speed_limit: float = 8.0
@export var stand_height: float = 1.85
@export var crouch_height: float = 1.15
@export var stand_eye: float = 1.7
@export var crouch_eye: float = 1.03
@export var lean_angle_degrees: float = 6.0
@export var lean_seconds: float = 0.65
@export var lean_curve_strength: float = 5.0
@export var lean_distance: float = 0.22
@export var lean_neck_pivot: float = 0.24
@export var lean_drop: float = 0.018
@export var lean_viewmodel_counter_roll: float = 1.47
@export var lean_ads_viewmodel_counter_roll: float = 3.0
@export var lean_viewmodel_drop: float = 0.008
@export var lean_collision_margin: float = 0.03
@export var dash_distance: float = 5.12
@export var dash_seconds: float = 0.32
@export var lateral_dash_multiplier: float = 1.0
@export var dash_cooldown: float = 20.0
@export var operator_refund: float = 0.9
@export var soldier_refund: float = 0.52
@export var passive_speed_multiplier: float = 1.15
@export var passive_seconds: float = 2.0
@export var passive_cooldown: float = 8.0
@export var passive_fall_threshold: float = 3.0
@export var fall_damage_reduction: float = 0.5
@export var fall_damage_threshold: float = 4.0
@export var fall_damage_per_metre: float = 15.0
@export var charge_capacity: int = 2
@export var charge_replenish: float = 25.0
@export var charge_throw_speed: float = 16.0
@export var charge_windup: float = 0.75
@export var charge_fuse: float = 3.0
@export var charge_radius: float = 5.0
@export var charge_damage: float = 110.0
@export var thumper_cooldown: float = 35.0
@export var thumper_throw_speed: float = 32.0
@export var thumper_windup: float = 0.65
@export var thumper_fuse: float = 3.0
@export var thumper_radius: float = 6.0
@export var thumper_stun: float = 4.0
@export var projectile_gravity: float = 12.0
@export var throw_inheritance: float = 0.65
@export var restitution: float = 0.38

func jump_speed() -> float:
	return 2.0 * jump_height / maxf(0.1, jump_apex_seconds)

func gravity_value() -> float:
	return 2.0 * jump_height / pow(maxf(0.1, jump_apex_seconds), 2)
