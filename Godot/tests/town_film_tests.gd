extends SceneTree
const Intro = preload("res://scripts/tutorial_intro.gd")
class StandIn extends Node3D:
	var active := true
	var camera: Camera3D
	var visual: Node3D
var failures: Array[String] = []
var checks := 0
var completions := 0
var natural_video_completions := 0
var live := false
func playback_time(intro: Node) -> float:
	if live: return float(intro._town.elapsed) if is_instance_valid(intro._town) else 0.0
	return float(intro._video.stream_position) if is_instance_valid(intro._video) else 0.0
func observe_natural_end(intro: Node) -> void:
	if not live and is_instance_valid(intro._video):
		intro._video.finished.connect(func(): natural_video_completions += 1)
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := StandIn.new()
	scene.add_child(player)
	player.camera = Camera3D.new()
	player.add_child(player.camera)
	player.camera.make_current()
	player.visual = Node3D.new()
	player.add_child(player.visual)
	var hud := Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var intro := Intro.new()
	live = OS.get_cmdline_user_args().has("--live-3d")
	intro.town_enabled = live
	intro.film_enabled = not live
	scene.add_child(intro)
	intro.finished.connect(func(): completions += 1)
	# Main's settings setup creates this bus; reproduce that setup in isolation.
	var settings = preload("res://scripts/menu_settings.gd").new()
	settings._set_bus(&"Dialogue", 1.0)
	var bus := AudioServer.get_bus_index("Dialogue")
	check(bus >= 0, "Dialogue bus exists")
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	check(intro.begin(player, hud) and (intro._town != null if live else intro._video != null), "Animated town loads and starts")
	observe_natural_end(intro)
	if not live and is_instance_valid(intro._video):
		check(not intro._video.loop, "The movie is configured for a single natural playback")
	check(paused and not player.active and root.disable_3d, "Cinematic suspends player and 3D rendering")
	await create_timer(.15, true).timeout
	var peak := 0.0
	var snapshots := 0
	var maximum_playback_time := 0.0
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Intro.FILM_MANIFEST))
	var expected_duration := float(manifest.get("duration_seconds", 0.0))
	check(expected_duration > 35.0 and expected_duration <= 90.0, "The delivered intro has a bounded full-story duration")
	var frames: Array[float] = []
	var previous := Time.get_ticks_usec()
	var deadline := Time.get_ticks_msec() + 120000
	var output := ProjectSettings.globalize_path("res://../Evidence/Town3D")
	DirAccess.make_dir_recursive_absolute(output)
	while intro.is_running() and Time.get_ticks_msec() < deadline:
		await process_frame
		maximum_playback_time = maxf(maximum_playback_time, playback_time(intro))
		var now := Time.get_ticks_usec()
		if playback_time(intro) > 2: frames.append(float(now-previous)/1000.0)
		previous = now
		if (intro._town_ready if live else true) and capture.can_get_buffer(capture.get_frames_available()):
			for sample in capture.get_buffer(capture.get_frames_available()): peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		if playback_time(intro) >= 8.0 + snapshots * 12.0 and snapshots < 3:
			var picture_size: Vector2 = Vector2(intro._town_viewport.size) if live else intro._video.size
			check(picture_size.x > 600 and picture_size.y > 300, "Animated picture fills the viewport")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/cinematic-%d.png" % snapshots)
			snapshots += 1
	check(not intro.is_running() and completions == 1, "Cinematic completion restores control within the deadline")
	check(live or natural_video_completions == 1, "The decoder emits its natural end signal; the stall watchdog is not accepted as completion")
	check(absf(maximum_playback_time - expected_duration) <= 0.25 and snapshots == 3,
		"Playback finishes within a quarter-second of the declared duration after every picture milestone")
	check(peak > 0.02 and peak < 1.0, "Decoded Dialogue output is audible and unclipped")
	check(not paused and player.active and not root.disable_3d and player.camera.current, "Cinematic completion restores gameplay and rendering")
	intro.begin(player, hud)
	observe_natural_end(intro)
	await create_timer(0.2, true).timeout
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	check(not intro.is_running() and completions == 2 and not root.disable_3d and not paused, "Real Enter input skips cinematic and restores rendering")
	check(live or natural_video_completions == 1, "Skipping does not counterfeit a second natural decoder completion")
	if not live:
		check(intro.begin(player, hud) and is_instance_valid(intro._video), "A third playback starts for a bounded stalled-decoder fixture")
		observe_natural_end(intro)
		if is_instance_valid(intro._video):
			intro._video.stop()
			intro._video_last_position = 0.0
			intro._video_stalled_seconds = 15.1
			intro._process(0.01)
		check(not intro.is_running() and completions == 3 and natural_video_completions == 1,
			"The stall watchdog exits without masquerading as natural video completion")
		check(not paused and player.active and not root.disable_3d and player.camera.current,
			"The stalled-decoder fallback restores gameplay, camera and rendering")
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	var report := {"checks":checks,"failures":failures,"decoded_audio_peak":peak,"frames_captured":snapshots,
		"natural_video_completions":natural_video_completions,"maximum_playback_time":maximum_playback_time,
		"expected_duration":expected_duration,"mode":"live_3d" if live else "rendered_3d_movie"}
	frames.sort()
	if not frames.is_empty(): report["frame_ms"] = {"median":frames[frames.size()/2],"p95":frames[int(frames.size()*.95)],"maximum":frames[-1],"samples":frames.size()}
	FileAccess.open(output + "/town-playback-tests.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TOWN_FILM ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
