@tool
extends Node3D

@export_enum("stand", "crouch", "run", "jump", "shoot", "stun", "death", "low_ready", "aim", "crouch_aim") var preview_animation: String = "stand"
@export var face_material: Material = preload("res://resources/materials/face.tres")
@export var crying_material: Material = preload("res://resources/materials/face_crying.tres")
var aim_target := Vector3.ZERO
var crying_time: float = 0.0
var hit_flash_time: float = 0.0
var face_mesh: MeshInstance3D
var render_meshes: Array[MeshInstance3D] = []
var hit_flash_material: StandardMaterial3D
var last_animation: String = ""
var animator: AnimationPlayer
var skeleton: Skeleton3D



# 取得 Blender GLB 内实际导入的骨骼与动画。
func _ready() -> void:
	animator = $Model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = find_skeleton($Model)
	var face := $Model.find_child("Skin_Painted_face_albedo", true, false) as MeshInstance3D
	face_mesh = face
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		render_meshes.append(node as MeshInstance3D)
	hit_flash_material = StandardMaterial3D.new()
	hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hit_flash_material.albedo_color = Color(1.0, 0.72, 0.62, 0.34)
	hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_flash_material.emission_enabled = true
	hit_flash_material.emission = Color(1.0, 0.12, 0.025)
	hit_flash_material.emission_energy_multiplier = 1.65
	if face:
		face.material_override = face_material
	play_pose(preview_animation)



# 一次性查找 Skeleton3D，以支持更换模型后保持命中部位接口。
func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null



# 在编辑器直接选择动画预览，运行时由 NPC 场景控制状态。
func _process(_delta: float) -> void:
	if hit_flash_time > 0.0:
		hit_flash_time = maxf(0.0, hit_flash_time - _delta)
		if hit_flash_time == 0.0:
			for mesh in render_meshes:
				if is_instance_valid(mesh):
					mesh.material_overlay = null
	if crying_time > 0:
		crying_time = maxf(0, crying_time - _delta)
		if crying_time == 0 and face_mesh:
			face_mesh.material_override = face_material
	if Engine.is_editor_hint() and preview_animation != last_animation:
		play_pose(preview_animation)
	if skeleton and has_node("HeldWeapon"):
		var grip: Vector3 = bone_world("Hand_R", Vector3(0, 0.055, 0))
		$HeldWeapon.global_basis = global_basis.scaled(Vector3.ONE * 0.66)
		$HeldWeapon.global_position = grip + global_basis * Vector3(-0.025, 0.085, 0.05)
		if last_animation in ["aim", "shoot", "crouch_aim"] and not aim_target.is_zero_approx():
			$HeldWeapon.look_at(aim_target, Vector3.UP, true)
			$HeldWeapon.scale = Vector3.ONE * 0.66
		elif last_animation == "low_ready":
			$HeldWeapon.rotate_object_local(Vector3.RIGHT, 0.35)
		$ShotFlash.global_position = $HeldWeapon.to_global(Vector3(0, 0.015, 0.65))



# 骨骼动画使用 AnimationPlayer 中的持久化轨道，可在 Godot 动画面板修改。
func play_pose(animation_name: String) -> void:
	if animator == null or last_animation == animation_name:
		return
	for key in animator.get_animation_list():
		if key == animation_name or key.ends_with("/" + animation_name) or key.ends_with("|" + animation_name):
			var animation := animator.get_animation(key)
			animation.loop_mode = Animation.LOOP_NONE if animation_name == "death" else Animation.LOOP_LINEAR
			animator.play(key, 0.12)
			last_animation = animation_name
			return



# 停止姿态播放器，保留完整导入场景。
func stop_pose() -> void:
	if animator:
		animator.stop()



# 命中区域通过真实骨骼全局位置跟随站、蹲、跳的变化。
func bone_world(bone_name: String, offset: Vector3 = Vector3.ZERO) -> Vector3:
	if skeleton:
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			return skeleton.global_transform * (skeleton.get_bone_global_pose(index) * offset)
	return global_position + offset



# 每个 NPC 独立切换哭脸，短时间重复命中会延长表情。
func show_hurt_face() -> void:
	crying_time = 2.5
	hit_flash_time = 0.055
	for mesh in render_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = hit_flash_material
	if face_mesh:
		face_mesh.material_override = crying_material
