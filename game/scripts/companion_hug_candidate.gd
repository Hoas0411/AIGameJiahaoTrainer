extends "res://scripts/companion_hug.gd"
## Waist-hold controller: same character size and same-source operator hands.
## Human acceptance remains separate from geometry and state-machine checks.
const CANDIDATE_MOUSE = preload("res://assets/models/companions/three_spots_20261002/mouse_repaired.glb")
const OPERATOR_ARMS = preload("res://assets/models/companions/hug_rework_20260930/operator_arms.glb")
const CHEEK_REST := Vector3(.21,1.205,.28032863)
const CHEEK_NORMAL := Vector3(.33689809,.28860879,.89621681)
const UPPER_LENGTH := .34
const LOWER_LENGTH := .29566704
const PICKUP_SECONDS := 2.25
const RELEASE_SECONDS := 2.25
const KISS_SECONDS := 1.65
@export var character_scale := .67
var skeleton: Skeleton3D
var mouse_skeleton: Skeleton3D
var camera_before := Transform3D.IDENTITY
var weapon_pose_before := Transform3D.IDENTITY
var camera_leased := false
var reach_excess := 0.0
var contact_distance := INF
var kiss_weight := 0.0
var seat_weight := 0.0
var arm_weight := 0.0
var player_start := Vector3.ZERO
var last_targets: Array[Vector3] = []
var body_dip := 0.0
var current_reach_excess := 0.0
var camera_pose := Transform3D.IDENTITY
var name_was_visible := true
const INTERACTION_RANGE := 1.65
var pending_interaction := ""
var approach_time := 0.0
var petting := false
var pet_time := 0.0
var pet_surface: Array[Vector3] = []
var pet_contact_error := 0.0

func _ready() -> void:
	super._ready()
	register_action("companion_pet", [KEY_J, KEY_K])

func owns_motion() -> bool:
	return petting or not pending_interaction.is_empty() or super.owns_motion()

func body_reference() -> Transform3D:
	var p := player_node()
	return Transform3D(p.global_basis, p.global_position+Vector3.UP*p.get_node("Head").position.y)

func resting_camera() -> Transform3D:
	return player_node().camera.get_parent_node_3d().global_transform*camera_before

func ensure_visual() -> void:
	if is_instance_valid(model): return
	model = CANDIDATE_MOUSE.instantiate(); model.scale = Vector3.ONE*character_scale; add_child(model)
	arms = OPERATOR_ARMS.instantiate(); add_child(arms)
	arms.set_as_top_level(true)
	skeleton = arms.find_child("Skeleton3D",true,false)
	mouse_skeleton = model.find_child("Skeleton3D",true,false)
	animation = model.find_child("AnimationPlayer",true,false)
	for name in animation.get_animation_list():
		if "HugSequence" in str(name): animation_name = name
	assert(not animation_name.is_empty())
	animation.play(animation_name); animation.pause()

func can_pickup() -> bool:
	if not super.can_pickup(): return false
	var p := player_node()
	var delta: Vector3 = actor.global_position-p.global_position
	return not petting and pending_interaction.is_empty() and absf(delta.y)<.18 and p.get("crouched")!=true and actor.flat(delta).length() < INTERACTION_RANGE and p.global_basis.z.dot(actor.flat(delta).normalized()) < -.35

func pickup() -> bool:
	if not can_pickup(): return false
	if needs_approach(.58): return request_interaction("hug")
	return begin_pickup()

func needs_approach(distance: float) -> bool:
	return actor.flat(actor.global_position-player_node().global_position).length() > distance+.06 or actor.global_basis.z.dot(player_node().global_basis.z)<.98

func request_interaction(kind: String) -> bool:
	pending_interaction = kind
	approach_time = 0
	epoch = current_epoch()
	actor.velocity = Vector3.ZERO
	phase = Phase.NONE
	return true

func begin_pickup() -> bool:
	var player := player_node()
	camera_before = player.camera.transform
	camera_pose = camera_before
	weapon_pose_before = player.weapon.transform
	player_start = player.global_position
	if not super.pickup(): return false
	camera_leased = true
	name_was_visible = actor.get_node("Name").visible
	set_left_arm_visible(true)
	actor.get_node("Name").hide()
	arms.hide(); sample(0)
	seat_weight = 0; arm_weight = 0; reach_excess = 0
	player.weapon.visible = weapon_before
	return true

func smooth_phase(start: float, end: float, time: float) -> float:
	return smoothstep(start,end,time)

func camera_dip(amount: float) -> void:
	# A local camera lease only; no changes to shared player movement or saved FOV.
	body_dip = .66*amount
	var camera: Camera3D = player_node().camera
	camera.global_transform = resting_camera()
	camera.global_position += Vector3.DOWN*body_dip
	camera.basis = camera_before.basis*Basis(Vector3.RIGHT,deg_to_rad(-25)*amount)
	camera_pose = camera.transform

func held_transform() -> Transform3D:
	var body := body_reference()
	var offset := Vector3(0,-1.13,-.52)
	return Transform3D(body.basis*Basis(Vector3.RIGHT,deg_to_rad(-15)),body*offset)

func support_pose(progress: float) -> void:
	if not is_instance_valid(skeleton): return
	arm_weight = progress
	arms.global_transform = Transform3D.IDENTITY
	var camera: Camera3D = player_node().camera
	var body := body_reference()
	body.origin += Vector3.DOWN*body_dip
	current_reach_excess = 0
	last_targets.clear()
	for side in ["L","R"]:
		if petting and side == "L": continue
		var sign := -1.0 if side == "L" else 1.0
		var fore_i := skeleton.find_bone("Forearm_"+side)
		var hand_i := skeleton.find_bone("Hand_"+side)
		var fore_rest := skeleton.get_bone_global_rest(fore_i)
		var hand_rest := skeleton.get_bone_global_rest(hand_i)
		var rest_forward := hand_rest.basis.y.normalized()
		var rest_normal := Vector3(-sign*.079496,-.064903,-.994720).normalized()
		# Native Blender rays on Root-weighted waist, not the outer sleeves.
		# The imported character is asymmetric about its object origin.
		var palm_local := Vector3(-.221 if side == "L" else .097,.77,.045)
		var desired := actor.to_global(palm_local*character_scale)
		if petting:
			var stroke := (sin((pet_time-.65)*TAU*1.1)+1)*.5
			var index := stroke*float(pet_surface.size()-1)
			desired = pet_surface[floori(index)].lerp(pet_surface[mini(ceili(index),pet_surface.size()-1)],fmod(index,1.0))
		var retracted: Vector3 = body*Vector3(sign*.24,-.59,-.12)
		desired = retracted.lerp(desired,progress)
		var forward: Vector3 = actor.global_basis*Vector3(-sign*.20,.45,-.87).normalized()
		var normal: Vector3 = actor.global_basis*Vector3(-sign,0,0)
		if petting:
			forward = actor.global_basis*Vector3(0,0,-1)
			normal = Vector3.DOWN
		var rotation := orientation(forward,normal)*orientation(rest_forward,rest_normal).inverse()
		# Corresponds to the centre of the ORIGINAL glove palm, not its fingertips.
		var palm_delta := Vector3(-sign*.02,-.063,-.02994918)
		var wrist := desired-rotation*palm_delta
		# Small forward shoulder reach with the load; do not lengthen bones.
		var shoulder: Vector3 = body*Vector3(sign*.23,-.32,lerpf(.045,-.10,seat_weight) if not petting else -.08)
		var line := wrist-shoulder
		var distance := line.length()
		reach_excess = maxf(reach_excess,distance-UPPER_LENGTH-LOWER_LENGTH)
		current_reach_excess = maxf(current_reach_excess,distance-UPPER_LENGTH-LOWER_LENGTH)
		var direction := line.normalized()
		var safe_distance := clampf(distance,absf(UPPER_LENGTH-LOWER_LENGTH)+.002,UPPER_LENGTH+LOWER_LENGTH-.002)
		wrist = shoulder+direction*safe_distance
		var along := (UPPER_LENGTH*UPPER_LENGTH-LOWER_LENGTH*LOWER_LENGTH+safe_distance*safe_distance)/(2*safe_distance)
		var bend_height := sqrt(maxf(0,UPPER_LENGTH*UPPER_LENGTH-along*along))
		var pole: Vector3 = body.basis*Vector3(sign*.8,-.9,.12)
		if petting: pole=body.basis*Vector3(1.8,-.1,.4)
		pole = (pole-direction*pole.dot(direction)).normalized()
		var elbow := shoulder+direction*along+pole*bend_height
		var rest_direction := (hand_rest.origin-fore_rest.origin).normalized()
		var fore_rotation := orientation((wrist-elbow).normalized(),normal)*orientation(rest_direction,rest_normal).inverse()
		skeleton.set_bone_global_pose(fore_i,Transform3D(fore_rotation*fore_rest.basis,elbow))
		skeleton.set_bone_global_pose(hand_i,Transform3D(rotation*hand_rest.basis,wrist))
		last_targets.append(desired)
		if petting and progress > .999:
			pet_contact_error = maxf(pet_contact_error,(wrist+rotation*palm_delta).distance_to(desired))

func set_left_arm_visible(value: bool) -> void:
	if not is_instance_valid(arms): return
	var left := arms.find_child("OperatorSleeveGlove_L",true,false)
	if left != null: left.visible = value

func pet_head() -> bool:
	if not can_pickup(): return false
	if needs_approach(.46): return request_interaction("pet")
	return begin_pet()

func collect_head_surface() -> bool:
	# Read the existing Blender mesh; ray/triangle queries do not create geometry.
	pet_surface.clear()
	var meshes := actor.get_node("Body/MouseVisual").find_children("*","MeshInstance3D",true,false)
	for i in range(9):
		# Behind the red headband, between the ears; avoid stroking its raised tips.
		var origin := actor.to_global(Vector3(lerpf(-.08,-.02,float(i)/8),3,-.10))
		var best := Vector3(0,-INF,0)
		for mesh_node in meshes:
			if mesh_node.mesh == null: continue
			var triangles: PackedVector3Array = mesh_node.mesh.get_faces()
			var inverse: Transform3D = mesh_node.global_transform.affine_inverse()
			var local_origin := inverse*origin
			var local_direction := inverse.basis*Vector3.DOWN
			for j in range(0,triangles.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin,local_direction,triangles[j],triangles[j+1],triangles[j+2])
				if hit != null:
					var world: Vector3 = mesh_node.to_global(hit)
					if world.y>best.y: best=world
		if not is_finite(best.y): return false
		pet_surface.append(best+Vector3.UP*.004)
	return true

func begin_pet() -> bool:
	ensure_visual()
	model.hide();arms.hide()
	actor.set_expression(0)
	actor.get_node("Body").transform = Transform3D.IDENTITY
	if not collect_head_surface(): return false
	var p := player_node()
	epoch=current_epoch(); combat_before=p.combat_enabled; weapon_before=p.weapon.visible
	weapon_pose_before=p.weapon.transform
	camera_before=p.camera.transform;camera_pose=camera_before;camera_leased=true
	name_was_visible=actor.get_node("Name").visible
	p.combat_enabled=false; p.weapon.hide()
	petting=true; pet_time=0; body_dip=0; seat_weight=0; pet_contact_error=0; reach_excess=0
	model.hide(); arms.show(); set_left_arm_visible(false)
	support_pose(0)
	actor.velocity=Vector3.ZERO
	actor.emotion_response.emit(2,"嘿嘿～摸摸头，好舒服呀！")
	cloth.play()
	return true

func step_approach(delta: float) -> void:
	approach_time += delta
	var p := player_node()
	if not available() or epoch!=current_epoch() or p.controls_blocked or approach_time>5 or actor.flat(actor.global_position-p.global_position).length()>2.3:
		cancel(epoch==current_epoch()); return
	var desired_distance := .46 if pending_interaction=="pet" else .58
	var goal: Vector3 = p.global_position+p.global_basis*Vector3(0,0,-desired_distance)
	var direction: Vector3 = actor.flat(goal-actor.global_position)
	actor.rotation.y=rotate_toward(actor.rotation.y,p.global_rotation.y,delta*3.5)
	if direction.length()>.035:
		if not actor.clear_path(actor.global_position,goal) or actor.ground_at(goal).is_empty(): cancel(); return
		actor.velocity=direction.normalized()*minf(1.15,direction.length()/maxf(delta,.001))+Vector3.DOWN*.5
		actor.move_and_slide()
		actor.get_node("Body").position.y=absf(sin(approach_time*8))*.018
		return
	if actor.global_basis.z.dot(p.global_basis.z)<.98: return
	var action := pending_interaction
	pending_interaction="";actor.velocity=Vector3.ZERO;actor.get_node("Body").transform=Transform3D.IDENTITY
	if action=="pet": begin_pet()
	else: begin_pickup()

func orientation(forward: Vector3, normal: Vector3) -> Basis:
	var f := forward.normalized()
	var n := (normal-f*normal.dot(f)).normalized()
	return Basis(f.cross(n),n,-f).orthonormalized()

func cheek_point() -> Vector3:
	var head := mouse_skeleton.find_bone("Head")
	var skin := mouse_skeleton.get_bone_global_pose(head)*mouse_skeleton.get_bone_global_rest(head).affine_inverse()
	return mouse_skeleton.to_global(skin*CHEEK_REST)

func mouth_point() -> Vector3:
	return player_node().camera.to_global(Vector3(0,-.09,-.095))

func lean_to_cheek(weight: float) -> void:
	var camera: Camera3D = player_node().camera
	var head := mouse_skeleton.find_bone("Head")
	var skin := mouse_skeleton.get_bone_global_pose(head)*mouse_skeleton.get_bone_global_rest(head).affine_inverse()
	var normal: Vector3 = (mouse_skeleton.global_basis*skin.basis*CHEEK_NORMAL).normalized()
	var x := Vector3.UP.cross(normal).normalized()
	var basis := Basis(x,normal.cross(x).normalized(),normal)
	var target := Transform3D(basis,cheek_point()-basis*Vector3(0,-.09,-.095))
	camera.global_transform = resting_camera().interpolate_with(target,weight)
	camera_pose = camera.transform
	body_dip = .25*weight

func put_down() -> bool:
	if not super.put_down(): return false
	# A close drop beside the player's feet; the old 1.3m target is out of reach.
	var p := player_node()
	var candidate: Vector3 = p.global_position+p.global_basis*Vector3(0,0,-.55)
	var hit: Dictionary = actor.ground_at(candidate)
	if hit.is_empty() or hit.normal.y < .7 or not actor.clear_path(p.global_position,candidate):
		phase = Phase.HELD; elapsed = 0; return false
	release_pose = Transform3D(Basis(Vector3.UP,p.global_rotation.y),hit.position+Vector3.UP*.05)
	start_pose = actor.global_transform
	return true

func cancel(restore_player: bool = true) -> void:
	var p := player_node()
	if petting and restore_player and is_instance_valid(p) and epoch==current_epoch():
		p.combat_enabled=combat_before;p.weapon.visible=weapon_before;p.weapon.transform=weapon_pose_before
	petting=false;pending_interaction=""
	set_left_arm_visible(true)
	if camera_leased and is_instance_valid(p):
		actor.get_node("Name").visible = name_was_visible
		if restore_player and epoch == current_epoch():
			p.camera.transform = camera_before
			p.weapon.transform = weapon_pose_before
	camera_leased = false
	super.cancel(restore_player)

func step(delta: float) -> void:
	if not pending_interaction.is_empty(): step_approach(delta); return
	if petting:
		if not available() or epoch!=current_epoch() or player_node().controls_blocked or player_node().velocity.length()>.5:
			cancel(epoch==current_epoch());return
		pet_time+=delta
		var reach := smooth_phase(0,.65,pet_time)*(1-smooth_phase(1.85,2.45,pet_time))
		support_pose(reach)
		# Briefly look down toward the contact instead of patting below the screen.
		var resting := resting_camera()
		var target := resting.looking_at(pet_surface[4]-Vector3.UP*.22,Vector3.UP)
		player_node().camera.global_transform=resting.interpolate_with(target,reach*.9)
		camera_pose=player_node().camera.transform
		if pet_time>=2.45: cancel()
		return
	if not carrying(): super.step(delta); return
	if not available() or epoch != current_epoch(): cancel(epoch == current_epoch()); return
	elapsed += delta
	if phase == Phase.PICKUP:
		var reach := smooth_phase(.35,.95,elapsed)
		var lift := smooth_phase(1.00,2.05,elapsed)
		seat_weight = smooth_phase(1.10,1.90,elapsed)
		camera_dip(smooth_phase(.20,.90,elapsed)*(1-smooth_phase(1.0,2.15,elapsed)))
		actor.global_transform = start_pose.interpolate_with(held_transform(),lift)
		# A small settling arc, not a straight-line teleport to the camera.
		actor.global_position += Vector3.UP*.025*sin(PI*lift)
		sample(.6*reach+.8*seat_weight)
		arms.visible = elapsed >= .35
		if elapsed >= .35: player_node().weapon.hide()
		support_pose(reach)
		if elapsed >= PICKUP_SECONDS: phase = Phase.HELD; elapsed = 0; camera_dip(0)
	elif phase == Phase.HELD:
		camera_dip(0)
		actor.global_transform = held_transform(); seat_weight = 1
		sample(2); support_pose(1)
	elif phase == Phase.CHEEK:
		kiss_weight = smooth_phase(0,.55,elapsed)*(1-smooth_phase(.90,KISS_SECONDS,elapsed))
		seat_weight = 1; sample(2+.8*kiss_weight)
		actor.global_transform = held_transform()
		lean_to_cheek(kiss_weight)
		support_pose(1)
		contact_distance = cheek_point().distance_to(mouth_point())
		if elapsed >= KISS_SECONDS: phase = Phase.HELD; elapsed = 0
	elif phase == Phase.RELEASE:
		var lower := smooth_phase(.10,1.25,elapsed)
		seat_weight = 1-smooth_phase(.15,1.20,elapsed)
		camera_dip(smooth_phase(0,1.15,elapsed)*(1-smooth_phase(1.45,RELEASE_SECONDS,elapsed)))
		actor.global_transform = start_pose.interpolate_with(release_pose,lower)
		sample(.6*(1-smooth_phase(1.30,1.75,elapsed))+.8*seat_weight)
		support_pose(1-smooth_phase(1.35,1.85,elapsed))
		arms.visible = elapsed < 1.85
		if elapsed >= RELEASE_SECONDS: actor.global_transform = release_pose; cancel()
	if carrying():
		actor.get_node("PlayerBulletHitArea").collision_layer = 0
		if actor.expression != 2: actor.set_expression(2)

func _process(delta: float) -> void:
	super._process(delta)
	# Weapon recoil writes even while its viewmodel is hidden. Reapply this
	# feature's camera lease after it; never modify the weapon controller.
	if (carrying() or petting) and camera_leased:
		player_node().camera.transform = camera_pose
		actor.get_node("Name").hide()
	elif is_instance_valid(player_node()) and actor.global_position.distance_to(player_node().global_position)<1.15:
		actor.get_node("Name").hide()
	if phase == Phase.PICKUP and elapsed < .35 and weapon_before:
		var p := player_node()
		p.weapon.position = weapon_pose_before.origin + Vector3.DOWN*.45*smooth_phase(0,.35,elapsed)
		p.weapon.rotation.x = weapon_pose_before.basis.get_euler().x-deg_to_rad(30)*smooth_phase(0,.35,elapsed)
	if label.visible:
		if petting: label.text="摸摸头～"
		elif not pending_interaction.is_empty(): label.text="麦小鼠正在走近…"
		elif not carrying() and can_pickup(): label.text += "  ·  %s 摸摸头" % key_label("companion_pet")

func _input(event: InputEvent) -> void:
	if petting and (event.is_action("fire") or event.is_action("aim")):
		get_viewport().set_input_as_handled();return
	super._input(event)

func _unhandled_input(event: InputEvent) -> void:
	if petting or not pending_interaction.is_empty(): return
	if available() and not player_node().controls_blocked and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not event.is_echo() and event.is_action_pressed("companion_pet"):
		pet_head();get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
