extends Node3D

@export_category("威龙 / 动力推进")
@export var dash_speed: float = 16.0
@export var dash_duration: float = 0.32
@export var dash_cooldown: float = 20.0
@export var elimination_refund: float = 0.9
@export var soldier_refund: float = 0.52
@export_category("磁吸炸弹 / C4")
@export var charge_capacity: int = 2
@export var charge_replenish: float = 25.0
@export var throw_speed: float = 16.0
@export_category("虎蹲炮")
@export var thumper_cooldown: float = 35.0
var motion: MotionProfile = preload("res://resources/motion_baseline.tres")
var current_dash_speed: float = 16.0
var passive_remaining: float = 0.0
var passive_cd: float = 0.0
var dash_start := Vector3.ZERO
var measured_dash_distance: float = 0.0
var was_dashing: bool = false
var dash_clock: float = 0.0
var measured_dash_seconds: float = 0.0
var dash_remaining: float = 0.0
var dash_cd: float = 0.0
var charge_cd: float = 0.0
var thumper_cd: float = 0.0
var charges: int = 2
var dash_vector := Vector3.ZERO
var cast_time: float = 0.0
var cast_kind: String = ""
var held_kind: String = ""
var effect_time: float = 0.0
const CHARGE = preload("res://scenes/abilities/magnetic_charge.tscn")
const THUMPER = preload("res://scenes/abilities/thumper_shell.tscn")
@onready var player: CharacterBody3D = get_parent()



# 在关卡开始时恢复全部技能，训练用补给计时与正式配装参数分开保存。
func reset() -> void:
	dash_speed = motion.dash_distance / motion.dash_seconds
	dash_duration = motion.dash_seconds
	dash_cooldown = motion.dash_cooldown
	elimination_refund = motion.operator_refund
	soldier_refund = motion.soldier_refund
	charge_capacity = motion.charge_capacity
	charge_replenish = motion.charge_replenish
	throw_speed = motion.charge_throw_speed
	thumper_cooldown = motion.thumper_cooldown
	passive_remaining = 0
	passive_cd = 0
	was_dashing = false
	dash_remaining = 0.0
	dash_cd = 0.0
	charge_cd = 0.0
	thumper_cd = 0.0
	charges = charge_capacity
	cast_time = 0.0
	held_kind = ""
	$AnimationPlayer.stop()
	effect_time = 0.0
	$JetSound.stop()



# 使用原生输入动作，支持地面和空中的八方向喷气。
func _unhandled_input(event: InputEvent) -> void:
	if not player.active or player.controls_blocked or not player.combat_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("dash"):
		activate_dash()
	elif event.is_action_pressed("charge"):
		prepare("charge")
	elif event.is_action_pressed("thumper"):
		prepare("thumper")
	elif event.is_action_pressed("fire") and held_kind != "":
		cast(held_kind)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("aim") and held_kind != "":
		held_kind = ""
		get_viewport().set_input_as_handled()



# 更新冷却、投掷前摇和显示在第一人称中的技能道具。
func _process(delta: float) -> void:
	if not player.active:
		$CastVisual.hide()
		return
	passive_remaining = maxf(0, passive_remaining - delta)
	passive_cd = maxf(0, passive_cd - delta)
	dash_cd = maxf(0, dash_cd - delta)
	thumper_cd = maxf(0, thumper_cd - delta)
	effect_time = maxf(0, effect_time - delta)
	if charges < charge_capacity:
		charge_cd -= delta
		if charge_cd <= 0:
			charges += 1
			charge_cd = charge_replenish
	if cast_time > 0:
		cast_time -= delta
		if cast_time <= 0:
			launch_gadget()
	$CastVisual.visible = cast_time > 0 or held_kind != ""
	if $CastVisual.visible:
		$CastVisual.global_transform = player.camera.global_transform
		$CastVisual.translate_object_local(Vector3(-0.20, -0.16 + sin(cast_time * 9.0) * 0.05, -0.48))
		$CastVisual/Charge.visible = (held_kind if held_kind != "" else cast_kind) == "charge"
		$CastVisual/Shell.visible = not $CastVisual/Charge.visible



# 激活推进；真实 CharacterBody3D 碰撞阻止穿墙。
func activate_dash() -> bool:
	if dash_cd > 0 or not player.active:
		return false
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() < 0.1:
		input_dir = Vector2(0, -1)
	dash_vector = (player.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	current_dash_speed = dash_speed * (motion.lateral_dash_multiplier if absf(input_dir.x) > 0.1 else 1.0)
	dash_start = player.global_position
	dash_clock = 0
	was_dashing = true
	trigger_passive()
	dash_remaining = dash_duration
	dash_cd = dash_cooldown
	effect_time = 0.5
	player.velocity.y = maxf(player.velocity.y, 1.1)
	$JetSound.play()
	get_tree().call_group("session", "ability_used", "动力推进")
	return true



# 扣除道具和冷却后播放前摇，避免重复输入制造无限弹体。
func cast(kind: String) -> bool:
	if cast_time > 0 or not player.active:
		return false
	if kind == "charge":
		if charges <= 0:
			return false
		charges -= 1
		charge_cd = charge_replenish
	else:
		if thumper_cd > 0:
			return false
		thumper_cd = thumper_cooldown
	held_kind = ""
	cast_kind = kind
	cast_time = motion.charge_windup if kind == "charge" else motion.thumper_windup
	$AnimationPlayer.play("charge_throw" if kind == "charge" else "thumper_launch")
	player.weapon.aiming = false
	$CastSound.play()
	return true



# 在抛出帧实例化独立技能场景，继承奔跑与跳跃速度。
func launch_gadget() -> void:
	var gadget: Node3D = (CHARGE if cast_kind == "charge" else THUMPER).instantiate()
	gadget.fuse_seconds = motion.charge_fuse if cast_kind == "charge" else motion.thumper_fuse
	gadget.blast_radius = motion.charge_radius if cast_kind == "charge" else motion.thumper_radius
	gadget.max_damage = motion.charge_damage
	gadget.stun_seconds = motion.thumper_stun
	gadget.gravity = motion.projectile_gravity
	gadget.restitution = motion.restitution
	trigger_passive()
	get_tree().current_scene.add_child(gadget)
	var origin: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	gadget.global_position = origin + forward * 0.28
	gadget.velocity = forward * (throw_speed if cast_kind == "charge" else motion.thumper_throw_speed) + player.velocity * motion.throw_inheritance + Vector3.UP * (2.0 if cast_kind == "charge" else 0.3)
	gadget.shooter = player
	get_tree().call_group("session", "ability_used", "磁吸炸弹" if cast_kind == "charge" else "虎蹲炮")



# 击倒按基础冷却返还，不能把剩余冷却乘百分比，形成突入、击倒、再转点的练习循环。
func refund_dash(operator_target: bool = true) -> void:
	var old_cd: float = dash_cd
	dash_cd = maxf(0.0, dash_cd - dash_cooldown * (elimination_refund if operator_target else soldier_refund))
	if old_cd > 0:
		get_tree().call_group("session", "ability_feedback", "喷气就绪 / 击倒刷新" if dash_cd <= 0 else "击倒返还冷却 · 剩余 %.1fs" % dash_cd)



# 技能键只拿出道具，不扣次数也不开始引信；再次按键收起。
func prepare(kind: String) -> bool:
	if cast_time > 0 or not player.active:
		return false
	if (kind == "charge" and charges <= 0) or (kind == "thumper" and thumper_cd > 0):
		return false
	held_kind = "" if held_kind == kind else kind
	$AnimationPlayer.stop()
	$CastVisual/Charge.position = Vector3.ZERO
	$CastVisual/Charge.rotation = Vector3.ZERO
	$CastVisual/Shell.position = Vector3(0.5, 0, 0)
	$CastVisual/Shell.rotation = Vector3(0, PI, 0)
	player.weapon.aiming = false
	return true

func trigger_passive() -> void:
	if passive_cd > 0:
		return
	passive_remaining = motion.passive_seconds
	passive_cd = motion.passive_seconds + motion.passive_cooldown
