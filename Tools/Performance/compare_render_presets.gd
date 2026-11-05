extends SceneTree
## One-house, paused-render diagnostic. Does not change or save game preferences.
## Native only: --path Godot --script <this file> -- --output=<Evidence JSON>
## Q/N/S/S/N/Q balances order; separate route evidence measures live simulation.

const CONFIGURATIONS := [
	{"name": "quality", "scale": 1.0, "msaa": Viewport.MSAA_2X},
	{"name": "native_no_msaa", "scale": 1.0, "msaa": Viewport.MSAA_DISABLED},
	{"name": "scaled_no_msaa", "scale": 0.75, "msaa": Viewport.MSAA_DISABLED},
]
const ORDER := [0, 1, 2, 2, 1, 0]
const VIEWS := [
	{"name": "entry", "eye": Vector3(-4.3, 1.82, .4), "look": Vector3(-.3, 1.15, .4)},
	{"name": "records", "eye": Vector3(.6, 1.82, 2.5), "look": Vector3(2.8, 1.1, 1.1)},
	{"name": "web_room", "eye": Vector3(4.0, 1.82, -2.8), "look": Vector3(6.8, 1.1, -1.5)},
]
var game: Node3D
var output_path := "D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/InterfaceRelease/render-variant-comparison.json"
var source_commit := "not supplied; exact runtime hashes included"
var report := {"schema": 1, "kind": "Native paused-render Q/N/S/S/N/Q comparison", "failures": [], "prewarm": [], "phases": []}
var started_usec := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	started_usec = Time.get_ticks_usec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		if argument.begins_with("--source-commit="): source_commit = argument.trim_prefix("--source-commit=")
	output_path = output_path.replace("\\", "/").simplify_path()
	if not output_path.begins_with("D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/") or not output_path.ends_with(".json"):
		printerr("Comparison output must be a JSON inside this project's Evidence directory")
		quit(3)
		return
	if DisplayServer.get_name() == "headless":
		printerr("This render comparison requires a native renderer; no headless timing")
		quit(3)
		return
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	print("RENDER_VARIANTS: loading house pid=", OS.get_process_id())
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	print("RENDER_VARIANTS: first process frame after scene construction")
	if not game._loaded:
		report.failures.append("House did not load")
		await _finish()
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Freeze the same starter scene for every configuration. Keep the real torch
	# and its shadows, web materials and environmental lighting enabled.
	game.player.active = false
	paused = true
	game.player.lamp.visible = true
	game.player.lamp.light_energy = 1.45
	root.disable_3d = false
	game.player.camera.make_current()
	_metadata()
	print("RENDER_VARIANTS: awaiting first native house draw (not measured)")
	if not await _wait_draws(2, 300.0):
		report.failures.append("No first native house frames within the draw watchdog")
		await _finish()
		return
	report.metadata["first_house_draw_elapsed_seconds"] = (Time.get_ticks_usec() - started_usec) / 1000000.0
	# Compile/visit each configuration and view before collecting any samples.
	for configuration in CONFIGURATIONS:
		_apply(configuration)
		for view in VIEWS:
			_position(view)
			var prime := await _warmup(1.0)
			prime["configuration"] = configuration.name
			prime["view"] = view.name
			report.prewarm.append(prime)
			if not prime.ok:
				report.failures.append("Prewarm did not render: " + configuration.name + "/" + view.name)
				await _finish()
				return
	print("RENDER_VARIANTS: all configurations/views prewarmed; timing begins")
	for phase_index in ORDER.size():
		var configuration: Dictionary = CONFIGURATIONS[ORDER[phase_index]]
		_apply(configuration)
		var phase := {"index": phase_index, "name": configuration.name, "repeat": 1 if phase_index < 3 else 2, "views": []}
		for view in VIEWS:
			_position(view)
			var warm := await _warmup(1.5)
			if not warm.ok:
				report.failures.append("Sample warmup did not render: " + configuration.name + "/" + view.name)
				await _finish()
				return
			var result := await _sample(3.0)
			result["name"] = view.name
			result["eye"] = _vector(view.eye)
			result["look"] = _vector(view.look)
			result["warmup"] = warm
			result["actual_config"] = _config()
			phase.views.append(result)
			if result.samples < 10 or result.drawn_frames < 5:
				report.failures.append("Insufficient frames: " + configuration.name + "/" + view.name)
			# Readback/file writes are explicitly outside every timing window.
			if not await _wait_draws(1, 15.0):
				report.failures.append("No draw before evidence readback")
			else:
				var capture := root.get_texture().get_image()
				result["framebuffer_pixels"] = [capture.get_width(), capture.get_height()]
				result["estimated_3d_pixels"] = [roundi(capture.get_width() * root.scaling_3d_scale), roundi(capture.get_height() * root.scaling_3d_scale)]
				var capture_path := output_path.trim_suffix(".json") + "-%02d-%s-%s.png" % [phase_index, configuration.name, view.name]
				result["capture"] = capture_path
				if capture.save_png(capture_path) != OK: report.failures.append("Could not save capture " + capture_path)
			print("RENDER_VARIANTS: ", phase_index, " ", configuration.name, "/", view.name, " median_ms=", result.median_ms, " p95_ms=", result.p95_ms, " frames=", result.samples)
		report.phases.append(phase)
		_write_report() # Retain completed phases if a later external failure occurs.
	report["comparisons"] = _comparisons()
	await _finish()

func _metadata() -> void:
	var hashes: Dictionary = {}
	for source in ["main", "player", "spider", "mini_spider", "house_dressing", "environment_surfaces", "modeled_silk", "house_batching", "horror_menu", "menu_settings", "armor_visuals", "progression", "soundscape"]:
		var path: String = "res://scripts/" + source + ".gd"
		if FileAccess.file_exists(path): hashes[source + ".gd"] = FileAccess.get_sha256(path)
	report["metadata"] = {
		"utc": Time.get_datetime_string_from_system(true), "process_id": OS.get_process_id(), "engine": Engine.get_version_info(),
		"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"renderer": RenderingServer.get_current_rendering_method(), "display_driver": DisplayServer.get_name(),
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"window": [root.size.x, root.size.y], "content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		"source_commit": source_commit, "runtime_script_sha256": hashes,
		"harness_sha256": FileAccess.get_sha256(get_script().resource_path),
		"armor_loadout": game.player.get_armor_state(), "torch_visible": game.player.lamp.visible, "torch_energy": game.player.lamp.light_energy,
		"order": ["quality", "native_no_msaa", "scaled_no_msaa", "scaled_no_msaa", "native_no_msaa", "quality"],
		"views": ["entry", "records", "web_room"], "prewarm_seconds_per_view": 1.0, "warmup_seconds_per_sample": 1.5, "sample_seconds": 3.0,
		"workload": "One full house loaded once; paused starter simulation, fixed camera views, real environmental lights and torch shadows. Same visible HUD and geometry throughout. No armor equipped. No settings saved.",
		"sampling": "Monotonic process_frame-to-process_frame intervals, seeded at a process_frame boundary. Includes presentation, OS scheduling and minimal collection overhead. Raw timestamps and draw deltas retained. No screenshot, file write, logging or config change inside samples.",
		"limitations": ["Paused rendering is not live AI/physics gameplay or a thermal endurance test.", "These are wall-clock frame intervals, not isolated GPU execution times.", "Estimated 3D dimensions are final framebuffer dimensions multiplied by configured scale; the internal render target is not directly read back.", "Process manifests recorded by launcher establish external engine presence; desktop programs and ordinary OS scheduling still share resources.", "Reverse repetition reduces order bias but cannot remove thermal or background-load drift."],
	}

func _apply(configuration: Dictionary) -> void:
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = float(configuration.scale)
	root.msaa_3d = int(configuration.msaa)

func _position(view: Dictionary) -> void:
	game.player.camera.global_position = view.eye
	game.player.camera.look_at(view.look, Vector3.UP)

func _config() -> Dictionary:
	return {"scale_3d": root.scaling_3d_scale, "scaling_mode": root.scaling_3d_mode, "msaa_3d": root.msaa_3d,
		"disable_3d": root.disable_3d, "tree_paused": paused, "window_mode": DisplayServer.window_get_mode(),
		"window_size": [root.size.x, root.size.y], "viewport_texture_size": [root.get_texture().get_width(), root.get_texture().get_height()],
		"draw_calls_monitor": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives_monitor": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

func _wait_draws(count: int, timeout: float) -> bool:
	var before := Engine.get_frames_drawn()
	var start := Time.get_ticks_usec()
	while Engine.get_frames_drawn() - before < count:
		await process_frame
		if Engine.get_frames_drawn() - before >= count: return true
		if Time.get_ticks_usec() - start > int(timeout * 1000000.0): return false
	return true

func _warmup(seconds: float) -> Dictionary:
	var start := Time.get_ticks_usec()
	var initial_draws := Engine.get_frames_drawn()
	var frames := 0
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0) or frames < 15:
		await process_frame
		frames += 1
		if Time.get_ticks_usec() - start > 60000000 and Engine.get_frames_drawn() == initial_draws: break
	return {"elapsed_seconds": (Time.get_ticks_usec() - start) / 1000000.0, "process_frames": frames,
		"drawn_frames": Engine.get_frames_drawn() - initial_draws, "ok": Engine.get_frames_drawn() - initial_draws >= 10}

func _sample(seconds: float) -> Dictionary:
	var intervals: Array[float] = []
	var timestamps: Array[int] = []
	var draw_deltas: Array[int] = []
	# Seed after a process_frame, not midway between draw and the next frame.
	await process_frame
	var start := Time.get_ticks_usec()
	var previous := start
	var previous_draw := Engine.get_frames_drawn()
	var initial_draw := previous_draw
	while previous - start < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		var draws := Engine.get_frames_drawn()
		intervals.append((now - previous) / 1000.0)
		timestamps.append(now)
		draw_deltas.append(draws - previous_draw)
		previous = now
		previous_draw = draws
	var result := _stats(intervals)
	result["start_monotonic_usec"] = start
	result["end_monotonic_usec"] = previous
	result["drawn_frames"] = previous_draw - initial_draw
	result["raw_frame_ms"] = intervals
	result["sample_monotonic_usec"] = timestamps
	result["raw_draw_delta"] = draw_deltas
	return result

func _stats(frames: Array[float]) -> Dictionary:
	if frames.is_empty(): return {"samples": 0, "mean_ms": 0.0, "median_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	var ordered := frames.duplicate()
	ordered.sort()
	var total := 0.0
	for frame in frames: total += frame
	return {"samples": frames.size(), "mean_ms": total / frames.size(), "median_ms": ordered[maxi(0, ceili(ordered.size() * .5) - 1)],
		"p95_ms": ordered[maxi(0, ceili(ordered.size() * .95) - 1)], "max_ms": ordered.back(), "min_ms": ordered.front(),
		"frames_over_33_34_ms": frames.filter(func(value: float) -> bool: return value > 33.34).size()}

func _comparisons() -> Array:
	var comparisons: Array = []
	for view in VIEWS:
		var configs: Dictionary = {}
		for configuration in CONFIGURATIONS:
			var all_frames: Array[float] = []
			var repeats: Array = []
			for phase in report.phases:
				if phase.name != configuration.name: continue
				for result in phase.views:
					if result.name != view.name: continue
					all_frames.append_array(result.raw_frame_ms)
					repeats.append({"phase": phase.index, "mean_ms": result.mean_ms, "median_ms": result.median_ms, "p95_ms": result.p95_ms})
			configs[configuration.name] = {"pooled": _stats(all_frames), "repeats": repeats}
		comparisons.append({"view": view.name, "configurations": configs})
	return comparisons

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _write_report() -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write comparison report: ", output_path)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()

func _finish() -> void:
	report["complete"] = report.phases.size() == ORDER.size()
	report["total_elapsed_seconds"] = (Time.get_ticks_usec() - started_usec) / 1000000.0
	_write_report()
	print("RENDER_VARIANTS_COMPLETE phases=", report.phases.size(), " failures=", report.failures.size(), " output=", output_path)
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.queue_free()
	paused = false
	await process_frame
	await create_timer(.12, true).timeout
	quit(0 if report.failures.is_empty() and report.phases.size() == ORDER.size() else 1)
