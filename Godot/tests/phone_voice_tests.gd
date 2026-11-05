extends SceneTree
## Real-time subtitle/audio test. Run without --headless: Dummy audio does not
## provide a real hardware playback clock for the strict synchronization checks.

const PlayerScript = preload("res://scripts/player.gd")
const ProgressionScript = preload("res://scripts/progression.gd")
const SoundScript = preload("res://scripts/soundscape.gd")
class AudioTestPlayer extends BlackwebPlayer:
	# The audio integration uses the real player API, without loading/rendering
	# held-model assets irrelevant to an audio clock and menu routing test.
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
var timing_samples: Array[Dictionary] = []
var progression: BlackwebProgression
var player: BlackwebPlayer
var sounds: Node3D
var timeline: Dictionary
var capture: AudioEffectCapture
var signal_peak := 0.0
var signal_squared := 0.0
var signal_samples := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	rows.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _until(time: float) -> void:
	var deadline := Time.get_ticks_msec() + 18000
	while progression.stage == progression.Stage.MESSAGE and progression._elapsed < time and Time.get_ticks_msec() < deadline:
		_drain_signal()
		await process_frame

func _drain_signal() -> void:
	for frame in capture.get_buffer(capture.get_frames_available()):
		signal_peak = maxf(signal_peak, maxf(absf(frame.x), absf(frame.y)))
		signal_squared += frame.x * frame.x + frame.y * frame.y
		signal_samples += 2

func _run() -> void:
	# This isolated fixture bypasses main._install_input(), but its real player
	# still receives native window events while audio is under observation.
	for action in ["interact", "flashlight", "hotbar_1", "hotbar_2", "hotbar_3"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	timeline = JSON.parse_string(FileAccess.get_file_as_string(SoundScript.PHONE_DIALOGUE_PATH))
	var second: float = timeline.durations[0]
	var third: float = second + timeline.durations[1]
	var gap_start: float = timeline.warning.duration_seconds
	var reply_start: float = timeline.reply.start_seconds
	var message_end: float = reply_start + timeline.durations[4]
	var stage := Node3D.new()
	root.add_child(stage)
	progression = ProgressionScript.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	stage.add_child(progression)
	progression.set_process(false)
	player = AudioTestPlayer.new()
	player.progression = progression
	stage.add_child(player)
	player.set_physics_process(false)
	player.global_position = SoundScript.WEB_REVEAL_POSITION
	progression.player = player
	sounds = SoundScript.new()
	sounds.player = player
	sounds.progression = progression
	stage.add_child(sounds)
	await process_frame
	var mara: AudioStreamWAV = sounds._mara_warning.stream
	var reply: AudioStreamWAV = sounds._phone_reply.stream
	_check(mara != null and reply != null and mara.mix_rate == 24000 and reply.mix_rate == 24000, "Both local neural WAVs import as 24 kHz audio")
	_check(mara.format == AudioStreamWAV.FORMAT_16_BITS and not mara.stereo and reply.format == AudioStreamWAV.FORMAT_16_BITS and not reply.stereo, "Dialogue uses compact mono PCM16")
	_check(mara.loop_mode == AudioStreamWAV.LOOP_DISABLED and reply.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Neither spoken line inherits an audio loop")
	_check(is_equal_approx(mara.get_length(), timeline.warning.duration_seconds) and is_equal_approx(reply.get_length(), timeline.reply.duration_seconds), "Mica and Luke match the shared JSON durations without trimming words")
	_check(progression.mara_lines == Array(timeline.lines) and progression.mara_durations == Array(timeline.durations), "Real progression reads the shared Mica lines and timings")
	_check(timeline.caller == "Mica" and "plant" in timeline.lines[2] and not "Mara" in JSON.stringify(timeline.lines), "Phone hint ends at plant with the new caller name")
	var dialogue_bus := AudioServer.get_bus_index(SoundScript.DIALOGUE_BUS)
	_check(dialogue_bus > 0 and AudioServer.get_bus_send(dialogue_bus) == &"Master" and not AudioServer.is_bus_mute(dialogue_bus) and is_zero_approx(AudioServer.get_bus_volume_db(dialogue_bus)), "Dialogue bus routes unmuted at unity to Master")
	_check(sounds._mara_warning.bus == SoundScript.DIALOGUE_BUS and is_zero_approx(sounds._mara_warning.volume_db) and sounds._phone_reply.bus == SoundScript.DIALOGUE_BUS and sounds._web_voice.bus == SoundScript.DIALOGUE_BUS, "All story voices share the audible dialogue route")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(dialogue_bus, capture)
	paused = true
	_check(sounds.play_voice_test() and not sounds.play_voice_test(), "Settings voice check starts once while paused")
	await create_timer(.8, true).timeout
	_drain_signal()
	_check(sounds._voice_test.playing and signal_samples > 1000 and signal_peak > .02, "Paused voice check produces nonzero mixed PCM")
	_check(not sounds._mara_warning_played and not sounds._phone_reply_played and progression.stage == progression.Stage.NORMAL, "Voice check does not consume or advance the story")
	paused = false
	_check(not sounds._voice_test.playing, "Resuming stops the settings sample")
	_check(not sounds.play_mara_warning() and not sounds.play_phone_reply(), "Dialogue cannot play before the phone interaction")
	_check(progression.interact(&"phone") and progression.stage == progression.Stage.MESSAGE, "The real phone interaction starts Mica's message")
	await process_frame
	_check(not sounds._mara_warning.playing and not sounds._mara_warning_played, "Inactive player/menu state does not start dialogue")
	player.active = true
	progression.set_process(true)
	await _until(0.10)
	_check(sounds._mara_warning.playing and sounds._mara_warning_played and progression.subtitle == progression.mara_lines[0], "Mica starts with her first matching subtitle on active play")
	_check(not sounds.play_mara_warning() and not sounds.play_web_reveal_voice() and not sounds.play_voice_test(), "Repeated warning, web reaction and active-game voice check cannot overlap")
	sounds._stage_changed(progression.Stage.MESSAGE)
	_check(not sounds.play_mara_warning(), "A duplicated MESSAGE signal cannot restart the recording")
	var before_pause := progression._elapsed
	var audio_before: float = sounds._mara_warning.get_playback_position()
	paused = true
	await create_timer(0.15, true).timeout
	_check(is_equal_approx(progression._elapsed, before_pause) and absf(sounds._mara_warning.get_playback_position() - audio_before) < 0.12 and not sounds.play_phone_reply(), "Pausing freezes subtitle and dialogue clocks together")
	paused = false
	await _until(second + .15)
	_record_timing("second_line")
	_check(progression.subtitle == progression.mara_lines[1] and absf(sounds._mara_warning.get_playback_position() - progression._elapsed) < 0.25, "Vault-key subtitle and spoken track stay synchronized")
	await _until(third + .15)
	_record_timing("third_line")
	_check(progression.subtitle == progression.mara_lines[2] and absf(sounds._mara_warning.get_playback_position() - progression._elapsed) < 0.25, "The interrupted warning stays synchronized at the third line")
	# The dummy headless audio driver can stall with the main thread. Check
	# normal clock alignment first, then verify real-time subtitle catch-up.
	var before_stall := progression._elapsed
	OS.delay_msec(400)
	await process_frame
	await process_frame
	_check(progression._elapsed >= before_stall - .02 and absf(sounds._mara_warning.get_playback_position() - progression._elapsed) < .25 and progression.stage == progression.Stage.MESSAGE, "A blocked render frame follows the real mixer without skipping unfinished speech")
	await _until(gap_start + .18)
	_record_timing("signal_lost")
	_check(progression.subtitle == "[Connection lost]" and not sounds._mara_warning.playing and not sounds._phone_reply.playing, "Connection-loss beat has no overlapping spoken line")
	var gap_before_stall := progression._elapsed
	OS.delay_msec(350)
	await process_frame
	await process_frame
	_check(progression._elapsed >= gap_before_stall + 0.28 and progression.subtitle == "[Connection lost]" and not sounds._phone_reply.playing, "The silent connection-loss gap also catches up after a stall")
	await _until(reply_start + .15)
	_check(progression.subtitle == progression.mara_lines[4] and sounds._phone_reply.playing and sounds._phone_reply_played and not sounds._mara_warning.playing, "Luke's reply starts under his subtitle after the phone drops")
	_check(absf(sounds._phone_reply.get_playback_position() - (progression._elapsed - reply_start)) < 0.25 and not sounds.play_phone_reply(), "Luke's reply uses the shared seek offset and cannot duplicate")
	await _until(message_end + .1)
	for frame in range(3): await process_frame
	_check(progression.stage == progression.Stage.PREPARATION and not sounds._web_voice_played and not sounds._phone_reply.playing and not sounds._mara_warning.playing, "The call ends in a quiet exploration beat before Luke's web reaction")
	await create_timer(4.1).timeout
	_check(progression.stage == progression.Stage.PREPARATION and sounds._web_voice_played, "The web reaction follows the four-second post-call breathing room")
	_check("Mica" in progression.notice and not "Mara" in progression.notice, "Web reaction also uses Mica in its subtitle")
	progression.set_process(false)
	var message_save := {"version": 1, "stage": progression.Stage.MESSAGE, "warning_heard": false, "has_flashlight": false, "has_keys": false, "encounter_survived": false, "departed": false}
	player.active = false
	progression.restore_snapshot(message_save)
	progression._elapsed = second + .15
	progression._update_message()
	sounds._process(0.0)
	_check(not sounds._mara_warning.playing, "Restored message remains silent while the player is inactive")
	player.active = true
	sounds._process(0.0)
	_check(sounds._mara_warning.playing and absf(sounds._mara_warning.get_playback_position() - progression._elapsed) < 0.25 and progression.subtitle == progression.mara_lines[1], "Late activation seeks to the current subtitle instead of restarting old words")
	player._recovering = true
	player.recovery_changed.emit(true)
	_check(not sounds._mara_warning.playing and not sounds._phone_reply.playing and not sounds._web_voice.playing, "Player recovery stops every spoken channel")
	player._recovering = false
	player.recovery_changed.emit(false)
	progression.restore_snapshot(message_save)
	sounds._process(0.0)
	_check(sounds._mara_warning.playing and progression._elapsed == 0.0 and not sounds.play_mara_warning(), "Restoring a message checkpoint permits one synchronized fresh attempt")
	progression._elapsed = message_end + 2.0
	progression._update_message()
	_check(progression.stage == progression.Stage.MESSAGE and progression.mara_lines.slice(0, 3).has(progression.subtitle) and sounds._mara_warning.playing and not sounds._phone_reply.playing, "A clock leap cannot cut Mica's recording or overlap Luke's reply")
	_check(progression._elapsed < gap_start and sounds._phone_clock_elapsed < gap_start, "Mixer delay is discarded before starting the full disconnect beat")
	# Simulate a backend that accepts playback but stops advancing. This is a
	# bounded failure fallback, distinct from a muted stream that still advances.
	sounds._mara_warning.stream_paused = true
	await create_timer(3.3).timeout
	_check(not sounds._mara_warning.playing and sounds.get_audio_status().missing.has("Phone playback stopped advancing; continuing the readable subtitle timeline"), "An audio backend stalled for three seconds cannot trap story progression")
	sounds._mara_warning.stream_paused = false
	progression._set_stage(progression.Stage.COMPLETE)
	_check(not sounds._mara_warning.playing and not sounds._phone_reply.playing and not sounds._web_voice.playing, "Departure stops all dialogue")
	_drain_signal()
	_check(signal_peak > .05 and signal_peak < 1 and signal_samples > 24000, "Dialogue mix contains sustained unclipped measured speech")
	var evidence_path := ProjectSettings.globalize_path("res://").path_join("../Evidence/mica-phone-voice-test-report.json")
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "real-time Mica phone subtitle/audio synchronization and PCM routing", "display_driver": DisplayServer.get_name(), "audio_status": sounds.get_audio_status(), "checks": checks, "failures": failures, "mica_seconds": mara.get_length(), "luke_seconds": reply.get_length(), "mixed_signal_peak": signal_peak, "mixed_signal_rms": sqrt(signal_squared / maxf(1, signal_samples)), "mixed_signal_samples": signal_samples, "limitations": "PCM and mixer evidence cannot establish sound heard at the physical user output.", "timing_samples": timing_samples, "results": rows}, "  "))
	file.close()
	print("Phone voice: %d checks, %d failures" % [checks, failures])
	sounds.set_process(false)
	_stop_audio(stage)
	await create_timer(.12, true).timeout
	print("PHONE_TEARDOWN audio stopped")
	AudioServer.remove_bus_effect(dialogue_bus, 0)
	print("PHONE_TEARDOWN capture effect removed")
	stage.queue_free()
	await process_frame
	print("PHONE_TEARDOWN fixture freed")
	await create_timer(.2, true).timeout
	quit(0 if failures == 0 else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): _stop_audio(child)

func _record_timing(label: String) -> void:
	var sample := {"label": label, "elapsed": progression._elapsed, "subtitle": progression.subtitle, "mara_position": sounds._mara_warning.get_playback_position(), "mara_playing": sounds._mara_warning.playing}
	timing_samples.append(sample)
	print("PHONE_SYNC ", JSON.stringify(sample))
