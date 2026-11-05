extends SceneTree
## Native house playback and subtitle capture; no altered time scale or save writes.

var game: Node3D
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.progression.interact(&"phone")
	var sounds = game.get_node("Soundscape")
	while game.progression._elapsed < 0.4: await process_frame
	await _capture("mara-warning-first-line-native.png")
	while game.progression._elapsed < 3.8: await process_frame
	await _capture("mara-warning-greyhaven-native.png")
	var blocked_web: bool = not sounds.play_web_reveal_voice()
	while game.progression._elapsed < 13.8: await process_frame
	await _capture("luke-phone-reply-native.png")
	while game.progression.stage == game.progression.Stage.MESSAGE: await process_frame
	var valid := blocked_web and rows.size() == 3 and rows.all(func(row): return row.saved and row.expected_voice_playing and row.clock_difference_seconds < 0.25)
	var evidence_path := ProjectSettings.globalize_path("res://").path_join("../Evidence/phone-voice-native-capture.json")
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "native house phone dialogue and subtitle capture", "passed": valid, "web_reaction_blocked_during_message": blocked_web, "rows": rows}, "  "))
	file.close()
	print("Native phone voice: ", JSON.stringify({"passed": valid, "captures": rows.size()}))
	quit(0 if valid else 1)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var sounds = game.get_node("Soundscape")
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var is_reply: bool = game.progression._elapsed > 13.5
	var elapsed: float = game.progression._elapsed
	var voice_position: float = sounds._phone_reply.get_playback_position() if is_reply else sounds._mara_warning.get_playback_position()
	var subtitle: String = game.progression.subtitle
	var voice_playing: bool = sounds._phone_reply.playing if is_reply else sounds._mara_warning.playing
	# GPU readback/PNG saving blocks the main thread. Sample the clocks first.
	var saved := root.get_texture().get_image().save_png(path) == OK
	rows.append({"filename": filename, "saved": saved, "elapsed": elapsed, "subtitle": subtitle, "expected_voice_playing": voice_playing, "voice_position": voice_position, "clock_difference_seconds": absf(voice_position - (elapsed - 13.5 if is_reply else elapsed))})
	print("Phone voice capture: ", filename, " at=", game.progression._elapsed)
