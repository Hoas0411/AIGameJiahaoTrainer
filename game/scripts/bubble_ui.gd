extends CanvasLayer

var operation_receipt_until := 0
var progress_active := false

enum WorldState { HIDDEN, FULL, EDGE }

const WORLD_WIDTH := 270.0
const DOCK_WIDTH := 270.0
const MASCOT_TOP := 66.0
const HUD_BOTTOM_RESERVE := 178.0
const SCREEN_MARGIN := 30.0
const EXPRESSION_TEXTURES := [
	preload("res://resources/ui/dialogue_mascot/neutral.tres"),
	preload("res://resources/ui/dialogue_mascot/crying.tres"),
	preload("res://resources/ui/dialogue_mascot/happy.tres"),
	preload("res://resources/ui/dialogue_mascot/excited.tres"),
	preload("res://resources/ui/dialogue_mascot/smug.tres"),
	preload("res://resources/ui/dialogue_mascot/angry.tres"),
	preload("res://resources/ui/dialogue_mascot/scared.tres"),
]
const AIM_PROTECTION_HALF := Vector2(150.0, 105.0)
const MIN_FULL_DISTANCE := 1.25
const MAX_FULL_DISTANCE := 18.0

@onready var game: Node = get_parent()
@onready var companion: Node = game.get_node("Companion")
@onready var actor: CharacterBody3D = game.get_node("CompanionActor")
@onready var voice: Node = game.get_node("VoiceInput")
@onready var world_bubble: Control = $WorldOverlay/WorldBubble
@onready var edge_prompt: Control = $WorldOverlay/EdgePrompt

var old_mouse: int = Input.MOUSE_MODE_CAPTURED
var queue: Array[String] = []
var bubble_time: float = 0.0
var manually_folded: bool = false
var explicit_reply_pending: bool = false
var last_reply: String = ""
var world_state: WorldState = WorldState.HIDDEN
var world_reason: String = ""
var route_bubble: PanelContainer
var route_label: Label
var displayed_expression := -1


func _ready() -> void:
	actor.get_node("Speech").visible = false
	apply_appearance()
	UIAppearance.changed.connect(apply_appearance)
	build_route_prompt()
	$Root/Bubble/Fold.pressed.connect(func(): manually_folded = not manually_folded)
	companion.reply_received.connect(on_reply)
	actor.emotion_response.connect(on_emotion_response)
	companion.reply_progress.connect(on_progress)
	companion.changed.connect(refresh)
	voice.state_changed.connect(refresh)
	voice.transcribed.connect(func(text): submit_text(text, true))
	$Root/Bubble/Entry.text_submitted.connect(func(_text): submit_entry())
	$Root/Bubble/Send.pressed.connect(submit_entry)
	$Root/Bubble/Remember.pressed.connect(func(): companion.confirm_memory(); refresh())
	$Root/Bubble/Summon.pressed.connect(func(): companion.enabled = true; companion.save_state(); actor.reset_position())
	$Root/Bubble/MicMode.add_item("麦克风关闭")
	$Root/Bubble/MicMode.add_item("E 按一下开 / 关")
	$Root/Bubble/MicMode.add_item("E 长按说话")
	$Root/Bubble/MicMode.select(voice.mode)
	$Root/Bubble/MicMode.item_selected.connect(func(i): voice.set_mode(i); call_deferred("close_input"))
	$Root/Bubble/Preferences.pressed.connect(func(): close_input(); game.get_node("CompanionUI").open_panel())
	$Root/Bubble/MicButton.pressed.connect(func():
		if voice.mode == 2:
			return
		if voice.mode == 0:
			voice.set_mode(1)
			$Root/Bubble/MicMode.select(1)
		if voice.listening: voice.stop_listening()
		else: voice.start_listening()
		close_input())
	$Root/Bubble/MicButton.button_down.connect(func():
		if voice.mode == 2: voice.start_listening())
	$Root/Bubble/MicButton.button_up.connect(func():
		if voice.mode == 2:
			voice.stop_listening()
			close_input())
	refresh()


func build_route_prompt() -> void:
	route_bubble = PanelContainer.new()
	route_bubble.name = "RoutePrompt"
	route_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_bubble.custom_minimum_size = Vector2(510, 118)
	$Root.add_child(route_bubble)
	route_label = Label.new()
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_label.custom_minimum_size = Vector2(470, 0)
	route_label.add_theme_font_size_override("font_size", 18)
	route_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_bubble.add_child(route_label)
	apply_appearance()


func _input(event: InputEvent) -> void:
	# Screen-length replies remain readable with the FPS mouse captured.
	if edge_prompt.visible and $WorldOverlay/EdgePrompt/Panel/Summary.scroll_active and event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var scroll: VScrollBar = $WorldOverlay/EdgePrompt/Panel/Summary.get_v_scroll_bar()
			scroll.value += 72.0 * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if $Root/Bubble/Entry.visible and event.is_action_pressed("ui_cancel"):
		close_input()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and game.running and game.player.active and not get_tree().paused:
		if $Root/Bubble/Entry.visible:
			submit_entry()
		else:
			open_input()
		get_viewport().set_input_as_handled()


func open_input() -> void:
	if $Root/Bubble/Entry.visible or not game.running or not game.player.active or get_tree().paused:
		return
	old_mouse = Input.mouse_mode
	manually_folded = false
	game.player.controls_blocked = true
	game.player.weapon.aiming = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Root/Bubble.show()
	for path in ["Entry", "Send", "MicMode", "MicButton", "MicStatus", "Level", "Status"]:
		get_node("Root/Bubble/" + path).show()
	$Root/Bubble/Entry.grab_focus()
	_hide_world()


func close_input() -> void:
	if not $Root/Bubble/Entry.visible:
		return
	for path in ["Entry", "Send", "MicMode", "MicButton", "MicStatus", "Level", "Status"]:
		get_node("Root/Bubble/" + path).hide()
	$Root/Bubble.hide()
	$Root/Bubble/Entry.release_focus()
	game.player.controls_blocked = false
	Input.mouse_mode = old_mouse


func submit_entry() -> void:
	var text: String = $Root/Bubble/Entry.text.strip_edges()
	if text.is_empty():
		close_input()
		return
	if submit_text(text):
		$Root/Bubble/Entry.clear()
		close_input()


func submit_text(text: String, spoken: bool = false) -> bool:
	if companion.busy and companion.current_kind == "event": companion.invalidate()
	if companion.commands.is_command(text):
		explicit_reply_pending = true
		manually_folded = false
		companion.chat.call_deferred(text)
		return true
	if queue.size() >= 4:
		$Root/Bubble/Status.text = "消息队列已满，请等麦小鼠回应"
		return false
	queue.append(text.left(1500))
	explicit_reply_pending = true
	manually_folded = false
	$Root/Bubble/Transcript.text = ("语音 → " if spoken else "你 → ") + summarize(text, 48)
	return true


func summarize(text: String, limit: int) -> String:
	var compact := text.replace("\r", " ").replace("\n", " ").strip_edges()
	while "  " in compact:
		compact = compact.replace("  ", " ")
	return compact.left(limit) + ("…" if compact.length() > limit else "")


func on_progress(text: String) -> void:
	progress_active = true
	manually_folded = false
	last_reply = text if not text.is_empty() else "消息收到了，正在想…"
	$Root/Bubble/Reply.text = last_reply
	set_reply_text(last_reply)
	bubble_time = 10.0
	operation_receipt_until = Time.get_ticks_msec() + 1000

func on_reply(text: String, source: String, _action: String) -> void:
	if progress_active and source != "local": operation_receipt_until = 0
	progress_active = false
	manually_folded = false
	if is_instance_valid(game.level) and game.level.get_meta("training_focus", false) and not $Root/Bubble/Entry.visible and not explicit_reply_pending:
		manually_folded = true
	explicit_reply_pending = false
	last_reply = text
	$Root/Bubble/Reply.text = text
	$Root/Bubble/Who.text = "麦小鼠 · " + ("AI" if source == "ai" else "本地")
	if source == "ai" and companion.last_reply_latency_ms > 0:
		$Root/Bubble/Who.text += " · 本次回复 %.2f 秒" % (float(companion.last_reply_latency_ms) / 1000.0)
	set_reply_text(text)
	bubble_time = clampf(5.0 + text.length() * 0.20, 10.0, 120.0)
	actor.get_node("Speech").text = ""
	actor.get_node("Speech").visible = false

func on_emotion_response(_face: int, text: String) -> void:
	# This local reaction uses the ordinary world bubble, even in focused drills.
	explicit_reply_pending = true
	operation_receipt_until = 0
	on_reply(text, "local", "idle")
	bubble_time = 3.5


func refresh() -> void:
	if progress_active and not companion.busy:
		progress_active = false
		operation_receipt_until = 0
		bubble_time = 0.0
	$Root/Bubble/Status.text = companion.status
	$Root/Bubble/MicStatus.text = voice.status
	$Root/Bubble/Remember.disabled = companion.pending_memory.is_empty()
	$Root/Bubble/Remember.tooltip_text = companion.pending_memory
	$Root/Bubble/MicButton.text = "按住说话" if voice.mode == 2 else ("停止录音" if voice.listening else "开始录音")


func _process(delta: float) -> void:
	sync_model_expression()
	if progress_active and companion.busy:
		operation_receipt_until = Time.get_ticks_msec() + 1000
		bubble_time = 10.0
	actor.get_node("Speech").visible = false
	update_input_bar()
	update_route_prompt()
	update_world_presentation()
	if should_advance_bubble_time():
		bubble_time = maxf(0.0, bubble_time - delta)
	if not queue.is_empty() and not companion.busy:
		companion.chat(queue.pop_front())
	if not queue.is_empty():
		$Root/Bubble/Status.text = companion.status + " · 等待 %d 条" % queue.size()
	$Root/Bubble/Level.value = voice.rms * 10 if voice.listening else 0


func update_input_bar() -> void:
	var size := get_viewport().get_visible_rect().size
	var width := minf(860.0, size.x - 36.0)
	$Root.size = size
	$Root.scale = Vector2.ONE
	$Root/Bubble.size = Vector2(width, 118)
	$Root/Bubble.position = Vector2((size.x - width) * 0.5, size.y - 136.0)
	$Root/Bubble.visible = $Root/Bubble/Entry.visible and game.running and game.player.active and not get_tree().paused and not game.get_node("CompanionUI").box.visible
	$Root/Bubble/Entry.size.x = maxf(250.0, width - 360.0)
	$Root/Bubble/Send.position.x = width - 332.0
	$Root/Bubble/MicButton.position.x = width - 238.0
	$Root/Bubble/Level.position.x = width - 105.0
	$Root/Bubble/MicStatus.size.x = maxf(220.0, width - 270.0)


func update_route_prompt() -> void:
	var routes: Node = game.get_node("CompanionRoutes")
	route_bubble.visible = routes.pending and game.running and not get_tree().paused and not game.player.controls_blocked and not routes.suspended
	if route_bubble.visible:
		route_label.text = "麦小鼠  /  下一段\n" + routes.prompt_text()
		var size := get_viewport().get_visible_rect().size
		route_bubble.position = Vector2(maxf(18.0, size.x - 528.0), maxf(18.0, size.y - 148.0))


func has_modal_overlay() -> bool:
	if game.get_node("CompanionUI").box.visible:
		return true
	if game.ui.get_node("Root/Results").visible:
		return true
	for overlay in get_tree().get_nodes_in_group("training_modal"):
		if overlay.has_method("is_open") and overlay.is_open():
			return true
	return false


func world_context_available() -> bool:
	return game.running and game.player.active and game.player.visible and game.player.camera.current and (actor.visible or Time.get_ticks_msec() < operation_receipt_until) and not get_tree().paused and not has_modal_overlay() and not $Root/Bubble/Entry.visible


func should_advance_bubble_time() -> bool:
	if bubble_time <= 0.0 or not game.running or not game.player.active or get_tree().paused:
		return false
	if has_modal_overlay() or $Root/Bubble/Entry.visible or game.get_node("CompanionRoutes").pending:
		return false
	if edge_prompt.visible and $WorldOverlay/EdgePrompt/Panel/Summary.scroll_active:
		return false
	return true


func set_reply_text(text: String) -> void:
	for panel in [world_bubble, edge_prompt]:
		var body: RichTextLabel = panel.get_node("Panel/Summary")
		body.text = text
		body.scroll_to_line(0)

func sync_model_expression() -> void:
	# The actor is the sole owner: includes direct changes, hugs and expiry.
	var current := clampi(actor.expression, 0, EXPRESSION_TEXTURES.size() - 1)
	if current == displayed_expression: return
	displayed_expression = current
	for panel in [world_bubble, edge_prompt]:
		panel.get_node("Mascot").texture = EXPRESSION_TEXTURES[current]

func dock_top() -> float:
	return maxf(MASCOT_TOP + 12.0, get_viewport().get_visible_rect().size.y * 0.24)


func layout_reply(panel: Control, docked: bool) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compensation := world_display_compensation()
	panel.scale = compensation
	var width := minf(DOCK_WIDTH if docked else WORLD_WIDTH, (viewport_size.x - SCREEN_MARGIN * 2.0) / compensation.x)
	var top := 34.0
	var bottom := 14.0
	var body: RichTextLabel = panel.get_node("Panel/Summary")
	body.position = Vector2(16, top)
	body.size.x = width - 32.0
	# Measure at the real wrap width before assigning height. No character limit.
	var content_height := float(body.get_content_height())
	var limit := maxf(48.0, viewport_size.y - HUD_BOTTOM_RESERVE - dock_top() - top - bottom)
	body.scroll_active = docked and content_height > limit
	body.size.y = minf(content_height, limit) if docked else content_height
	panel.size = Vector2(width, top + body.size.y + bottom)
	panel.get_node("Panel").size = Vector2(width, top + body.size.y + bottom)


func actor_fully_in_view(camera: Camera3D) -> bool:
	# Check the full visible body, including ears and feet, not just Speech.
	# Local mesh bounds are deliberately conservative near the frame edges.
	var meshes := actor.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	var hug := actor.get_node_or_null("Hug")
	if hug != null and is_instance_valid(hug.model):
		meshes.append_array(hug.model.find_children("*", "MeshInstance3D", true, false))
	var found := false
	var safe := get_viewport().get_visible_rect().grow(-8.0)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		found = true
		var bounds := mesh.get_aabb()
		for corner in 8:
			var point := mesh.global_transform * bounds.get_endpoint(corner)
			if not camera.is_position_in_frustum(point) or not safe.has_point(camera.unproject_position(point)):
				return false
	return found


func update_world_presentation() -> void:
	_hide_world()
	var name_label: Label3D = actor.get_node("Name")
	name_label.visible = true
	if bubble_time <= 0.0 or last_reply.is_empty() or manually_folded or not world_context_available():
		return
	if game.get_node("CompanionRoutes").pending:
		return
	name_label.visible = false
	var camera: Camera3D = game.player.camera
	var anchor: Vector3 = actor.get_node("Speech").global_position
	var head: Vector3 = actor.get_node("Body/Head").global_position
	var distance := camera.global_position.distance_to(head)
	if Time.get_ticks_msec() < operation_receipt_until:
		_show_docked("operation")
		return
	if not actor_fully_in_view(camera):
		_show_docked("outside_frame")
		return
	if distance < MIN_FULL_DISTANCE or distance > MAX_FULL_DISTANCE or is_head_occluded(camera, head):
		_show_docked("distance_or_occlusion")
		return
	layout_reply(world_bubble, false)
	var viewport_size := get_viewport().get_visible_rect().size
	var projected := camera.unproject_position(anchor)
	var drawn_size := world_bubble.size * world_bubble.scale
	var candidate := Rect2(projected - Vector2(drawn_size.x * 0.5, drawn_size.y), drawn_size)
	var safe := Rect2(Vector2.ONE * SCREEN_MARGIN, viewport_size - Vector2.ONE * SCREEN_MARGIN * 2.0)
	var aim := Rect2(viewport_size * 0.5 - AIM_PROTECTION_HALF, AIM_PROTECTION_HALF * 2.0)
	var visual_bounds := Rect2(candidate.position - Vector2(0, MASCOT_TOP), candidate.size + Vector2(10, MASCOT_TOP))
	if not safe.encloses(visual_bounds) or visual_bounds.intersects(aim):
		_show_docked("layout_space")
		return
	world_bubble.position = candidate.position
	world_bubble.show()
	world_state = WorldState.FULL


func is_head_occluded(camera: Camera3D, head: Vector3) -> bool:
	var excluded: Array[RID] = [game.player.get_rid(), actor.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, head, 1, excluded)
	query.collide_with_areas = false
	return not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func world_display_compensation() -> Vector2:
	if DisplayServer.get_name() == "headless":
		return Vector2.ONE
	var screen_scale := get_viewport().get_screen_transform().get_scale().abs()
	if screen_scale.x < 0.001 or screen_scale.y < 0.001:
		return Vector2.ONE
	# Keep the panel and text physically isotropic when IGNORE stretch maps a
	# 4:3 logical viewport into a 16:9 window. Projection remains in logical space.
	return Vector2(screen_scale.y / screen_scale.x, 1.0)


func _show_docked(reason: String) -> void:
	layout_reply(edge_prompt, true)
	var viewport_size := get_viewport().get_visible_rect().size
	# Approved upper-right anchor: long replies grow down towards the HUD.
	edge_prompt.position = Vector2(viewport_size.x - SCREEN_MARGIN - edge_prompt.size.x * edge_prompt.scale.x,
		dock_top())
	edge_prompt.show()
	world_state = WorldState.EDGE
	world_reason = reason # Diagnostic state only, never player-facing prose.


func _hide_world() -> void:
	world_bubble.hide()
	edge_prompt.hide()
	world_state = WorldState.HIDDEN
	world_reason = ""


func reset_session() -> void:
	close_input()
	explicit_reply_pending = false
	queue.clear()
	bubble_time = 0.0
	last_reply = ""
	manually_folded = false
	_hide_world()
	actor.get_node("Speech").text = ""
	actor.get_node("Speech").visible = false
	actor.get_node("Name").visible = true
	voice.stop_listening(false)
	voice.pending.clear()
	voice.get_node("Request").cancel_request()
	voice.busy = false


func make_style(background: Color, border: Color, radius: int, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	return style


func apply_appearance() -> void:
	if not is_node_ready():
		return
	$Root.theme = UIAppearance.get_theme()
	$WorldOverlay.theme = UIAppearance.get_theme()
	var index := clampi(UIAppearance.selected, 0, 2)
	var background: Color = [Color("141e23"), Color("080809"), Color("eeeae0")][index]
	var foreground: Color = [Color("f0f3f5"), Color.WHITE, Color("19272c")][index]
	var border: Color = [Color("4c7278"), Color("c6c6c6"), Color("b7b09d")][index]
	for panel in [world_bubble, edge_prompt]:
		var body: RichTextLabel = panel.get_node("Panel/Summary")
		body.add_theme_color_override("default_color", Color("#243238"))
		body.add_theme_font_size_override("normal_font_size", 17)
		body.add_theme_constant_override("line_separation", 3)
		body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		panel.get_node("Panel/Who").add_theme_color_override("font_color", Color("#243238"))
		panel.get_node("Panel/Accent").color = Color("#ad4144")
	$Root/Bubble.add_theme_stylebox_override("panel", make_style(background, border, 4, 1))
	$Root/Bubble/MicStatus.add_theme_color_override("font_color", foreground)
	$Root/Bubble/Status.add_theme_color_override("font_color", foreground)
	if is_instance_valid(route_bubble):
		route_bubble.add_theme_stylebox_override("panel", make_style(background, border, 4, 1))
		route_label.add_theme_color_override("font_color", foreground)
