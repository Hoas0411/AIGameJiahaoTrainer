extends Node

signal state_changed
signal transcribed(text: String)
var mode: int = 0
var listening: bool = false
var status: String = "麦克风关闭"
var rms: float = 0
var threshold: float = 0.012
var samples := PackedFloat32Array()
var preroll := PackedFloat32Array()
var silence: float = 0
var voiced: float = 0
var pending: Array[PackedByteArray] = []
var busy: bool = false
var capture: AudioEffectCapture
var rate: float = 48000
var last_transcript: String = ""
var quiet_seconds: float = 0
@onready var game: Node = get_parent()

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://voice.cfg") == OK:
		mode = clampi(config.get_value("voice", "mode", 0), 0, 2)
		threshold = clampf(config.get_value("voice", "threshold", 0.012), 0.003, 0.1)
	var index := AudioServer.get_bus_index("VoiceCapture")
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "VoiceCapture")
		capture = AudioEffectCapture.new()
		capture.buffer_length = 2.0
		AudioServer.add_bus_effect(index, capture)
	else:
		capture = AudioServer.get_bus_effect(index, 0)
	# Capture is pre-fader; muting prevents microphone feedback through speakers.
	AudioServer.set_bus_mute(index, true)
	$Microphone.bus = "VoiceCapture"
	rate = AudioServer.get_mix_rate()
	$Request.request_completed.connect(completed)
	update_status()

func set_mode(value: int) -> void:
	stop_listening(false)
	$Request.cancel_request()
	pending.clear()
	busy = false
	mode = clampi(value, 0, 2)
	var config := ConfigFile.new()
	config.set_value("voice", "mode", mode)
	config.set_value("voice", "threshold", threshold)
	config.save("user://voice.cfg")
	update_status()

func update_status() -> void:
	status = "麦克风关闭" if mode == 0 else ("按 T 开始 / 再按 T 停止" if mode == 1 else "长按 T 说话，松开发送")
	state_changed.emit()

func start_listening() -> void:
	if mode == 0 or listening:
		return
	listening = true
	samples.clear()
	preroll.clear()
	silence = 0
	voiced = 0
	quiet_seconds = 0
	capture.clear_buffer()
	$Microphone.play()
	status = "● 正在听 · 停顿后自动发给麦小鼠"
	state_changed.emit()

func stop_listening(send_last: bool = true) -> void:
	if listening and send_last:
		flush_utterance()
	listening = false
	$Microphone.stop()
	samples.clear()
	preroll.clear()
	if capture:
		capture.clear_buffer()
	update_status()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		stop_listening(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode != KEY_T or event.echo:
		return
	if not event.pressed and mode == 2 and listening:
		stop_listening()
		get_viewport().set_input_as_handled()
	elif event.pressed and mode > 0 and not game.player.controls_blocked and not get_tree().paused:
		if mode == 1 and listening:
			stop_listening()
		else:
			start_listening()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if listening and (get_tree().paused or not game.player.visible):
		stop_listening(false)
	if listening:
		quiet_seconds = quiet_seconds + delta if rms < threshold else 0
		if quiet_seconds > 8 and not busy:
			status = "未检测到声音 · 检查 Windows 默认麦克风和权限"
			state_changed.emit()
		while capture.get_frames_available() >= 1024:
			consume(capture.get_buffer(1024))
	if not busy and not pending.is_empty():
		var wav: PackedByteArray = pending.pop_front()
		busy = true
		status = "正在转文字…" + (" · 麦克风仍在听" if listening else "")
		state_changed.emit()
		var error: int = $Request.request_raw(game.get_node("Companion").service_url.get_base_dir() + "/transcribe", ["Content-Type: audio/wav"], HTTPClient.METHOD_POST, wav)
		if error != OK:
			busy = false
			status = "语音服务未连接；F7 检查 / 重连 AI"
			state_changed.emit()

func consume(frames: PackedVector2Array) -> void:
	var mono := PackedFloat32Array()
	var power: float = 0
	for frame in frames:
		var value: float = (frame.x + frame.y) * 0.5
		mono.append(value)
		power += value * value
	rms = sqrt(power / maxi(1, frames.size()))
	var duration: float = frames.size() / rate
	if rms >= threshold:
		if samples.is_empty():
			samples.append_array(preroll)
		voiced += duration
		silence = 0
	else:
		silence += duration
	if not samples.is_empty() or rms >= threshold:
		samples.append_array(mono)
	else:
		preroll.append_array(mono)
		if preroll.size() > int(rate * 0.2):
			preroll = preroll.slice(preroll.size() - int(rate * 0.2))
	if samples.size() >= int(rate * 10) or (silence > 0.7 and not samples.is_empty()):
		flush_utterance()

func flush_utterance() -> void:
	if voiced >= 0.18 and samples.size() >= int(rate * 0.25):
		if pending.size() < 3:
			pending.append(encode_wav(samples, rate))
		else:
			status = "语音队列已满，等麦小鼠回应后再说"
			state_changed.emit()
	samples.clear()
	preroll.clear()
	voiced = 0
	silence = 0

static func encode_wav(audio: PackedFloat32Array, source_rate: float) -> PackedByteArray:
	var count: int = mini(192000, int(audio.size() * 16000.0 / source_rate))
	var b := PackedByteArray()
	b.resize(44 + count * 2)
	for pair in [[0,"RIFF"],[8,"WAVE"],[12,"fmt "],[36,"data"]]:
		var bytes: PackedByteArray = pair[1].to_ascii_buffer()
		for i in 4:
			b[pair[0] + i] = bytes[i]
	b.encode_u32(4, b.size() - 8)
	b.encode_u32(16,16)
	b.encode_u16(20,1)
	b.encode_u16(22,1)
	b.encode_u32(24,16000)
	b.encode_u32(28,32000)
	b.encode_u16(32,2)
	b.encode_u16(34,16)
	b.encode_u32(40,count * 2)
	# Average each source interval, including fractional-rate input (e.g. 44.1kHz).
	for i in count:
		var start: int = int(i * source_rate / 16000.0)
		var end: int = mini(audio.size(), maxi(start + 1, int((i + 1) * source_rate / 16000.0)))
		var total: float = 0
		for j in range(start,end):
			total += audio[j]
		b.encode_u16(44 + i * 2, int(clampf(total / (end - start), -1, 1) * 32767) & 65535)
	return b

func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var parser := JSON.new()
	var data: Variant = parser.data if parser.parse(body.get_string_from_utf8()) == OK else null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not data is Dictionary:
		status = str(data.get("error", "语音识别失败")) if data is Dictionary else "语音服务无响应；F7 检查连接"
	elif not str(data.get("text", "")).strip_edges().is_empty():
		last_transcript = str(data.text).strip_edges()
		transcribed.emit(last_transcript)
		status = "已转文字并发送" + (" · 继续听" if listening else " · 麦克风已停")
	else:
		status = "没有识别到清晰语音" + (" · 继续听" if listening else "")
	state_changed.emit()
