extends "res://scenes/levels/range_honor_R35/honor.gd"

func _finish_materials() -> void:
 for mesh in find_children("*","MeshInstance3D",true,false):
  for i in mesh.mesh.get_surface_count():
   var old=mesh.get_active_material(i)
   if not old is StandardMaterial3D:continue
   var name=old.resource_name.to_lower()
   var m=old.duplicate()
   if "warm grey powdercoat" in name:
    m.albedo_color=Color(.40,.42,.41);m.metallic=0;m.roughness=.51
   elif "graphite seal" in name or "graphite award" in name:
    m.albedo_color=Color(.115,.13,.135);m.metallic=.05;m.roughness=.64
   elif "brushed metal edge" in name:
    m.albedo_color=Color(.30,.32,.33);m.metallic=.8;m.roughness=.32
   elif "brushed silver" in name:
    m.albedo_color=Color(.65,.67,.68);m.metallic=1;m.roughness=.22
   elif "satin brass" in name:
    m.albedo_color=Color(.68,.48,.20);m.metallic=.9;m.roughness=.27
   elif "cut crystal" in name:
    m.albedo_color=Color(.79,.92,1,.10);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.metallic=0;m.roughness=.045
    m.refraction_enabled=false;m.refraction_scale=.012;m.cull_mode=BaseMaterial3D.CULL_BACK
   elif "clear display glass" in name:
    m.albedo_color=Color(.82,.94,1,.035);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.metallic=0;m.roughness=.055;m.cull_mode=BaseMaterial3D.CULL_BACK;m.refraction_enabled=false
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   elif "graphite cabinet interior" in name:
    m.albedo_color=Color(.16,.185,.195);m.metallic=.12;m.roughness=.51
   elif "joint cover" in name:
    m.albedo_color=Color(.24,.26,.27);m.metallic=.55;m.roughness=.38
   elif "diffuser" in name:
    m.emission=Color(1,.64,.30);m.emission_energy_multiplier=.65
   else:
    m.normal_scale=.10;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   mesh.set_surface_override_material(i,m)
 var probe=ReflectionProbe.new();probe.name="HonorInteriorReflection";add_child(probe)
 probe.position=Vector3(0,1.08,7.35);probe.size=Vector3(20,1.75,2.2);probe.box_projection=true;probe.interior=false;probe.intensity=.55;probe.max_distance=35;probe.enable_shadows=true
 probe.ambient_mode=ReflectionProbe.AMBIENT_COLOR
 probe.ambient_color=Color(.8,.82,.84);probe.ambient_color_energy=.85



