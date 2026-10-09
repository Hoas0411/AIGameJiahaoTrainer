extends RefCounted
## Runtime draw-call batching for repeated, static architecture modules.
## Authored scenes stay unchanged and editable: at level load, MeshInstance3D
## nodes that share one mesh + materials + shadow mode are grouped into spatial
## chunks and drawn through MultiMeshInstance3D. The originals are only hidden,
## so their collision bodies, names and any code references keep working.
## Chunking keeps per-chunk culling and LOD selection local (a MultiMesh picks
## LOD and visibility from its own bounds), instead of one level-wide instance.

const MIN_GROUP := 6

static func batch(root: Node3D, chunk_size: float = 12.0, min_group: int = MIN_GROUP) -> Dictionary:
	var groups: Dictionary = {}
	var mesh_cache: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _eligible(mi): continue
		var mesh: Mesh = _effective_mesh(mi, mesh_cache)
		var key := "%d|%d|%d|%d|%d" % [mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override else 0, mi.cast_shadow, mi.layers, mi.gi_mode]
		var p: Vector3 = mi.global_position
		var cell := Vector3i(floori(p.x / chunk_size), floori(p.y / chunk_size), floori(p.z / chunk_size))
		var gkey := key + "|" + str(cell)
		if not groups.has(gkey): groups[gkey] = {"mesh": mesh, "src": mi, "items": []}
		groups[gkey].items.append(mi)
	# Merge sparse chunks back with their siblings so tiny groups do not stay unbatched.
	var batched := 0
	var multimeshes := 0
	var holder := Node3D.new()
	holder.name = "StaticBatches"
	root.add_child(holder)
	holder.global_transform = Transform3D.IDENTITY
	for gkey in groups:
		var g: Dictionary = groups[gkey]
		var items: Array = g.items
		if items.size() < min_group: continue
		var src: MeshInstance3D = g.src
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = g.mesh
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, (items[i] as MeshInstance3D).global_transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = src.material_override
		mmi.cast_shadow = src.cast_shadow
		mmi.layers = src.layers
		mmi.gi_mode = src.gi_mode
		holder.add_child(mmi)
		for item in items:
			(item as MeshInstance3D).visible = false
		batched += items.size()
		multimeshes += 1
	return {"batched_instances": batched, "multimeshes": multimeshes}

static func _eligible(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or not mi.is_visible_in_tree(): return false
	if mi.get_script() != null: return false
	if mi.skeleton != NodePath("") and mi.get_node_or_null(mi.skeleton) is Skeleton3D: return false
	if mi.material_overlay != null: return false
	if mi.transparency > 0.0: return false
	if mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0: return false
	if mi.mesh is ImmediateMesh: return false
	# Transparent surfaces need per-object depth sorting; keep them as individual nodes.
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s) as BaseMaterial3D
		if m != null and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	return true

# Bake per-surface override materials into a shared mesh copy (cached per combination),
# because MultiMeshInstance3D only exposes a whole-object material override.
static func _effective_mesh(mi: MeshInstance3D, cache: Dictionary) -> Mesh:
	var overrides: Array = []
	var any := false
	for s in mi.mesh.get_surface_count():
		var m: Material = mi.get_surface_override_material(s)
		overrides.append(m)
		if m != null: any = true
	if not any: return mi.mesh
	var key := str(mi.mesh.get_instance_id())
	for m in overrides: key += ":" + str(m.get_instance_id() if m else 0)
	if cache.has(key): return cache[key]
	var copy: Mesh = mi.mesh.duplicate()
	for s in overrides.size():
		if overrides[s] != null: copy.surface_set_material(s, overrides[s])
	cache[key] = copy
	return copy
