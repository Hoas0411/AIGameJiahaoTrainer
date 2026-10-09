extends Node
## Local presentation adapter; remote AI is not required for training feedback.
var policy := preload("res://scripts/companion_reaction_policy.gd").new()
var epoch := 0
var clock := 0.0
var priority := 0
var remaining := 0.0
@onready var actor: Node = get_parent()
@onready var game: Node = actor.get_parent()

func _ready() -> void:
	add_to_group("companion_reaction_observers")

func current_epoch() -> int:
	var level: Variant = game.get("level")
	return level.get_instance_id() if is_instance_valid(level) else 0

func available() -> bool:
	return actor.visible and game.get_node("Companion").enabled

func sync_session() -> void:
	var latest := current_epoch()
	if latest != epoch:
		epoch = latest
		policy.reset()
		remaining = 0
		priority = 0
		actor.set_expression(0)

func _process(delta: float) -> void:
	clock += delta
	sync_session()
	if not available():
		policy.reset()
		remaining = 0
		priority = 0
		return
	if remaining > 0:
		remaining = maxf(0, remaining-delta)
		if remaining == 0:
			priority = 0
			actor.set_expression(0)

func present(result: Dictionary) -> void:
	if result.is_empty() or not available(): return
	if remaining > 0 and int(result.priority) < priority: return
	priority = int(result.priority)
	remaining = float(result.duration)
	actor.set_expression(int(result.face))
	actor.reaction = 1.0
	actor.emotion_response.emit(int(result.face), str(result.text))

func observe_shot_result(hit: bool, shot_epoch: int) -> void:
	sync_session()
	if not available() or game.get("running") != true or epoch != shot_epoch: return
	present(policy.shot(hit,clock))

func observe_reaction_sample(milliseconds: float, shot_epoch: int) -> void:
	sync_session()
	if not available() or game.get("running") != true or epoch != shot_epoch: return
	present(policy.fast_reaction(milliseconds,clock))

func on_hurt() -> void:
	present(policy.hurt(clock))

func on_hug() -> void:
	present(policy.hug(clock))
