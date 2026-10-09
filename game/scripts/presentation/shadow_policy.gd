extends RefCounted
## Ground modules sit below everything else in a level: they receive shadows but
## never cast a visible one. Excluding them from the shadow pass removes their
## (very dense) geometry from every directional split without changing the image.

static func ground_receives_only(root: Node, name_prefixes: Array) -> int:
	var changed := 0
	for child in root.get_children():
		var n := str(child.name)
		var match_prefix := false
		for prefix in name_prefixes:
			if n.begins_with(prefix): match_prefix = true
		if not match_prefix: continue
		var meshes: Array = child.find_children("*", "GeometryInstance3D", true, false)
		if child is GeometryInstance3D: meshes.append(child)
		for g in meshes:
			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				changed += 1
	return changed
