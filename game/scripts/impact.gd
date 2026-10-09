extends Node3D

const LIFETIME := 0.055
const PARTICLE_LIFETIME := 0.40
var remaining := PARTICLE_LIFETIME
var character_hit := false

func setup(surface_normal: Vector3, is_character_hit: bool) -> void:
	character_hit = is_character_hit
	# The source shows brief armor sparks and a thin puff, without an
	# expanding red ring or a luminous four-ray explosion.
	$Core.hide()
	$Ring.hide()
	$Rays.hide()
	if not surface_normal.is_zero_approx():
		basis = Basis(Quaternion(Vector3.FORWARD, surface_normal.normalized()))
	$Light.light_color = Color(1.0,0.72,0.36)
	$ImpactParticles/Sparks.amount = 7 if character_hit else 5
	$ImpactParticles/Dust.amount = 3 if character_hit else 5

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var progress := clampf((PARTICLE_LIFETIME - remaining) / LIFETIME, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.42, 1.0, progress)
	$Light.light_energy = 0.22 * fade
	if remaining <= 0.0:
		queue_free()
