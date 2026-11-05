extends SceneTree
## Headless micro-measurement of next_direction elapsed time, not rendered FPS.
## Run with --path Godot --script <absolute path to this file>.
const SAMPLE_COUNT := 60
const START := Vector3(5.7, 0.45, -2.15)
const DESTINATION := Vector3(-2.2, 0.425, 0.0)
var game: Node3D
var failures: Array[String] = []
var concurrent_game_pid := 0
var output_path := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	output_path = ProjectSettings.globalize_path("res://../Evidence/spider-navigation-cost.json").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--concurrent-game-pid="): concurrent_game_pid = int(arg.trim_prefix("--concurrent-game-pid="))
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Actual house failed to load")
		quit(1)
		return
	game._resume()
	game.progression.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.spider.set_process(false)
	game.spider.set_physics_process(false)
	for juvenile in get_nodes_in_group("mini_spider"):
		juvenile.set_process(false)
		juvenile.set_physics_process(false)
	for door in game._tutorial_doors:
		if not door.opened: door.toggle()
	await create_timer(0.75).timeout
	for door in game._tutorial_doors:
		if not door.opened or door._hinge.rotation.y > -1.35: failures.append("Door did not finish opening: " + str(door.name))
	game.spider.position = START
	await physics_frame
	var navigation = game.spider._navigation
	var direct_clear: bool = navigation._clear(game.spider, START, DESTINATION)
	navigation.advance(0.61)
	var started := Time.get_ticks_usec()
	var direction: Vector3 = navigation.next_direction(game.spider, DESTINATION)
	var first_cold_us := Time.get_ticks_usec() - started
	if direction.is_zero_approx(): failures.append("Initial query returned no route")
	var warm_samples: Array[int] = []
	var invalidated_samples: Array[int] = []
	for index in SAMPLE_COUNT:
		await physics_frame
		started = Time.get_ticks_usec()
		direction = navigation.next_direction(game.spider, DESTINATION)
		warm_samples.append(Time.get_ticks_usec() - started)
		if direction.is_zero_approx(): failures.append("Warm query returned no route at sample " + str(index))
	for index in SAMPLE_COUNT:
		await physics_frame
		navigation.advance(0.61)
		started = Time.get_ticks_usec()
		direction = navigation.next_direction(game.spider, DESTINATION)
		invalidated_samples.append(Time.get_ticks_usec() - started)
		if direction.is_zero_approx(): failures.append("Invalidated query returned no route at sample " + str(index))
	var report := {
		"schema": 1,
		"measurement": "Elapsed microseconds inside next_direction only; wall-clock timing includes possible OS preemption",
		"utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"concurrent_native_game_pid": concurrent_game_pid,
		"controlled_benchmark": false,
		"limitations": "Headless route query timing, not rendered frame time or FPS. Existing native game and other desktop tasks may compete for CPU. Endpoints are fixed, all four doors open, actor simulation frozen; no evidence about many simultaneous enemies or moving doors under rendering load.",
		"scene": "res://scenes/main.tscn",
		"from": [START.x, START.y, START.z],
		"to": [DESTINATION.x, DESTINATION.y, DESTINATION.z],
		"waypoint_count": navigation.points.size(),
		"direct_route_clear": direct_clear,
		"first_cold_query_us": first_cold_us,
		"warm_cache": _stats(warm_samples),
		"invalidated_cache": _stats(invalidated_samples),
		"warm_samples_us": warm_samples,
		"invalidated_samples_us": invalidated_samples,
		"failures": failures
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		printerr("Could not write navigation evidence: " + output_path)
		failures.append("Evidence write failed")
	else:
		output.store_string(JSON.stringify(report, "  ") + "\n")
		output.close()
	print("SPIDER_NAVIGATION_COST ", JSON.stringify({"first_cold_query_us": first_cold_us,
		"warm_cache": report.warm_cache, "invalidated_cache": report.invalidated_cache,
		"direct_route_clear": direct_clear, "failures": failures, "output": output_path}))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func _stats(samples: Array[int]) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var count := sorted.size()
	var total := 0.0
	for value in sorted: total += value
	var median := (float(sorted[count / 2 - 1]) + float(sorted[count / 2])) * 0.5 if count % 2 == 0 else float(sorted[count / 2])
	return {"samples": count, "median_us": median, "p95_us": sorted[ceili(count * 0.95) - 1],
		"max_us": sorted[count - 1], "min_us": sorted[0], "mean_us": total / count}

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
