extends SceneTree
## Native real-input capture. Time is slowed only in this QA tool to catch each pose.

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
	var player = game.player
	player.select_quick_slot(1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in range(30): await physics_frame
	# Discard the OS pointer recentering motion before recording the view.
	player._pitch = -0.09
	player.set_view(0.0)
	for frame in range(5): await physics_frame
	await _capture("knife-slash-ready.png")
	Engine.time_scale = 0.16
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	for sample in [[0.125, "knife-slash-windup.png"], [0.28, "knife-slash-contact.png"], [0.47, "knife-slash-followthrough.png"], [0.83, "knife-slash-recovery.png"]]:
		while player._action_time < sample[0] and player._action_kind == &"knife": await process_frame
		await _capture(sample[1])
	Engine.time_scale = 1.0
	for frame in range(20): await physics_frame
	await _capture("knife-slash-return.png")
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.04
	root.add_child(camera)
	game.status_hud.hide()
	var knife: Node3D = player._hand_knife
	var direction := -knife.global_basis.z.normalized()
	var side := direction.cross(Vector3.UP).normalized()
	camera.global_position = knife.global_position - direction * 0.12 + side * 0.46 + Vector3.UP * 0.09
	camera.look_at(knife.global_position + direction * 0.09, Vector3.UP)
	camera.current = true
	var fill := OmniLight3D.new()
	fill.light_energy = 0.75
	fill.omni_range = 0.8
	root.add_child(fill)
	fill.global_position = knife.global_position + side * 0.18 + Vector3.UP * 0.14
	await _capture("knife-slash-grip-close.png")
	var file := FileAccess.open("res://data/knife_swing_capture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "native real-click slash sequence; QA time scale 0.16", "rows": rows}, "  "))
	file.close()
	print("Knife sequence captures: ", rows.size())
	quit(0 if rows.size() == 7 and rows.all(func(row): return row.saved) else 1)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var player = game.player
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var saved := root.get_texture().get_image().save_png(path) == OK
	rows.append({"filename": filename, "saved": saved, "action": str(player._action_kind), "time": player._action_time, "hand_world": player._hand_mount.global_position, "grip_local": player._hand_knife.position})
	print(filename, " saved=", saved, " time=", player._action_time)
