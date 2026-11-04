extends SceneTree
## Paired native frame-time sample with all web/residue dressing hidden/visible.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Web profile: house failed to load")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.global_position = Vector3(-4.02, 0.44, -1.50)
	game.player.set_view(0.12)
	game.player._pitch = -0.04
	game.player.arm.spring_length = 0.10
	game.player.visual.hide()
	for frame in range(25): await process_frame
	var house: Node3D = game.get_node("RecoveredHouse")
	var parts: Array[Node3D] = []
	for name in ["BlackwebCornerWebs", "BlackwebRadialWebs", "BlackwebHangingVeils",
		"BlackwebBloodAndGoo", "BlackwebPhotoWebs", "BlackwebSheetAndWrapCards",
		"BlackwebSheetAndWrapStrands"]:
		var part: Node3D = house.get_node_or_null(name)
		if part == null:
			printerr("Web profile: missing ", name)
			quit(2)
			return
		parts.append(part)
	_set_visible(parts, false)
	var bare_first := await _sample("bare_a")
	_set_visible(parts, true)
	var dressed := await _sample("dressed_b")
	_set_visible(parts, false)
	var bare_second := await _sample("bare_a2")
	_set_visible(parts, true)
	await RenderingServer.frame_post_draw
	var result := {"kind": "native paired dressing frame-time trial", "renderer": "Godot 4.7.2 Compatibility / ANGLE on Intel HD Graphics 530",
		"view": "stationary painted cabinet and web wall", "samples": [bare_first, dressed, bare_second],
		"interpretation": "Single location, same process; not a whole-route FPS guarantee."}
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/web-residue-frame-trial.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Web profile: could not write evidence")
		quit(3)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("WEB_RESIDUE_FRAME_TRIAL ", JSON.stringify(result))
	quit(0)


func _set_visible(parts: Array[Node3D], visible: bool) -> void:
	for part in parts: part.visible = visible


func _sample(name: String) -> Dictionary:
	for frame in range(25): await process_frame
	var durations: Array[float] = []
	var draws: Array[int] = []
	var previous := Time.get_ticks_usec()
	for frame in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		durations.append(float(now - previous) / 1000.0)
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous = now
	durations.sort()
	draws.sort()
	return {"phase": name, "window": [root.size.x, root.size.y], "frame_ms_median": durations[60],
		"frame_ms_p95": durations[114], "draw_calls_median": draws[60], "sample_count": durations.size()}
