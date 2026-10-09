extends Node3D

@export var duration: float = 0.055
var remaining: float = 0.0
var base_rotation: Vector3
var burst_scale := Vector3.ONE

func _ready() -> void:
	base_rotation = rotation
	hide()

func trigger() -> void:
	remaining = duration
	rotation = base_rotation + Vector3(0.0, 0.0, randf_range(-0.45, 0.45))
	burst_scale = Vector3(randf_range(0.82, 1.12), randf_range(0.82, 1.12), randf_range(0.9, 1.18))
	scale = burst_scale * 0.45
	show()

func _process(delta: float) -> void:
	if remaining <= 0.0:
		hide()
		return
	remaining = maxf(0.0, remaining - delta)
	var progress := 1.0 - remaining / duration
	# Fast hot expansion followed by a short collapse reads as combustion,
	# instead of the old static gold ball blinking on the muzzle.
	var envelope := sin(progress * PI)
	scale = burst_scale * maxf(0.08, envelope) * Vector3(1.0, 1.0, 1.0 + progress * 0.7)
	if remaining <= 0.0:
		hide()
