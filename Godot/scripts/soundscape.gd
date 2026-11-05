extends Node3D
## Recovered: wood footsteps, the brief PRESENCE clip, and door creak.
## Original procedural audio: low mechanical room hum, phone ping, power-cut click.
## Sound positions are this opening's staging. There is no continuous horror score.

var player: BlackwebPlayer
var progression: Node
var assets: Dictionary = {}
var phone_position := Vector3.ZERO
var door_position := Vector3(-5.08, 1.5, 0.4)
var _room: AudioStreamPlayer
var _steps: AudioStreamPlayer3D
var _phone: AudioStreamPlayer3D
var _presence: AudioStreamPlayer3D
var _door: AudioStreamPlayer3D
var _event: AudioStreamPlayer
var _web_voice: AudioStreamPlayer
var _mara_warning: AudioStreamPlayer
var _phone_reply: AudioStreamPlayer
var _voice_test: AudioStreamPlayer
var _phone_dialogue: Dictionary = {}
var _phone_timer := 1.2
var _step_distance := 0.0
var _step_streams: Array[AudioStream] = []
var _step_index := 0
var _presence_remaining := 0.0
var _presence_started := false
var _recovering := false
var _stage := -1
var _recovered_audio: Dictionary = {}
var _missing_audio: Array[String] = []
var _web_voice_played := false
var _mara_warning_played := false
var _phone_reply_played := false
var _phone_clock_elapsed := 0.0
var _phone_clock_tick_usec := 0
const WEB_REVEAL_POSITION := Vector3(-1.6, 0.44, -2.0)
const PHONE_DIALOGUE_PATH := "res://data/phone_dialogue.json"
const DIALOGUE_BUS := &"Dialogue"
const WEB_VOICE_PATH := "res://assets/generated/luke_web_reveal_neural_v3.wav"
const MICA_WARNING_PATH := "res://assets/generated/mica_phone_warning_neural_v1.wav"
const PHONE_REPLY_PATH := "res://assets/generated/luke_mica_reply_neural_v1.wav"
const VOICE_TEST_PATH := "res://assets/generated/luke_voice_check_neural_v1.wav"
const STEP_PITCH := [0.985, 1.01, 0.995, 1.015]
const STEP_GAIN := [-0.6, 0.2, -0.2, 0.5]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_phone_dialogue()
	_ensure_dialogue_bus()
	_room = AudioStreamPlayer.new()
	_room.name = "OriginalMechanicalRoomHum"
	_room.volume_db = -24.0
	_room.stream = _mechanical_hum()
	add_child(_room)
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "RecoveredWoodFootsteps"
	_steps.volume_db = -17.0
	_steps.unit_size = 1.8
	_steps.max_distance = 12.0
	add_child(_steps)
	for sound_path in assets.get("steps", []):
		var stream: AudioStream = _load_sound(str(sound_path), "wood_footstep")
		if stream != null: _step_streams.append(stream)
	_phone = AudioStreamPlayer3D.new()
	_phone.name = "OriginalPhonePing"
	_phone.position = phone_position
	_phone.volume_db = -17.0
	_phone.unit_size = 2.0
	_phone.max_distance = 18.0
	_phone.stream = _tone(0.42, 520.0, 0.20)
	add_child(_phone)
	_presence = AudioStreamPlayer3D.new()
	_presence.name = "RecoveredPresenceCue"
	# A fixed source in the house, rather than a sound attached to the listener.
	_presence.position = phone_position + Vector3(3.5, 0.8, 1.8)
	_presence.volume_db = -28.0
	_presence.unit_size = 3.0
	_presence.max_distance = 22.0
	_presence.stream = _load_sound(str(assets.get("presence", "")), "presence")
	add_child(_presence)
	_door = AudioStreamPlayer3D.new()
	_door.name = "RecoveredFrontDoor"
	_door.position = door_position
	_door.volume_db = -19.0
	_door.unit_size = 2.0
	_door.max_distance = 16.0
	_door.stream = _load_sound(str(assets.get("door", "")), "door")
	add_child(_door)
	_event = AudioStreamPlayer.new()
	_event.name = "OriginalPowerCutClick"
	_event.volume_db = -25.0
	_event.stream = _tone(0.12, 55.0, 0.45)
	add_child(_event)
	_web_voice = AudioStreamPlayer.new()
	_web_voice.name = "LukeWebRevealVoice"
	_web_voice.bus = DIALOGUE_BUS
	_web_voice.volume_db = 0.0
	_web_voice.stream = _load_voice(_dialogue_path("web_reaction", WEB_VOICE_PATH))
	add_child(_web_voice)
	_mara_warning = AudioStreamPlayer.new()
	# Keep the private legacy field for existing QA callers; the caller is Mica.
	_mara_warning.name = "MicaPhoneWarningVoice"
	_mara_warning.bus = DIALOGUE_BUS
	_mara_warning.volume_db = 0.0
	_mara_warning.stream = _load_voice(_dialogue_path("warning", MICA_WARNING_PATH), "Mica phone warning")
	add_child(_mara_warning)
	_phone_reply = AudioStreamPlayer.new()
	_phone_reply.name = "LukePhoneReplyVoice"
	_phone_reply.bus = DIALOGUE_BUS
	_phone_reply.volume_db = 0.0
	_phone_reply.stream = _load_voice(_dialogue_path("reply", PHONE_REPLY_PATH), "Luke phone reply")
	add_child(_phone_reply)
	_voice_test = AudioStreamPlayer.new()
	_voice_test.name = "MenuVoiceCheck"
	_voice_test.bus = DIALOGUE_BUS
	_voice_test.volume_db = 0.0
	_voice_test.process_mode = Node.PROCESS_MODE_ALWAYS
	_voice_test.stream = _load_voice(_dialogue_path("voice_test", VOICE_TEST_PATH), "voice check")
	add_child(_voice_test)
	_voice_test.finished.connect(stop_voice_test)
	if is_instance_valid(player):
		player.recovery_changed.connect(_on_recovery)
		_recovering = player.is_recovering()
	if is_instance_valid(progression):
		progression.stage_changed.connect(_stage_changed)
		if progression.has_signal("checkpoint_restored"):
			progression.checkpoint_restored.connect(_checkpoint_restored)
		_stage_changed(int(progression.stage), true)
	set_meta("audio_provenance", get_audio_provenance())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		# A paused menu must not count toward the real-time message clock.
		_phone_clock_tick_usec = Time.get_ticks_usec()
	if what == NOTIFICATION_UNPAUSED:
		stop_voice_test()

func _load_phone_dialogue() -> void:
	if FileAccess.file_exists(PHONE_DIALOGUE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PHONE_DIALOGUE_PATH))
		if parsed is Dictionary:
			_phone_dialogue = parsed

func _dialogue_path(role: String, fallback: String) -> String:
	return str(_phone_dialogue.get(role, {}).get("path", fallback))

func _ensure_dialogue_bus() -> void:
	if AudioServer.get_bus_index(DIALOGUE_BUS) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, DIALOGUE_BUS)
	AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_db(index, 0.0)
	# Existing user bus settings are preserved; this only creates our new bus.

func play_voice_test() -> bool:
	if not is_instance_valid(_voice_test) or _voice_test.stream == null or _voice_test.playing: return false
	# Menu-only: never interrupt an active gameplay line or consume its once flag.
	if not get_tree().paused and is_instance_valid(player) and player.active: return false
	for channel in [_mara_warning, _phone_reply, _web_voice]:
		if is_instance_valid(channel): channel.stream_paused = true
	_voice_test.play()
	return true

func stop_voice_test() -> void:
	if is_instance_valid(_voice_test): _voice_test.stop()
	for channel in [_mara_warning, _phone_reply, _web_voice]:
		if is_instance_valid(channel): channel.stream_paused = false

func get_audio_status() -> Dictionary:
	var buses: Array[Dictionary] = []
	for index in range(AudioServer.bus_count):
		buses.append({"name": AudioServer.get_bus_name(index), "send": AudioServer.get_bus_send(index), "volume_db": AudioServer.get_bus_volume_db(index), "muted": AudioServer.is_bus_mute(index), "solo": AudioServer.is_bus_solo(index), "peak_left_db": AudioServer.get_bus_peak_volume_left_db(index, 0), "peak_right_db": AudioServer.get_bus_peak_volume_right_db(index, 0)})
	return {"driver": AudioServer.get_driver_name(), "output_device": AudioServer.output_device, "output_devices": AudioServer.get_output_device_list(), "mix_rate": AudioServer.get_mix_rate(), "output_latency_seconds": AudioServer.get_output_latency(), "buses": buses, "dialogue_loaded": is_instance_valid(_mara_warning) and _mara_warning.stream != null and is_instance_valid(_phone_reply) and _phone_reply.stream != null, "voice_test_loaded": is_instance_valid(_voice_test) and _voice_test.stream != null, "voice_test_playing": is_instance_valid(_voice_test) and _voice_test.playing, "missing": _missing_audio.duplicate()}

func _load_sound(sound_path: String, role: String) -> AudioStream:
	if not sound_path.is_empty() and ResourceLoader.exists(sound_path):
		var loaded: AudioStream = load(sound_path) as AudioStream
		if loaded != null:
			if not _recovered_audio.has(role): _recovered_audio[role] = []
			_recovered_audio[role].append(sound_path)
			# Avoid changing shared imported WAVs or inheriting an accidental loop.
			if loaded is AudioStreamWAV:
				var one_shot: AudioStreamWAV = loaded.duplicate(false) as AudioStreamWAV
				one_shot.loop_mode = AudioStreamWAV.LOOP_DISABLED
				return one_shot
			return loaded
	_missing_audio.append(role + ": " + (sound_path if not sound_path.is_empty() else "path not supplied"))
	return null

func _load_voice(sound_path: String, role: String = "Luke web reveal neural voice") -> AudioStream:
	if ResourceLoader.exists(sound_path):
		var stream := load(sound_path) as AudioStream
		if stream is AudioStreamWAV:
			var one_shot := stream.duplicate(false) as AudioStreamWAV
			one_shot.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return one_shot
		if stream != null: return stream
	_missing_audio.append(role + ": " + sound_path)
	return null

func get_audio_provenance() -> Dictionary:
	return {"recovered": _recovered_audio.duplicate(true), "original_procedural": ["low mechanical room hum", "phone notification ping", "power-cut click"], "prototype_voice": {"path": _dialogue_path("web_reaction", WEB_VOICE_PATH), "source": "Locally generated Kokoro-82M neural voice, am_michael; synthetic placeholder, not an actor performance"}, "phone_dialogue": {"mica_path": _dialogue_path("warning", MICA_WARNING_PATH), "luke_path": _dialogue_path("reply", PHONE_REPLY_PATH), "timeline": PHONE_DIALOGUE_PATH, "source": "Local Kokoro-82M stock synthetic voices: af_heart and am_michael; no voice cloning", "policy": "Once per message attempt, aligned to message elapsed time and subtitle slots, no overlap with the web reaction"}, "missing": _missing_audio.duplicate(), "presence_policy": "Spatial, quiet, once per PRESENCE entry, at most 8 active seconds, stopped on POWER_LOSS.", "footstep_policy": "Recovered wood samples, grounded velocity-based stride distance, deterministic mild pitch/gain sequence.", "continuous_horror_score": false}

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(progression): return
	if _recovering or player.is_recovering(): return
	if not player.active:
		_phone_clock_tick_usec = Time.get_ticks_usec()
		_steps.stop()
		_step_distance = 0.0
		if _mara_warning.playing:
			_mara_warning.stop()
			_mara_warning_played = false
		if _phone_reply.playing:
			_phone_reply.stop()
			_phone_reply_played = false
		return # A door opened during departure may finish naturally.
	if _voice_test.playing: stop_voice_test()
	if _stage == progression.Stage.MESSAGE:
		_synchronize_phone_clock()
		play_mara_warning()
		play_phone_reply()
		# The recording ends naturally. Its complete duration is in the shared
		# timeline; never cut it at a previous recording's hardcoded boundary.
		# Some drivers retain playing=true for a frame after the final sample.
		if _mara_warning.playing and _mara_warning.get_playback_position() >= _mara_warning.stream.get_length():
			_mara_warning.stop()
	if not _web_voice_played and _stage >= progression.Stage.PREPARATION and _stage < progression.Stage.POWER_LOSS and player.global_position.distance_to(WEB_REVEAL_POSITION) < 2.3:
		play_web_reveal_voice()
	if _stage < progression.Stage.POWER_LOSS and not _room.playing: _room.play()
	if _stage == progression.Stage.PRESENCE and _presence_remaining > 0.0:
		if not _presence_started and _presence.stream != null:
			_presence.play()
			_presence_started = true
		_presence_remaining = maxf(0.0, _presence_remaining - delta)
		if _presence_remaining <= 0.0: _presence.stop()
	_phone_timer -= delta
	if _stage == progression.Stage.NORMAL and _phone_timer <= 0.0:
		_phone.play()
		_phone_timer = 6.0
	_steps.global_position = player.global_position + Vector3.UP * 0.1
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if not player.is_on_floor() or horizontal_speed <= 0.5 or _step_streams.is_empty():
		_step_distance = 0.0
		return
	# Cadence advances only from grounded movement, never from a running timer.
	_step_distance += horizontal_speed * minf(delta, 0.1)
	var stride: float = lerpf(1.35, 1.8, clampf((horizontal_speed - 2.3) / 3.0, 0.0, 1.0))
	if _step_distance >= stride:
		_step_distance = fmod(_step_distance, stride)
		_steps.stream = _step_streams[_step_index % _step_streams.size()]
		_steps.pitch_scale = float(STEP_PITCH[_step_index % STEP_PITCH.size()])
		_steps.volume_db = -17.0 + float(STEP_GAIN[_step_index % STEP_GAIN.size()])
		_step_index += 1
		_steps.play()

func play_web_reveal_voice() -> bool:
	if _web_voice_played or not is_instance_valid(_web_voice) or _web_voice.stream == null or _recovering or get_tree().paused:
		return false
	if not is_instance_valid(progression) or _stage < progression.Stage.PREPARATION or _stage >= progression.Stage.POWER_LOSS or _mara_warning.playing or _phone_reply.playing:
		return false
	_web_voice_played = true
	_web_voice.play()
	if is_instance_valid(progression):
		progression.show_notice(str(_phone_dialogue.get("web_reaction", {}).get("subtitle", "Luke: Mica... these webs were not here yesterday.")), maxf(3.2, _web_voice.stream.get_length() + 0.2))
	return true

func _synchronize_phone_clock() -> void:
	var now := Time.get_ticks_usec()
	var wall_delta := maxf(0.0, float(now - _phone_clock_tick_usec) / 1000000.0) if _phone_clock_tick_usec > 0 else 0.0
	_phone_clock_tick_usec = now
	_phone_clock_elapsed += wall_delta
	# Frame delta can clamp during a GPU/readback stall while speech keeps
	# playing. Catch the subtitle clock up monotonically, including the silent
	# disconnected beat; never seek speech backward or replay an old line.
	var spoken_clock := 0.0
	if _mara_warning.playing:
		spoken_clock = _mara_warning.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	elif _phone_reply.playing:
		spoken_clock = _phone_reply_start() + _phone_reply.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	_phone_clock_elapsed = maxf(_phone_clock_elapsed, spoken_clock)
	if _phone_clock_elapsed > progression._elapsed + 0.04:
		progression._elapsed = _phone_clock_elapsed
		progression._update_message()

func _phone_reply_start() -> float:
	if _phone_dialogue.has("reply"):
		return float(_phone_dialogue.reply.get("start_seconds", 0.0))
	var start := 0.0
	for index in range(mini(4, progression.mara_durations.size())):
		start += maxf(0.5, float(progression.mara_durations[index]))
	return start

func _dialogue_can_play() -> bool:
	return is_instance_valid(player) and player.active and is_instance_valid(progression) and _stage == progression.Stage.MESSAGE and not _recovering and not player.is_recovering() and not get_tree().paused

func play_mara_warning() -> bool:
	if not _dialogue_can_play() or _mara_warning_played or not is_instance_valid(_mara_warning) or _mara_warning.stream == null:
		return false
	var elapsed: float = progression._elapsed
	if elapsed >= _mara_warning.stream.get_length():
		_mara_warning_played = true
		return false
	# The generated takes follow the shared JSON subtitle boundaries.
	# Seeking preserves sync after a late active frame.
	_web_voice.stop()
	_mara_warning_played = true
	_mara_warning.play(maxf(0.0, elapsed))
	return true

func play_phone_reply() -> bool:
	if not _dialogue_can_play() or _phone_reply_played or not is_instance_valid(_phone_reply) or _phone_reply.stream == null:
		return false
	var offset: float = progression._elapsed - _phone_reply_start()
	if offset < 0.0: return false
	_phone_reply_played = true
	if offset >= _phone_reply.stream.get_length(): return false
	_mara_warning.stop()
	_web_voice.stop()
	_phone_reply.play(offset)
	return true

func play_door() -> bool:
	if not is_instance_valid(_door) or _door.stream == null or get_tree().paused or _recovering or (is_instance_valid(player) and player.is_recovering()): return false
	_door.position = door_position
	_door.play()
	return true

func _stage_changed(stage: int, restoring: bool = false) -> void:
	var previous: int = _stage
	_stage = stage
	if previous != stage or restoring:
		_phone_clock_elapsed = maxf(0.0, progression._elapsed)
	_phone_clock_tick_usec = Time.get_ticks_usec()
	if stage == progression.Stage.NORMAL:
		_mara_warning_played = false
		_phone_reply_played = false
	if stage != progression.Stage.MESSAGE:
		_mara_warning.stop()
		_phone_reply.stop()
	else:
		_web_voice.stop()
	if stage != progression.Stage.NORMAL: _phone.stop()
	else: _phone_timer = 1.2
	_presence.stop()
	_presence_remaining = 8.0 if stage == progression.Stage.PRESENCE else 0.0
	_presence_started = false
	if stage >= progression.Stage.POWER_LOSS:
		_room.stop() # The house loses its mechanical hum; no music replaces it.
	else:
		_room.volume_db = -27.0 if stage in [progression.Stage.MESSAGE, progression.Stage.PRESENCE] else -24.0
	if stage == progression.Stage.POWER_LOSS and previous == progression.Stage.PRESENCE and not restoring and not _recovering:
		_event.play()
	if stage == progression.Stage.COMPLETE:
		_phone.stop()
		_steps.stop()
		_presence.stop()
		_room.stop()
		_event.stop()
		_door.stop()
		_web_voice.stop()
		_mara_warning.stop()
		_phone_reply.stop()

func _on_recovery(recovering: bool) -> void:
	_recovering = recovering
	_phone_clock_tick_usec = Time.get_ticks_usec()
	_room.stream_paused = recovering
	_presence.stream_paused = recovering
	_steps.stop()
	_phone.stop()
	_event.stop()
	_door.stop()
	_web_voice.stop()
	_mara_warning.stop()
	_phone_reply.stop()
	_step_distance = 0.0

func _checkpoint_restored() -> void:
	_phone_clock_elapsed = maxf(0.0, progression._elapsed)
	_phone_clock_tick_usec = Time.get_ticks_usec()
	_step_index = 0
	_step_distance = 0.0
	_phone_timer = 1.2
	_presence.stop()
	_presence_started = false
	_door.stop()
	_event.stop()
	_mara_warning.stop()
	_phone_reply.stop()
	# A restored MESSAGE checkpoint restarts its subtitle clock from zero.
	# Permit one fresh take for that attempt, never a duplicate stage signal.
	if progression.stage in [progression.Stage.NORMAL, progression.Stage.MESSAGE]:
		_mara_warning_played = false
		_phone_reply_played = false
	# The immediately following stage_changed signal restores the correct state.

func _mechanical_hum() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 4
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(rate)
		# Integer cycles over four seconds make this original loop seamless.
		var motor: float = sin(TAU * 60.0 * t) * 0.60 + sin(TAU * 120.0 * t) * 0.20 + sin(TAU * 180.0 * t) * 0.08
		var fan: float = sin(TAU * 59.75 * t) * 0.06 + sin(TAU * 240.0 * t) * 0.025
		var modulation: float = 0.94 + 0.06 * cos(TAU * 0.5 * t)
		bytes.encode_s16(i * 2, int((motor + fan) * modulation * 0.16 * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = count
	return sound

func _tone(duration: float, frequency: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / rate
		var envelope := minf(t * 40.0, 1.0) * pow(maxf(0.0, 1.0 - t / duration), 2.0)
		var pulse := sin(TAU * frequency * t) * 0.65 + sin(TAU * frequency * 1.5 * t) * 0.35
		bytes.encode_s16(i * 2, int(clampf(pulse * envelope * amplitude, -1.0, 1.0) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
