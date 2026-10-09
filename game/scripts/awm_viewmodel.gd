extends Node

const VIEW_LAYER := 1 << 19
const MASK := preload("res://assets/shaders/awm_viewmodel_mask.gdshader")
var weapon: Node3D
var player: CharacterBody3D
var viewport: SubViewport
var camera: Camera3D
var canvas: CanvasLayer
var picture: TextureRect
var aperture: ShaderMaterial
var meshes: Array[GeometryInstance3D] = []
var original_layers: Array[int] = []
var ocular: Node3D
var muzzle: Node3D
var emitter: Node3D
var enabled := false

func _ready() -> void:
	process_priority=100
	call_deferred("setup")

func setup() -> void:
	weapon=get_parent()
	player=weapon.player
	for branch: Node in [weapon.get_node("Model/AWM"),weapon.get_node("Model/AWMArms"),weapon.get_node("MuzzleFlash")]:
		if branch is GeometryInstance3D:
			meshes.append(branch)
		for mesh in branch.find_children("*","GeometryInstance3D",true,false):meshes.append(mesh)
	for mesh in meshes:original_layers.append(mesh.layers)
	ocular=weapon.get_node("Model/AWM").find_child("OcularSocket",true,false)
	muzzle=weapon.get_node("Model/AWM").find_child("MuzzleSocket",true,false)
	emitter=weapon.get_node("Model/AWM").find_child("LaserSocket",true,false)
	viewport=SubViewport.new()
	viewport.name="WeaponViewport"
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.world_3d=weapon.get_world_3d()
	add_child(viewport)
	camera=Camera3D.new()
	camera.cull_mask=VIEW_LAYER
	camera.near=0.003
	camera.far=8.0
	camera.keep_aspect=player.camera.keep_aspect
	var lighting:=Environment.new()
	lighting.background_mode=Environment.BG_CLEAR_COLOR
	lighting.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color=Color(.65,.72,.8)
	lighting.ambient_light_energy=.7
	camera.environment=lighting
	viewport.add_child(camera)
	camera.current=true
	# World lights may only affect layer 1. Give the isolated weapon pass explicit
	# matching key/fill lighting, restricted to its own render layer.
	for settings: Vector3 in [Vector3(-32,-35,1.1),Vector3(12,145,.45)]:
		var light:=DirectionalLight3D.new()
		light.layers=VIEW_LAYER
		light.light_cull_mask=VIEW_LAYER
		light.light_energy=settings.z
		light.light_color=Color(.92,.96,1.0)
		light.rotation_degrees=Vector3(settings.x,settings.y,0)
		camera.add_child(light)
	player.camera.cull_mask&=~VIEW_LAYER
	canvas=CanvasLayer.new()
	canvas.layer=0
	add_child(canvas)
	picture=TextureRect.new()
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.texture=viewport.get_texture()
	aperture=ShaderMaterial.new()
	aperture.shader=MASK
	picture.material=aperture
	canvas.add_child(picture)

func _process(_delta: float) -> void:
	if camera==null or not is_instance_valid(player):return
	var active: bool=player.active and not weapon.profile.automatic
	if active!=enabled:
		enabled=active
		for i in meshes.size():meshes[i].layers=VIEW_LAYER if active else original_layers[i]
	canvas.visible=active
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:return
	var logical: Vector2=weapon.get_viewport().get_visible_rect().size
	var pixels: Vector2i=get_window().size
	var session: Node=get_tree().current_scene
	if session!=null and session.get("ui")!=null and session.ui.get_node("DisplaySettings").mode==1:
		pixels.x=roundi(pixels.y*4.0/3.0)
	if viewport.size!=pixels:viewport.size=pixels
	picture.size=logical
	camera.global_transform=player.camera.global_transform
	var scoped: float=smoothstep(0.0,1.0,weapon.ads_progress)*(1.0-smoothstep(0.0,1.0,weapon.sight_blend))
	# Match the measured 824px clear diameter through projection, without stretching the rifle.
	camera.fov=lerpf(player.camera.fov,10.07,scoped)
	weapon.get_node("Muzzle").global_position=muzzle.global_position
	weapon.get_node("LaserOrigin").global_position=emitter.global_position
	weapon.get_node("MuzzleFlash").global_position=muzzle.global_position
	var weight: float=smoothstep(.82,.98,weapon.ads_progress)*(1.0-smoothstep(.02,.16,weapon.sight_blend))
	var center: Vector2=camera.unproject_position(ocular.global_position)
	# AWM is rendered by this second camera. Its old shared ViewmodelLean roll
	# rotated the ocular around the camera origin, dropping the sight to 62% of
	# screen height at either endpoint. Translate the weapon pass so the actual
	# ocular socket remains on the aiming axis; the rifle body may roll around it.
	if weight>.001:
		var depth: float=(ocular.global_position-camera.global_position).dot(-camera.global_basis.z)
		if depth>camera.near:
			var desired_world: Vector3=camera.project_position(Vector2(pixels)*.5,depth)
			var correction_world: Vector3=(desired_world-ocular.global_position)*weight
			player.viewmodel_lean.position+=player.camera.global_basis.inverse()*correction_world
			center=camera.unproject_position(ocular.global_position)
	var radius_x: float=absf(camera.unproject_position(ocular.global_position+camera.global_basis.x*.0193).x-center.x)
	var radius_y: float=absf(camera.unproject_position(ocular.global_position+camera.global_basis.y*.0193).y-center.y)
	weapon.optic_center=center/Vector2(pixels)
	weapon.optic_radius=Vector2(radius_x,radius_y)/Vector2(pixels)
	aperture.set_shader_parameter("scope_blend",weight)
	aperture.set_shader_parameter("aperture_center",weapon.optic_center)
	aperture.set_shader_parameter("aperture_radius",weapon.optic_radius)
	weapon.update_laser()

func _exit_tree() -> void:
	if is_instance_valid(player) and is_instance_valid(player.camera):player.camera.cull_mask|=VIEW_LAYER
