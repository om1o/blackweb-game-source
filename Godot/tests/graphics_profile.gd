extends RefCounted
## Optional native A/B/A render comparison, using the already-loaded house.
## Paused simulation isolates visual cost; the separate route measures live AI.

func run(game: Node, tree: SceneTree, output: String) -> Dictionary:
	var viewport := tree.root
	var settings = game.menu.settings
	var original_choice: String = settings.graphics_preset
	var original_override: String = settings.graphics_override
	var original_camera: Transform3D = game.player.camera.global_transform
	var original_paused := tree.paused
	var original_active: bool = game.player.active
	game.menu.hide()
	game.player.active = false
	tree.paused = true
	settings.graphics_override = ""
	var views := [
		{"name": "entry", "eye": Vector3(-4.3, 1.82, .4), "look": Vector3(-.3, 1.15, .4)},
		{"name": "records", "eye": Vector3(.6, 1.82, 2.5), "look": Vector3(2.8, 1.1, 1.1)},
		{"name": "web_room", "eye": Vector3(4.0, 1.82, -2.8), "look": Vector3(6.8, 1.1, -1.5)},
	]
	var report := {
		"kind": "Native paused-render Quality/Performance/Quality comparison",
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window": [viewport.size.x, viewport.size.y],
		"vsync": DisplayServer.window_get_vsync_mode(),
		"phases": [],
		"limitations": "Three fixed views, three seconds each after warm-up; simulation paused, no AI/physics workload. Frame intervals include presentation and OS scheduling, not isolated GPU times. See the separate live five-room route for gameplay. External game contention is recorded by the launch manifest.",
	}
	for phase in ["quality_before", "performance", "quality_after"]:
		settings.graphics_preset = "performance" if phase == "performance" else "quality"
		settings.apply_graphics(viewport)
		var phase_result := {"name": phase, "scale_3d": viewport.scaling_3d_scale, "msaa": viewport.msaa_3d, "views": []}
		for view in views:
			game.player.camera.global_position = view.eye
			game.player.camera.look_at(view.look, Vector3.UP)
			await tree.create_timer(1.5, true).timeout
			await RenderingServer.frame_post_draw
			var rows: Array[float] = []
			var start := Time.get_ticks_usec()
			var previous := start
			while Time.get_ticks_usec() - start < 3000000:
				await tree.process_frame
				var now := Time.get_ticks_usec()
				rows.append((now - previous) / 1000.0)
				previous = now
			var result := _stats(rows)
			result["name"] = view.name
			result["raw_frame_ms"] = rows
			phase_result.views.append(result)
			if view.name == "entry":
				await RenderingServer.frame_post_draw
				var capture := viewport.get_texture().get_image()
				capture.save_png(output + "/graphics-" + phase + ".png")
				phase_result["framebuffer_pixels"] = [capture.get_width(), capture.get_height()]
		report.phases.append(phase_result)
	settings.graphics_preset = original_choice
	settings.graphics_override = original_override
	settings.apply_graphics(viewport)
	game.player.camera.global_transform = original_camera
	game.player.active = original_active
	tree.paused = original_paused
	var file := FileAccess.open(output + "/graphics-preset-comparison.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("GRAPHICS_COMPARISON_COMPLETE ", output)
	return report

func _stats(frames: Array[float]) -> Dictionary:
	var values := frames.duplicate()
	values.sort()
	var total := 0.0
	for value in values: total += value
	return {"samples": values.size(), "mean_ms": total / maxf(1, values.size()),
		"median_ms": values[maxi(0, ceili(values.size() * .5) - 1)],
		"p95_ms": values[maxi(0, ceili(values.size() * .95) - 1)], "max_ms": values.back()}
