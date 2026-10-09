extends Node
## One world environment and one sun rig per loaded level. Presentation only.

const GRAIN = preload("res://resources/presentation/surface_grain.png")
const NORMAL_GRAIN = preload("res://resources/presentation/surface_normal.png")
var game: Node
var active_id: int = -1
var default_environment: Environment
var presentation_sky: Sky
var materials: Dictionary = {}

func _ready() -> void:
	game = get_parent()
	default_environment = game.get_node("WorldEnvironment").environment
	presentation_sky = _create_sky()
	process_priority = 90
	if "--visual-baseline" in OS.get_cmdline_user_args(): set_process(false)
	if "--visual-release-check" in OS.get_cmdline_user_args():
		game.call_deferred("add_child", load("res://scripts/tests/visual_quality_capture.gd").new())

func _process(_delta: float) -> void:
	var level: Node = game.level if is_instance_valid(game.level) else null
	var current_id: int = level.get_instance_id() if level != null else 0
	if current_id == active_id: return
	active_id = current_id
	_apply_level(level)

func _apply_level(level: Node) -> void:
	# Approved authored levels retain their sky, lighting and material settings.
	if level != null and level.get_meta("preserve_authored_visuals", false):
		var authored_world: WorldEnvironment = level.get_node("WorldEnvironment")
		game.get_node("WorldEnvironment").environment = authored_world.environment
		authored_world.environment = null
		game.get_node("Sun").visible = false
		game.get_node("Fill").visible = false
		return
	# Reuse the original environment instead of replacing rendered resources on switch.
	var env: Environment = default_environment
	var is_lobby := level != null and level.scene_file_path.ends_with("circular_lobby.tscn")
	var own_sun := level != null and level.has_node("Sun")
	if level != null:
		for world in level.find_children("*", "WorldEnvironment", true, false):
			# The main WorldEnvironment owns the active resource. No competing registrations.
			world.environment = null
	game.get_node("Sun").visible = not own_sun
	game.get_node("Fill").visible = not own_sun
	var sun: DirectionalLight3D = level.get_node("Sun") if own_sun else game.get_node("Sun")
	sun.light_energy = 0.55 if is_lobby else 1.35
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_angular_distance = 0.55
	sun.directional_shadow_max_distance = 85.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 1.2
	if own_sun and level.has_node("Fill"):
		level.get_node("Fill").light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.67, 0.76, 0.84)
	env.ambient_light_energy = 0.68 if is_lobby else 0.62
	env.sky = presentation_sky
	env.background_mode = Environment.BG_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ssao_enabled = true
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.25
	env.ssao_light_affect = 0.15
	env.ssil_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.fog_enabled = not is_lobby
	env.fog_light_color = Color(0.52, 0.61, 0.68)
	env.fog_density = 0.0007
	game.get_node("WorldEnvironment").environment = env
	if level == null: return
	if is_lobby:
		for light in level.find_children("*", "OmniLight3D", true, false):
			if str(light.name).begins_with("CeilingFill"):
				light.light_energy = 2.2
				light.light_color = Color(0.84, 0.91, 1.0)
				light.light_specular = 0.45
			elif light.name == "CentralFill":
				light.light_energy = 3.0
				light.light_color = Color(1.0, 0.94, 0.83)
		_add_lobby_lights(level)
	_polish_architecture(level)
	print("VISUAL_QUALITY level=",level.name," renderer=",RenderingServer.get_current_rendering_method()," own_sun=",own_sun)

func _create_sky() -> Sky:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.28, 0.41)
	sky_mat.sky_horizon_color = Color(0.72, 0.76, 0.77)
	sky_mat.ground_bottom_color = Color(0.12, 0.14, 0.17)
	sky_mat.ground_horizon_color = Color(0.43, 0.47, 0.50)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	return sky

func _add_lobby_lights(level: Node) -> void:
	var rig := Node3D.new()
	rig.name = "PresentationLighting"
	level.add_child(rig)
	var fill := DirectionalLight3D.new()
	rig.add_child(fill)
	fill.rotation_degrees = Vector3(-30,150,0)
	fill.light_color = Color(0.76,0.86,1.0)
	fill.light_energy = 0.5
	fill.light_specular = 0.65
	fill.shadow_enabled = false
	for i in 4:
		var angle: float = TAU * float(i) / 4.0 + PI / 4.0
		var spot := SpotLight3D.new()
		rig.add_child(spot)
		spot.position = Vector3(sin(angle)*8.0, 7.0, cos(angle)*8.0)
		spot.rotation_degrees.x = -90.0
		spot.light_color = Color(1.0, 0.92, 0.78)
		spot.light_energy = 4.0
		spot.spot_range = 13.0
		spot.spot_angle = 48.0
		spot.spot_attenuation = 1.25
		spot.light_size = 0.18
		spot.shadow_enabled = true
	var probe := ReflectionProbe.new()
	rig.add_child(probe)
	probe.position = Vector3(0,3.2,0)
	probe.size = Vector3(35,8,35)
	probe.box_projection = true
	probe.interior = true
	probe.intensity = 0.75
	probe.max_distance = 40.0
	probe.enable_shadows = true

func _polish_architecture(level: Node) -> void:
	# Restrict to level architecture: imported characters, weapons, props and UI stay authored.
	var architecture: Node = level.get_node_or_null("Architecture")
	if architecture == null: return
	for mesh in architecture.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for s in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(s)
			if not original is StandardMaterial3D: continue
			if original.albedo_texture != null or original.emission_enabled or original.transparency != 0: continue
			var key: int = original.get_instance_id()
			if not materials.has(key):
				var mat: StandardMaterial3D = original.duplicate()
				var title := mat.resource_name.to_lower()
				mat.roughness = maxf(mat.roughness, 0.42 if mat.metallic > 0.5 else 0.67)
				mat.albedo_texture = GRAIN
				mat.roughness_texture = GRAIN
				mat.normal_enabled = true
				mat.normal_texture = NORMAL_GRAIN
				mat.normal_scale = 0.18 if mat.metallic > 0.5 else 0.3
				mat.uv1_triplanar = true
				mat.uv1_world_triplanar = true
				mat.uv1_scale = Vector3.ONE * 2.0
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if "coated" in title or "paint" in title:
					mat.metallic = 0.0
					mat.roughness = 0.78
				materials[key] = mat
			mesh.set_surface_override_material(s, materials[key])
