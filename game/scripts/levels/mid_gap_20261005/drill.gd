extends "res://scripts/level.gd"

const GAP_SIZES := [0.2,0.5,1.0]
const STATIONS := [6.0,10.0,14.0]
const DIFFICULTY_NAMES := ["简单","困难","魔鬼"]
const DIFFICULTY_SCALES := [0.4,0.7,1.0]
var mode := 3
var game: Node
var rng := RandomNumberGenerator.new()
var crossing := false
var completed_crossings := 0
var successful_trials := 0
var reactions: Array[float] = []
var exposure_clock := -1.0
var exposure_ticks := -1
var clock := 0.0
var wait_time := 1.0
var begun := false
var gap_index := 1
var station_index := 1
var difficulty_index := 0
var gap_width := 0.5
var gap_animating := false
var gap_tween: Tween
var movers: Array[Node3D] = []
var mover_x: Dictionary = {}
var trial_hit := false
var trial_log: Array = []
var ui_layer: CanvasLayer
var options_panel: PanelContainer
var result_panel: PanelContainer
var history_panel: PanelContainer
var status: Label
var result_value: Label
var saved_mouse := Input.MOUSE_MODE_CAPTURED
var option_pause := false
var sound: AudioStreamPlayer3D
var gap_buttons: Array = []
var station_buttons: Array = []
var difficulty_buttons: Array = []
@onready var crosser: Node3D = $Enemies/Crosser

func _ready() -> void:
	game = get_parent()
	free_roam = true
	set_meta("training_focus",true)
	set_meta("preserve_authored_visuals",true)
	rng.randomize()
	for mesh: MeshInstance3D in $Architecture.find_children("*","MeshInstance3D",true,false):
		var n := str(mesh.name)
		if n.begins_with("leaf_") or n.begins_with("hanger_"):
			movers.append(mesh)
			mover_x[mesh] = mesh.position.x
		mesh.create_trimesh_collision()
		for body in mesh.get_children():
			if body is StaticBody3D: body.collision_layer = 1; body.collision_mask = 0
	# Invisible collision only; the visible scene is exclusively the Blender GLB.
	for side in [-1.0,1.0]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2,3,31)
		shape.shape = box
		body.position = Vector3(side*9,1.5,1)
		body.add_child(shape); add_child(body)
	crosser.training_hit.connect(_on_training_hit)
	sound = AudioStreamPlayer3D.new()
	sound.stream = preload("res://resources/audio/mid_gap_20261005/rail_move.wav")
	sound.position = Vector3(0,3.7,0.9);sound.volume_db = -8
	add_child(sound)
	_build_ui()
	call_deferred("_configure")

func _configure() -> void:
	game.player.weapon.equip(preload("res://resources/weapons/awm.tres"))
	var saved: Dictionary = game.training_options.get(15,{})
	gap_index = clampi(int(saved.get("gap_index",1)),0,2)
	station_index = clampi(int(saved.get("station_index",1)),0,2)
	difficulty_index = clampi(int(saved.get("difficulty_index",0)),0,2)
	_set_gap(GAP_SIZES[gap_index])
	select_station(station_index)
	for i in 3:
		gap_buttons[i].set_pressed_no_signal(i==gap_index)
		station_buttons[i].set_pressed_no_signal(i==station_index)
		difficulty_buttons[i].set_pressed_no_signal(i==difficulty_index)
	open_options()

func _process(delta: float) -> void:
	if not game.running or not begun: return
	clock += delta
	if game.player.position.y < -1 or absf(game.player.position.x)>8.85 or game.player.position.z>15.0:
		select_station(station_index)
	if crossing:
		if exposure_clock < 0 and target_visible():
			exposure_clock = clock
			exposure_ticks = Time.get_ticks_usec()
		if absf(crosser.position.x) >= 3.6:
			completed_crossings += 1
			trial_log.append({"kind":["run","jump","slide"][crosser.crossing_kind],"direction":crosser.crossing_direction,"hit":trial_hit,"first_visible_seconds":exposure_clock,"difficulty":DIFFICULTY_NAMES[difficulty_index],"speed_m_s":crosser.crossing_speed})
			crossing = false
			crosser.set_enabled(false)
			status.text = "%d / 5" % completed_crossings
			wait_time = rng.randf_range(0.7,1.5)
			if completed_crossings == 5: game.finish(true)
	else:
		wait_time -= delta
		if wait_time <= 0 and not gap_animating and game.player.weapon.cooldown <= 0 and game.player.weapon.reload_time <= 0:
			start_crossing()

func start_crossing() -> void:
	crossing = true
	trial_hit = false
	exposure_clock = -1
	exposure_ticks = -1
	crosser.start_crossing(rng.randi_range(0,2),1.0 if rng.randi_range(0,1)==0 else -1.0,DIFFICULTY_SCALES[difficulty_index])
	status.text = "%d / 5" % (completed_crossings+1)

func target_visible() -> bool:
	if not crosser.enabled: return false
	var eye: Vector3 = game.player.camera.global_position
	var space := get_world_3d().direct_space_state
	for area in crosser.get_node("Hitboxes").get_children():
		var shape: CollisionShape3D = area.get_node("Shape")
		var bounds := Vector3(0.16,0.12,0.12)
		if shape.shape is BoxShape3D: bounds = shape.shape.size*0.5
		for x in 25:
			for y in 3:
				var point: Vector3 = shape.global_transform*Vector3(lerpf(-bounds.x,bounds.x,x/24.0),lerpf(-bounds.y,bounds.y,y/2.0),bounds.z)
				if not game.player.camera.is_position_in_frustum(point): continue
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1))
				if hit.is_empty(): return true
	return false

func _on_training_hit(_zone: String) -> void:
	if not crossing or trial_hit or exposure_clock < 0: return
	trial_hit = true
	successful_trials += 1
	reactions.append(maxf(0,(Time.get_ticks_usec()-exposure_ticks)/1000.0))

func _set_gap(value: float) -> void:
	gap_width = value
	for mesh in movers:
		var side := -1.0 if str(mesh.name).contains("left") else 1.0
		mesh.position.x = float(mover_x[mesh])+side*(value-0.5)*0.5

func select_gap(index: int) -> void:
	gap_index = index
	if gap_tween: gap_tween.kill()
	gap_animating = true
	sound.play()
	gap_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	gap_tween.tween_method(_set_gap,gap_width,GAP_SIZES[index],0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	gap_tween.tween_callback(func(): gap_animating=false; sound.stop())
	_save_options()

func select_station(index: int) -> void:
	station_index = index
	game.player.position = Vector3(0,0.02,STATIONS[index])
	game.player.velocity = Vector3.ZERO
	_save_options()

func _save_options() -> void:
	game.training_options[15] = {"gap_index":gap_index,"station_index":station_index,"difficulty_index":difficulty_index}

func select_difficulty(index: int) -> void:
	difficulty_index = clampi(index,0,2)
	_save_options()

func metrics() -> Dictionary:
	var mean: Variant = null
	if not reactions.is_empty():
		var total := 0.0
		for r in reactions: total += r
		mean = total/reactions.size()
	return {"schema":"mid_gap_five_v1","mode":3,"completed_crossings":completed_crossings,"successful_trials":successful_trials,"accuracy_percent":successful_trials*100.0/5.0,"mean_reaction_ms":mean,"reaction_ms":reactions.duplicate(),"gap_width":gap_width,"station_z":STATIONS[station_index],"difficulty":DIFFICULTY_NAMES[difficulty_index],"trials":trial_log.duplicate(true)}

func live_stats() -> String: return "穿越 %d / 5" % completed_crossings
func session_time() -> float: return clock
func record_shot() -> void: pass
func is_open() -> bool: return options_panel.visible or result_panel.visible or history_panel.visible

func _build_ui() -> void:
	ui_layer = CanvasLayer.new();ui_layer.layer=20;ui_layer.process_mode=Node.PROCESS_MODE_ALWAYS;ui_layer.add_to_group("training_modal");add_child(ui_layer)
	# The modal group asks is_open on its member; this level implements it.
	ui_layer.remove_from_group("training_modal");add_to_group("training_modal")
	status = Label.new();status.position=Vector2(760,35);status.add_theme_font_size_override("font_size",24);ui_layer.add_child(status)
	options_panel = _panel(Vector2(570,185),Vector2(460,520))
	var v := _column(options_panel)
	_label(v,"架门缝",28)
	_label(v,"难度",19)
	var difficulties := HBoxContainer.new();v.add_child(difficulties)
	for i in 3: _button(difficulties,DIFFICULTY_NAMES[i],select_difficulty.bind(i))
	var difficulty_group := ButtonGroup.new()
	for b in difficulties.get_children(): b.toggle_mode=true; b.button_group=difficulty_group
	difficulty_buttons = difficulties.get_children()
	difficulties.get_child(difficulty_index).button_pressed=true
	_label(v,"门缝",19)
	var row := HBoxContainer.new();v.add_child(row)
	for i in 3: _button(row,["窄 · 20 cm","中 · 50 cm","宽 · 100 cm"][i],select_gap.bind(i))
	var gap_group := ButtonGroup.new()
	for b in row.get_children(): b.toggle_mode=true; b.button_group=gap_group
	gap_buttons = row.get_children()
	row.get_child(gap_index).button_pressed=true
	_label(v,"射击点位",19)
	var stations := HBoxContainer.new();v.add_child(stations)
	for i in 3: _button(stations,["近","中","远"][i],select_station.bind(i))
	var station_group := ButtonGroup.new()
	for b in stations.get_children(): b.toggle_mode=true; b.button_group=station_group
	station_buttons = stations.get_children()
	stations.get_child(station_index).button_pressed=true
	_label(v,"五次穿越，命中后计反应时间。",18)
	_button(v,"开始 / 继续训练",begin_training)
	result_panel = _panel(Vector2(570,260),Vector2(460,340));result_panel.hide()
	var result := _column(result_panel);_label(result,"本次训练",26)
	result_value = _label(result,"",26)
	_button(result,"▥  历史",show_history)
	var actions := HBoxContainer.new();result.add_child(actions)
	_button(actions,"继续该关卡",func():game.start_session(15))
	_button(actions,"返回训练基地",func():game.enter_hub())
	history_panel = _panel(Vector2(370,125),Vector2(860,650));history_panel.hide()
	var h := _column(history_panel);_label(h,"历史统计",26)
	_button(h,"返回",func():history_panel.hide();result_panel.show())

func _panel(pos: Vector2,extent: Vector2) -> PanelContainer:
	var panel := PanelContainer.new();panel.position=pos;panel.size=extent
	var style := StyleBoxFlat.new();style.bg_color=Color("202b30");style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style);ui_layer.add_child(panel);return panel
func _column(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new();v.add_theme_constant_override("separation",14);parent.add_child(v);return v
func _label(parent: Node,text: String,font_size: int) -> Label:
	var label := Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size);parent.add_child(label);return label
func _button(parent: Node,text: String,action: Callable) -> Button:
	var b := Button.new();b.text=text;b.custom_minimum_size=Vector2(100,40);b.pressed.connect(action);parent.add_child(b);return b

func open_options() -> void:
	option_pause = get_tree().paused
	saved_mouse = Input.mouse_mode
	get_tree().paused = true
	game.player.controls_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options_panel.show()

func begin_training() -> void:
	options_panel.hide()
	get_tree().paused = option_pause
	game.player.controls_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	begun = true
	status.text = "%d / 5" % completed_crossings
	wait_time = maxf(wait_time,0.8)

func show_session_results() -> void:
	options_panel.hide();result_panel.show()
	var data := metrics()
	result_value.text = "反应速度  %s\n命中率  %.0f%%" % ["—" if data.mean_reaction_ms==null else "%.0f ms" % data.mean_reaction_ms,data.accuracy_percent]

func show_history() -> void:
	result_panel.hide();history_panel.show()
	var v := history_panel.get_child(0)
	for child in v.get_children():
		if child.get_meta("chart_item",false): child.queue_free()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.get_node("Companion").history_path()))
	var records: Array = []
	if parsed is Array:
		for r in parsed:
			var m: Dictionary = r.get("drill_metrics",{})
			if r.get("level")==16 and m.get("schema")=="mid_gap_five_v1" and m.get("completed_crossings")==5: records.append(m)
	for reaction in [false,true]:
		var label := _label(v,"反应时间 · ms" if reaction else "命中率 · %",19);label.set_meta("chart_item",true)
		var chart := preload("res://scripts/levels/mid_gap_20261005/history_chart.gd").new();chart.records=records;chart.reaction=reaction;chart.custom_minimum_size=Vector2(780,190);chart.set_meta("chart_item",true);v.add_child(chart)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F9 and game.running:
		if options_panel.visible: begin_training()
		elif not crossing: open_options()
		get_viewport().set_input_as_handled()

## Three live values for the minimal HUD.
func hud_stats() -> Array:
	var hits := 0
	for t in trial_log:
		if t.get("hit", false): hits += 1
	return [["穿越", "%d / 5" % completed_crossings], ["截中", "%d / %d" % [hits, trial_log.size()]], ["用时", "%.1f s" % clock]]
