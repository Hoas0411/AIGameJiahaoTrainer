extends Node3D

const IDLE_CLIP := "Idle_Rifle_2s"
const AIM_CLIP := "Aim_Rifle_2s"

@onready var player: Node = get_parent()
@onready var body: Node3D = $Body

var animator: AnimationPlayer
var current_clip := ""

func _ready() -> void:
	# The body is present for external cameras and shadows. The player's own
	# camera renders layer 1 so the helmet and cloak cannot block the sight.
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = 2
	animator = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play(IDLE_CLIP)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var weapon: Node = player.get("weapon") as Node
	if not is_instance_valid(weapon):
		return
	var desired := AIM_CLIP if float(weapon.get("ads_progress")) > 0.25 and float(weapon.get("reload_time")) <= 0.0 else IDLE_CLIP
	_play(desired)

func _play(clip: String) -> void:
	if animator == null or current_clip == clip or not animator.has_animation(clip):
		return
	var animation := animator.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR
	animator.play(clip, 0.18)
	current_clip = clip
