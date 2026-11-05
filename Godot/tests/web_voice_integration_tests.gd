extends SceneTree

## Checks the authored one-time reaction against the real house scene and WAV.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("WEB_VOICE_TEST house did not load")
		quit(1)
		return
	game._resume()
	game.progression.warning_heard = true
	game.progression._set_stage(game.progression.Stage.PREPARATION)
	game.progression.step(4.0) # The authored post-call breathing room.
	game.player.global_position = Vector3(-1.6, 0.44, -2.0)
	for frame in range(3): await process_frame
	var sounds = game.get_node("Soundscape")
	var ready: bool = sounds._web_voice.stream != null
	var played: bool = sounds._web_voice_played
	var subtitled: bool = "webs were not here yesterday" in game.progression.notice
	var repeats: bool = sounds.play_web_reveal_voice()
	var result := {"voice_loaded": ready, "triggered_once": played, "subtitle_shown": subtitled, "repeat_rejected": not repeats}
	print("WEB_VOICE_TEST ", JSON.stringify(result))
	quit(0 if ready and played and subtitled and not repeats else 2)
