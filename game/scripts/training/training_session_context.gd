extends RefCounted

# Read-only session evidence. The shared player and its Resources remain owners
# of all input, movement and firearm parameters.
var initial: Dictionary = {}
var latest: Dictionary = {}
var changes: Array[Dictionary] = []
var origin := Vector3.ZERO
var previous := Vector3.ZERO
var distance_walked: float = 0.0
var maximum_horizontal_offset: float = 0.0
var airborne_seconds: float = 0.0
var crouched_seconds: float = 0.0
var sample_at: float = 0.0

static func stored_values(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for property in object.get_property_list():
		var name: String = property.name
		if int(property.usage) & PROPERTY_USAGE_STORAGE and name != "script" and not name.begins_with("resource_"):
			var value: Variant = object.get(name)
			if typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING]:
				result[name] = value
	return result

static func fingerprint(player: Node) -> Dictionary:
	var input: Dictionary = {}
	for key in ["sensitivity","yaw_coefficient","ads_multiplier","laser_multiplier","base_fov","horizontal_fov","mouse_dpi","horizontal_sensitivity","vertical_sensitivity","monitor_distance","monitor_match"]:
		input[key] = player.get(key)
	var body: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	var data: Dictionary = {"player_scene":player.scene_file_path,"motion":stored_values(player.motion),"input":input,"capsule_radius":body.radius,"physics_hz":Engine.physics_ticks_per_second,"viewport":vector2_array(player.get_viewport().get_visible_rect().size)}
	data["shared_weapons"] = {"rifle":stored_values(preload("res://resources/weapons/m7.tres")),"awm":stored_values(preload("res://resources/weapons/awm.tres"))}
	data["trainer_version"] = ProjectSettings.get_setting("application/config/version","")
	data["signature"] = JSON.stringify(data,"",true,true).sha256_text()
	return data

static func vector2_array(value: Vector2) -> Array:
	return [value.x,value.y]

static func vector3_array(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func begin(player: Node) -> void:
	changes.clear()
	distance_walked = 0.0
	maximum_horizontal_offset = 0.0
	airborne_seconds = 0.0
	crouched_seconds = 0.0
	sample_at = 0.0
	initial = fingerprint(player)
	latest = initial.duplicate(true)
	origin = player.global_position
	previous = origin

func observe(player: Node, delta: float, time: float) -> void:
	var current: Vector3 = player.global_position
	distance_walked += Vector2(current.x-previous.x,current.z-previous.z).length()
	maximum_horizontal_offset = maxf(maximum_horizontal_offset,Vector2(current.x-origin.x,current.z-origin.z).length())
	if not player.is_on_floor():
		airborne_seconds += delta
	if player.crouched:
		crouched_seconds += delta
	previous = current
	if time >= sample_at:
		sample_at = time + 0.5
		var now: Dictionary = fingerprint(player)
		if now.signature != latest.signature:
			changes.append({"time":time,"parameters":now})
			latest = now

func report(player: Node) -> Dictionary:
	var final: Dictionary = fingerprint(player)
	return {"initial":initial,"final":final,"changes":changes,"parameters_unchanged":changes.is_empty() and initial.get("signature","") == final.signature,
		"start_position_m":vector3_array(origin),"end_position_m":vector3_array(player.global_position),"horizontal_travel_m":distance_walked,"maximum_horizontal_offset_m":maximum_horizontal_offset,"airborne_seconds":airborne_seconds,"crouched_seconds":crouched_seconds,
		"weapon_at_end":stored_values(player.weapon.profile),"weapon_resource":player.weapon.profile.resource_path}
