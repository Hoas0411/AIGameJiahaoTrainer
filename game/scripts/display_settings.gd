extends Node

@export_enum("16:9", "4:3 拉伸") var mode: int = 0
var world_view: SubViewport
var world_camera: Camera3D
var world_canvas: CanvasLayer
var world_picture: TextureRect
var source_camera: Camera3D
var source_cull_mask: int = 0

func _ready() -> void:
	process_priority=200



# 16:9 保持比例；4:3 使用窄视口并横向填满窗口，鼠标仍使用原始计数。
func apply_mode(value: int) -> void:
	mode = clampi(value, 0, 1)
	var window := get_window()
	# Canvas UI is rendered at window pixels, not enlarged from a 900p bitmap.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = Vector2i(1600, 900) if mode == 0 else Vector2i(1200, 900)
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if mode == 0 else Window.CONTENT_SCALE_ASPECT_IGNORE
	get_parent().get_node("Root").scale = Vector2(1.0 if mode == 0 else 0.75, 1.0)
	if mode==0 and is_instance_valid(source_camera):
		source_camera.cull_mask=source_cull_mask
	if world_canvas!=null:world_canvas.visible=mode==1
	if world_view!=null:world_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if mode==1 else SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	if mode!=1:return
	var game: Node=get_tree().current_scene
	if game==null or game.get("player")==null:return
	var current: Camera3D=game.player.camera
	if current!=source_camera:
		if is_instance_valid(source_camera):source_camera.cull_mask=source_cull_mask
		source_camera=current
		source_cull_mask=current.cull_mask & ~(1<<19)
	if world_view==null:
		world_view=SubViewport.new()
		world_view.name="StretchedWorld"
		world_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		world_view.msaa_3d=Viewport.MSAA_2X
		add_child(world_view)
		world_camera=Camera3D.new()
		world_view.add_child(world_camera)
		world_camera.current=true
		world_canvas=CanvasLayer.new()
		world_canvas.layer=-1
		add_child(world_canvas)
		world_picture=TextureRect.new()
		world_picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		world_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		world_picture.texture=world_view.get_texture()
		world_canvas.add_child(world_picture)
	# Preserve the existing 4:3 world projection; only that 3D image is stretched.
	# UI remains on the native-resolution root canvas, with unchanged raw input.
	world_view.world_3d=source_camera.get_world_3d()
	var pixels: Vector2i=get_window().size
	world_view.size=Vector2i(roundi(pixels.y*4.0/3.0),pixels.y)
	world_picture.size=get_viewport().get_visible_rect().size
	world_camera.global_transform=source_camera.global_transform
	world_camera.fov=source_camera.fov
	world_camera.keep_aspect=source_camera.keep_aspect
	world_camera.near=source_camera.near
	world_camera.far=source_camera.far
	world_camera.cull_mask=source_cull_mask
	source_camera.cull_mask=0

func _exit_tree() -> void:
	if is_instance_valid(source_camera):source_camera.cull_mask=source_cull_mask
