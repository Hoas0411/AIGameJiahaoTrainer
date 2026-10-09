extends Node

## Lives under Main, so replacing a training level cannot restart the track.
const TRACKS: Array[String] = [
	"res://assets/audio/record_music/track_1.ogg",
	"res://assets/audio/record_music/track_2.ogg",
]
# Static references make both tracks part of exported game packages.
const BUNDLED_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/record_music/track_1.ogg"),
	preload("res://assets/audio/record_music/track_2.ogg"),
]
const TRACK_LABELS: Array[String] = ["Alugalug Cat", "Gut Genug_H"]
# Measured integrated loudness (EBU R128): track_1 -11.3 LUFS, track_2 -7.9 LUFS, both with
# true peaks above 0 dBTP. Weapon shots sit around -17…-20 LUFS. Bring both tracks to
# about -16 LUFS so they match each other and sit level with, not above, the gunfire.
const TRACK_GAIN_DB: Array[float] = [-4.7, -8.1]

var track_index: int = 0
var speaker: AudioStreamPlayer3D
var active_station: Node3D
@onready var game: Node = get_parent()


func _ready() -> void:
	speaker = AudioStreamPlayer3D.new()
	speaker.name = "PersistentRecordAudio"
	speaker.process_mode = Node.PROCESS_MODE_ALWAYS
	speaker.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	speaker.unit_size = 3.0
	speaker.max_distance = 30.0
	speaker.panning_strength = 1.5
	add_child(speaker)
	speaker.finished.connect(_on_track_finished)


func bind_station(station: Node3D) -> void:
	active_station = station
	if is_instance_valid(active_station):
		var origin: Node3D = active_station.get_node_or_null("AudioOrigin")
		speaker.global_position = origin.global_position if origin != null else active_station.global_position
		speaker.volume_db = TRACK_GAIN_DB[track_index]
	else:
		speaker.volume_db = -80.0


func is_near_station() -> bool:
	if not is_instance_valid(active_station) or not is_instance_valid(game.player):
		return false
	var offset: Vector3 = game.player.global_position - active_station.global_position
	return Vector2(offset.x, offset.z).length() <= 2.05 and absf(offset.y) < 1.4


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not game.running or not is_instance_valid(game.player) or game.player.controls_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var code: Key = event.physical_keycode
	if code == KEY_0 or code == KEY_KP_0:
		get_viewport().set_input_as_handled()
		toggle_playback()
		return
	if not is_near_station():
		return
	if code == KEY_F:
		get_viewport().set_input_as_handled()
		toggle_playback()
	elif code == KEY_KP_ADD or code == KEY_PLUS or code == KEY_EQUAL:
		get_viewport().set_input_as_handled()
		step_track(1)
	elif code == KEY_KP_SUBTRACT or code == KEY_MINUS:
		get_viewport().set_input_as_handled()
		step_track(-1)


func toggle_playback() -> void:
	if speaker.stream_paused:
		speaker.stream_paused = false
		_notify("继续播放")
		return
	if speaker.playing:
		speaker.stream_paused = true
		_notify("已暂停")
		return
	if _load_track(track_index):
		speaker.play()
		_notify("正在播放")
	else:
		_notify("缺少音频文件")


func step_track(direction: int) -> void:
	var should_play: bool = speaker.playing and not speaker.stream_paused
	track_index = posmod(track_index + direction, TRACKS.size())
	speaker.stop()
	if _load_track(track_index):
		if should_play:
			speaker.play()
		_notify("正在播放" if should_play else "已选中")
	else:
		_notify("缺少音频文件")


func status_text() -> String:
	var state: String = "播放中" if speaker.playing and not speaker.stream_paused else "已暂停" if speaker.playing else "已停止"
	if not ResourceLoader.exists(TRACKS[track_index]):
		state = "待添加音频"
	return "%s · %s" % [TRACK_LABELS[track_index], state]


func _load_track(index: int) -> bool:
	if index < 0 or index >= BUNDLED_TRACKS.size():
		return false
	var stream: Resource = BUNDLED_TRACKS[index]
	if not stream is AudioStream:
		return false
	speaker.stream = stream
	if is_instance_valid(active_station):
		speaker.volume_db = TRACK_GAIN_DB[index]
	return true


func _on_track_finished() -> void:
	# The requested two-track playlist loops continuously across training levels.
	track_index = posmod(track_index + 1, TRACKS.size())
	if _load_track(track_index):
		speaker.stream_paused = false
		speaker.play()
		_notify("正在播放")
	else:
		_notify("缺少音频文件")


func _notify(action: String) -> void:
	if game.has_method("ability_feedback"):
		game.ability_feedback("%s：%s" % [TRACK_LABELS[track_index], action])
