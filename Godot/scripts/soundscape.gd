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
const WEB_REVEAL_POSITION := Vector3(-1.6, 0.44, -2.0)
const WEB_VOICE_PATH := "res://assets/generated/luke_web_reveal_neural_v2.wav"
const STEP_PITCH := [0.985, 1.01, 0.995, 1.015]
const STEP_GAIN := [-0.6, 0.2, -0.2, 0.5]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	_web_voice.volume_db = -7.0
	_web_voice.stream = _load_voice(WEB_VOICE_PATH)
	add_child(_web_voice)
	if is_instance_valid(player):
		player.recovery_changed.connect(_on_recovery)
		_recovering = player.is_recovering()
	if is_instance_valid(progression):
		progression.stage_changed.connect(_stage_changed)
		if progression.has_signal("checkpoint_restored"):
			progression.checkpoint_restored.connect(_checkpoint_restored)
		_stage_changed(int(progression.stage), true)
	set_meta("audio_provenance", get_audio_provenance())

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

func _load_voice(sound_path: String) -> AudioStream:
	if ResourceLoader.exists(sound_path):
		var stream := load(sound_path) as AudioStream
		if stream is AudioStreamWAV:
			var one_shot := stream.duplicate(false) as AudioStreamWAV
			one_shot.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return one_shot
		if stream != null: return stream
	_missing_audio.append("Luke web reveal neural voice: " + sound_path)
	return null

func get_audio_provenance() -> Dictionary:
	return {"recovered": _recovered_audio.duplicate(true), "original_procedural": ["low mechanical room hum", "phone notification ping", "power-cut click"], "prototype_voice": {"path": WEB_VOICE_PATH, "source": "Locally generated Kokoro-82M neural voice, am_michael; synthetic placeholder, not an actor performance"}, "missing": _missing_audio.duplicate(), "presence_policy": "Spatial, quiet, once per PRESENCE entry, at most 8 active seconds, stopped on POWER_LOSS.", "footstep_policy": "Recovered wood samples, grounded velocity-based stride distance, deterministic mild pitch/gain sequence.", "continuous_horror_score": false}

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(progression): return
	if _recovering or player.is_recovering(): return
	if not player.active:
		_steps.stop()
		_step_distance = 0.0
		return # A door opened during departure may finish naturally.
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
	_web_voice_played = true
	_web_voice.play()
	if is_instance_valid(progression):
		progression.show_notice("Luke: Mara... these webs were not here yesterday.", 3.2)
	return true

func play_door() -> bool:
	if not is_instance_valid(_door) or _door.stream == null or get_tree().paused or _recovering or (is_instance_valid(player) and player.is_recovering()): return false
	_door.position = door_position
	_door.play()
	return true

func _stage_changed(stage: int, restoring: bool = false) -> void:
	var previous: int = _stage
	_stage = stage
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

func _on_recovery(recovering: bool) -> void:
	_recovering = recovering
	_room.stream_paused = recovering
	_presence.stream_paused = recovering
	_steps.stop()
	_phone.stop()
	_event.stop()
	_door.stop()
	_web_voice.stop()
	_step_distance = 0.0

func _checkpoint_restored() -> void:
	_step_index = 0
	_step_distance = 0.0
	_phone_timer = 1.2
	_presence.stop()
	_presence_started = false
	_door.stop()
	_event.stop()
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
