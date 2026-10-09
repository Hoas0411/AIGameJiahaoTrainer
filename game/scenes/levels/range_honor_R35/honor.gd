extends Node3D

var _cloth: Array[MeshInstance3D] = []
var _cloth_time: float = 0.0

func _process(delta: float) -> void:
	_cloth_time += delta
	for i in range(_cloth.size()):
		_cloth[i].set_blend_shape_value(0, 0.5 + 0.5 * sin(_cloth_time * 1.3 + i * 0.6))

func _ready() -> void:
	call_deferred("_finish_materials")
	for cloth in find_children("*", "MeshInstance3D", true, false):
		if cloth.get_blend_shape_count() > 0:
			_cloth.append(cloth)
	for player in find_children("*", "AnimationPlayer", true, false):
		player.stop()
		player.active = false
	for mesh in find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_active_material(i)
			if material is StandardMaterial3D and "crystal_local_material_candidate" in material.resource_name:
				var glass = material.duplicate()
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(0.85, 0.96, 1.0, 0.32)
				glass.metallic = 0.0
				glass.roughness = 0.07
				mesh.set_surface_override_material(i, glass)

func _finish_materials() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh.mesh.get_surface_count()):
			var original = mesh.get_active_material(i)
			if not original is StandardMaterial3D: continue
			var name = original.resource_name.to_lower()
			if "clear display glass" in name:
				var glass = original.duplicate()
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(0.88, 0.97, 1.0, 0.055)
				glass.roughness = 0.06
				glass.metallic = 0.0
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.set_surface_override_material(i,glass)
			elif "silver_local_material_candidate" in name:
				var metal = original.duplicate()
				metal.albedo_color = Color(0.34,0.37,0.40,1)
				metal.metallic = 1.0
				metal.roughness = 0.3
				mesh.set_surface_override_material(i,metal)
	var modules=get_parent().get_node("Architecture/BlenderArchitecture/Modules")
	for module in modules.get_children():
		if not "rear_" in module.name.to_lower(): continue
		for mesh in module.find_children("*", "MeshInstance3D", true, false):
			for i in range(mesh.mesh.get_surface_count()):
				var old=mesh.get_active_material(i)
				if not old is StandardMaterial3D: continue
				var wall=old.duplicate()
				wall.albedo_texture=null
				wall.albedo_color=Color(0.37,0.39,0.40,1)
				wall.metallic=0.0
				wall.roughness=0.58
				mesh.set_surface_override_material(i,wall)
