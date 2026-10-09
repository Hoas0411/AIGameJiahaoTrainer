extends "res://scripts/levels/distance_control.gd"

func _ready() -> void:
 super._ready()
 var authored=$Architecture/BlenderArchitecture/WorldEnvironment.environment.duplicate()
 for i in range(5):await get_tree().process_frame
 if not is_inside_tree():return
 authored.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 authored.ambient_light_color=Color(.84,.88,.92)
 authored.ambient_light_energy=.72
 authored.tonemap_mode=Environment.TONE_MAPPER_ACES
 authored.tonemap_exposure=1.02
 authored.ssao_enabled=true;authored.ssao_radius=.48;authored.ssao_intensity=1.5;authored.ssao_light_affect=.25
 authored.ssil_enabled=true;authored.ssil_radius=2;authored.ssil_intensity=.5
 authored.ssr_enabled=true;authored.glow_enabled=true;authored.glow_intensity=.10;authored.glow_hdr_threshold=1.8
 get_parent().get_node("WorldEnvironment").environment=authored
 $Architecture/BlenderArchitecture/Sun.visible=false
 $Sun.light_energy=1.05;$Sun.light_color=Color(1,.96,.89);$Sun.shadow_normal_bias=.18;$Sun.shadow_bias=.025
 # One duplicate per source material (not per mesh), so identical modules stay batchable.
 var tuned:={}
 for mesh in $Architecture.find_children("*","MeshInstance3D",true,false):
  var path=str(mesh.get_path()).to_lower()
  if "floor_" in path:
   mesh.material_override=load("res://scenes/levels/range_honor_R36/floor.tres")
   # Flat floor panels receive the skylight pattern but never cast a visible shadow.
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   continue
  for i in mesh.mesh.get_surface_count():
   var old=mesh.get_active_material(i)
   if not old is StandardMaterial3D:continue
   var tune_key=str(old.get_instance_id())+("|rear" if ("rear_" in path or "far_" in path) else ("|wall" if "wall_" in path else ("|ceiling" if "ceiling" in path else "")))
   if tuned.has(tune_key):
    mesh.set_surface_override_material(i,tuned[tune_key])
    if tuned[tune_key].transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    continue
   var m=old.duplicate();m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   if m.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    m.albedo_color=Color(.75,.87,.92,.06);m.roughness=.1;m.metallic=0;m.metallic_specular=.25;m.refraction_enabled=false
   elif "rear_" in path or "far_" in path:
    m.albedo_texture=null;m.albedo_color=Color(.48,.49,.47);m.metallic_texture=null;m.metallic=0;m.roughness_texture=null;m.roughness=.54;m.normal_scale=.025
   elif "floor_" in path:
    m.albedo_color=Color(.80,.82,.83);m.metallic_texture=null;m.metallic=.08;m.roughness_texture=null;m.roughness=.52;m.normal_scale=.035;m.metallic_specular=.4
   elif "wall_" in path:
    m.normal_scale=.07;m.metallic_texture=null;m.metallic=.05;m.roughness_texture=null;m.roughness=.5
   elif "ceiling" in path:
    m.normal_scale=.04;m.metallic_texture=null;m.metallic=.12;m.roughness_texture=null;m.roughness=.52
   tuned[tune_key]=m
   mesh.set_surface_override_material(i,m)
 # ~1.6k repeated wall/floor/ceiling modules: batch them per 12 m chunk (draw calls, not looks).
 var stats=preload("res://scripts/presentation/static_batcher.gd").batch($Architecture,16.0,3)
 print("STATIC_BATCH range ",stats)




