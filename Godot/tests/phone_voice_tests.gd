extends SceneTree
## Real-time subtitle/audio test. Run without --headless: Dummy audio does not
## provide a real hardware playback clock for the strict synchronization checks.

const PlayerScript = preload("res://scripts/player.gd")
const ProgressionScript = preload("res://scripts/progression.gd")
const SoundScript = preload("res://scripts/soundscape.gd")
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
var timing_samples: Array[Dictionary] = []
var progression: BlackwebProgression
var player: BlackwebPlayer
var sounds: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	rows.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _until(time: float) -> void:
	while progression.stage == progression.Stage.MESSAGE and progression._elapsed < time:
		await process_frame

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	progression = ProgressionScript.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	stage.add_child(progression)
	progression.set_process(false)
	player = PlayerScript.new()
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
	_check(is_equal_approx(mara.get_length(), 11.5) and reply.get_length() < 3.0, "Mara and Luke fit the existing subtitle slots without trimming words")
	_check(not sounds.play_mara_warning() and not sounds.play_phone_reply(), "Dialogue cannot play before the phone interaction")
	_check(progression.interact(&"phone") and progression.stage == progression.Stage.MESSAGE, "The real phone interaction starts Mara's message")
	await process_frame
	_check(not sounds._mara_warning.playing and not sounds._mara_warning_played, "Inactive player/menu state does not start dialogue")
	player.active = true
	progression.set_process(true)
	await _until(0.10)
	_check(sounds._mara_warning.playing and sounds._mara_warning_played and progression.subtitle == progression.mara_lines[0], "Mara starts with her first matching subtitle on active play")
	_check(not sounds.play_mara_warning() and not sounds.play_web_reveal_voice(), "Repeated warning calls and the later Luke reaction are rejected during the message")
	sounds._stage_changed(progression.Stage.MESSAGE)
	_check(not sounds.play_mara_warning(), "A duplicated MESSAGE signal cannot restart the recording")
	var before_pause := progression._elapsed
	var audio_before: float = sounds._mara_warning.get_playback_position()
	paused = true
	await create_timer(0.15, true).timeout
	_check(is_equal_approx(progression._elapsed, before_pause) and absf(sounds._mara_warning.get_playback_position() - audio_before) < 0.12 and not sounds.play_phone_reply(), "Pausing freezes subtitle and dialogue clocks together")
	paused = false
	await _until(3.60)
	_record_timing("second_line")
	_check(progression.subtitle == progression.mara_lines[1] and absf(sounds._mara_warning.get_playback_position() - progression._elapsed) < 0.25, "Greyhaven subtitle and spoken track stay synchronized at the second line")
	await _until(7.60)
	_record_timing("third_line")
	_check(progression.subtitle == progression.mara_lines[2] and absf(sounds._mara_warning.get_playback_position() - progression._elapsed) < 0.25, "The interrupted warning stays synchronized at the third line")
	# The dummy headless audio driver can stall with the main thread. Check
	# normal clock alignment first, then verify real-time subtitle catch-up.
	var before_stall := progression._elapsed
	OS.delay_msec(400)
	await process_frame
	await process_frame
	_check(progression._elapsed >= before_stall + 0.32 and progression.stage == progression.Stage.MESSAGE, "A blocked render frame catches the message clock up without replaying or changing stage")
	await _until(11.70)
	_record_timing("signal_lost")
	_check(progression.subtitle == "[Connection lost]" and not sounds._mara_warning.playing and not sounds._phone_reply.playing, "Connection-loss beat has no overlapping spoken line")
	var gap_before_stall := progression._elapsed
	OS.delay_msec(350)
	await process_frame
	await process_frame
	_check(progression._elapsed >= gap_before_stall + 0.28 and progression.subtitle == "[Connection lost]" and not sounds._phone_reply.playing, "The silent connection-loss gap also catches up after a stall")
	await _until(13.65)
	_check(progression.subtitle == progression.mara_lines[4] and sounds._phone_reply.playing and sounds._phone_reply_played and not sounds._mara_warning.playing, "Luke's reply starts under his subtitle after the phone drops")
	_check(absf(sounds._phone_reply.get_playback_position() - (progression._elapsed - 13.5)) < 0.25 and not sounds.play_phone_reply(), "Luke's reply uses the correct seek offset and cannot duplicate")
	await _until(16.6)
	for frame in range(3): await process_frame
	_check(progression.stage == progression.Stage.PREPARATION and sounds._web_voice_played and not sounds._phone_reply.playing and not sounds._mara_warning.playing, "The existing web reaction waits until the phone sequence has finished")
	progression.set_process(false)
	var message_save := {"version": 1, "stage": progression.Stage.MESSAGE, "warning_heard": false, "has_flashlight": false, "has_keys": false, "encounter_survived": false, "departed": false}
	player.active = false
	progression.restore_snapshot(message_save)
	progression._elapsed = 4.0
	progression._update_message()
	sounds._process(0.0)
	_check(not sounds._mara_warning.playing, "Restored message remains silent while the player is inactive")
	player.active = true
	sounds._process(0.0)
	_check(sounds._mara_warning.playing and absf(sounds._mara_warning.get_playback_position() - 4.0) < 0.25 and progression.subtitle == progression.mara_lines[1], "Late activation seeks to the current subtitle instead of restarting old words")
	player._recovering = true
	player.recovery_changed.emit(true)
	_check(not sounds._mara_warning.playing and not sounds._phone_reply.playing and not sounds._web_voice.playing, "Player recovery stops every spoken channel")
	player._recovering = false
	player.recovery_changed.emit(false)
	progression.restore_snapshot(message_save)
	sounds._process(0.0)
	_check(sounds._mara_warning.playing and progression._elapsed == 0.0 and not sounds.play_mara_warning(), "Restoring a message checkpoint permits one synchronized fresh attempt")
	progression._set_stage(progression.Stage.COMPLETE)
	_check(not sounds._mara_warning.playing and not sounds._phone_reply.playing and not sounds._web_voice.playing, "Departure stops all dialogue")
	var evidence_path := ProjectSettings.globalize_path("res://").path_join("../Evidence/phone-voice-test-report.json")
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "real-time phone subtitle/audio synchronization and event gating", "display_driver": DisplayServer.get_name(), "checks": checks, "failures": failures, "mara_seconds": mara.get_length(), "luke_seconds": reply.get_length(), "timing_samples": timing_samples, "results": rows}, "  "))
	file.close()
	print("Phone voice: %d checks, %d failures" % [checks, failures])
	stage.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

func _record_timing(label: String) -> void:
	var sample := {"label": label, "elapsed": progression._elapsed, "subtitle": progression.subtitle, "mara_position": sounds._mara_warning.get_playback_position(), "mara_playing": sounds._mara_warning.playing}
	timing_samples.append(sample)
	print("PHONE_SYNC ", JSON.stringify(sample))
