extends RefCounted

# Presentation only: never writes character velocity, collisions, aim or FOV.
# Camera landing is fitted to the 2026-09-26 video; absolute metre scale and
# ADS attenuation remain trainer mappings, not certified original physics.
var motion: MotionProfile = preload("res://resources/motion_baseline.tres")
var phase := 0.0
var weight := 0.0
var weight_velocity := 0.0
var camera_y := 0.0
var camera_velocity := 0.0
var gun_y := 0.0
var gun_velocity := 0.0
var gun_offset := Vector3.ZERO
var landing_count := 0

static func spring(value: float, velocity: float, target: float, omega: float, delta: float) -> Vector2:
	# Exact critically damped solution for a constant target over this interval.
	# No Euler overshoot and no frame-rate-dependent lerp coefficients.
	var error := value - target
	var coupling := velocity + omega * error
	var decay := exp(-omega * delta)
	return Vector2(target + (error + coupling * delta) * decay,
		(velocity - omega * coupling * delta) * decay)

static func damped_spring(value: float, velocity: float, omega: float, damping: float, delta: float) -> Vector2:
	# Exact underdamped solution: continuous displacement/velocity, one small
	# rebound as measured in the footage, without frame-dependent Euler steps.
	omega = maxf(0.1, omega)
	damping = clampf(damping, 0.05, 1.0)
	if damping >= 0.999:
		return spring(value, velocity, 0.0, omega, delta)
	var decay_rate := damping * omega
	var frequency := omega * sqrt(1.0 - damping * damping)
	var coupling := (velocity + decay_rate * value) / frequency
	var cosine := cos(frequency * delta)
	var sine := sin(frequency * delta)
	var oscillation := value * cosine + coupling * sine
	var decay := exp(-decay_rate * delta)
	return Vector2(decay * oscillation,
		decay * (frequency * (-value * sine + coupling * cosine) - decay_rate * oscillation))

func reset() -> void:
	phase = 0.0
	weight = 0.0
	weight_velocity = 0.0
	camera_y = 0.0
	camera_velocity = 0.0
	gun_y = 0.0
	gun_velocity = 0.0
	gun_offset = Vector3.ZERO
	landing_count = 0

func land(downward_speed: float) -> void:
	if downward_speed < 1.5:
		return
	landing_count += 1
	# The eye retains downward velocity when the collision body stops. Original
	# hip-fire footage reaches its compression minimum about 80 ms later.
	camera_velocity = maxf(-motion.landing_camera_speed_limit, camera_velocity - downward_speed * motion.landing_camera_impulse)
	gun_velocity = maxf(-1.05, gun_velocity - downward_speed * 0.16)

func advance(delta: float, speed: float, grounded: bool, crouched: bool) -> void:
	var ground_speed := speed if grounded else 0.0
	var reference := 2.1 if crouched else 3.29
	var target := clampf(ground_speed / reference, 0.0, 1.0)
	var stance_weight := 0.55 if crouched else 1.0
	var envelope := spring(weight, weight_velocity, target * stance_weight, 22.0, delta)
	weight = envelope.x
	weight_velocity = envelope.y
	var run_blend := clampf((ground_speed - 3.29) / (5.9 - 3.29), 0.0, 1.0)
	var steps_per_second := (1.5 if crouched else lerpf(2.0, 2.8, run_blend)) * target
	# One lateral cycle per two steps; the vertical channel has one cycle/step.
	phase = fmod(phase + PI * steps_per_second * delta, TAU)
	var camera_state := damped_spring(camera_y, camera_velocity, motion.landing_camera_omega, motion.landing_camera_damping, delta)
	camera_y = camera_state.x
	camera_velocity = camera_state.y
	var gun_state := spring(gun_y, gun_velocity, 0.0, 15.0, delta)
	gun_y = gun_state.x
	gun_velocity = gun_state.y
	gun_offset = Vector3(sin(phase) * 0.005, cos(phase * 2.0) * 0.0035, 0.0) * weight
	gun_offset.y += gun_y
