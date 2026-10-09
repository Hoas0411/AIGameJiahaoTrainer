extends Node3D

var radius: float = 5.0
var control_only: bool = false
var life: float = 0.0



# 原生粒子、环状冲击波、灯光和声音都保留在独立爆炸场景。
func _ready() -> void:
	add_to_group("projectiles")
	if control_only:
		$Ring.material_override.set_shader_parameter("tint", Color(0.25,0.75,1.0))
		$Sound.stream = preload("res://assets/audio/thumper.wav")
	for particles in $LayeredParticles.get_children():
		if control_only and particles.name == "Fire": continue
		if control_only and particles.name == "Sparks":
			particles.process_material = particles.process_material.duplicate(true)
			var ramp := Gradient.new()
			ramp.colors = PackedColorArray([Color(0.45,0.85,1.0,0.85),Color(0.15,0.5,1.0,0.0)])
			var texture := GradientTexture1D.new()
			texture.gradient = ramp
			particles.process_material.color_ramp = texture
		particles.emitting = true
	$Sound.play()



# 冲击波快速扩张后渐隐；不同技能使用不同色彩提示。
func _process(delta: float) -> void:
	life += delta
	$Ring.scale = Vector3.ONE * maxf(0.01, (1.0-exp(-life*9.0)) * radius)
	$Ring.material_override.set_shader_parameter("opacity", maxf(0.0, (0.12 if control_only else 0.045) * (1.0-life/0.32)))
	$Flash.light_energy = 3.2 * exp(-life*17.0)
	$Flash.light_color = Color(0.3, 0.8, 1.0) if control_only else Color(1.0, 0.45, 0.12)
	if life > 2.5:
		queue_free()
