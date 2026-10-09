extends MeshInstance3D

@export var lifetime: float = 0.085
var remaining: float = 0.085



# 只显示弹丸真实经过的路径，视觉余迹不参与伤害。
func setup(start: Vector3, finish: Vector3) -> void:
	var distance := start.distance_to(finish)
	global_position = (start + finish) * 0.5
	if distance > 0.001:
		look_at(finish)
	scale = Vector3(1, 1, maxf(distance, 0.001))
	remaining = lifetime



# 有限寿命自动清理，避免全图交火不断累积节点。
func _process(delta: float) -> void:
	remaining -= delta
	transparency = clampf(1.0 - remaining / lifetime, 0, 1)
	if remaining <= 0:
		queue_free()
