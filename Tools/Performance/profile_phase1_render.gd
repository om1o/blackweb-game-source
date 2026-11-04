extends SceneTree
## One-process, read-only render probe for the real recovered house.
## Run with --script <this file> -- --variant=<name>.

const VARIANTS := ["baseline", "current_starter", "occlusion_off", "shadows_off", "practicals_off", "normal_specular_off", "concrete_normal_off", "structure_normal_off", "house_off", "flashlight_on", "flashlight_no_shadow", "one_shadow_0", "one_shadow_1", "camera_far_20", "shadow_aba", "flashlight_aba", "beam_aba", "beam_range_aba", "resolution_aba"]
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var variant := "baseline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):
			variant = arg.trim_prefix("--variant=")
	if not VARIANTS.has(variant):
		printerr("Unknown profile variant: ", variant)
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("House failed to load")
		quit(3)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var light_count := 0
	var shadow_count := 0
	var normal_materials := 0
	var occluders := 0
	var shadowed_practicals: Array[Light3D] = []
	for light in game._lamps:
		if light.shadow_enabled: shadowed_practicals.append(light)
	for node in _descendants(game):
		if node is Light3D:
			light_count += 1
			if node.shadow_enabled: shadow_count += 1
			if variant == "shadows_off": node.shadow_enabled = false
			if variant == "practicals_off": node.visible = false
		if node is OccluderInstance3D:
			occluders += 1
			if variant == "occlusion_off": node.visible = false
		if node is MeshInstance3D and variant in ["normal_specular_off", "concrete_normal_off", "structure_normal_off"]:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh:
				for surface in mesh_node.mesh.get_surface_count():
					var material := mesh_node.get_surface_override_material(surface)
					if material == null: material = mesh_node.mesh.surface_get_material(surface)
					if material is StandardMaterial3D:
						var normal_path := ""
						if material.normal_texture: normal_path = material.normal_texture.resource_path.get_file()
						var selected := variant == "normal_specular_off" or (variant == "concrete_normal_off" and normal_path == "T_Concrete_N_01.png") or (variant == "structure_normal_off" and normal_path in ["T_Concrete_N_01.png", "T_Brick_N_01.png"])
						if selected:
							if material.normal_enabled: normal_materials += 1
							material.normal_enabled = false
							if variant == "normal_specular_off": material.metallic_specular = 0.0
	if variant == "occlusion_off": root.use_occlusion_culling = false
	if variant == "house_off": game.get_node("RecoveredHouse").visible = false
	if variant == "camera_far_20": game.player.camera.far = 20.0
	if variant.begins_with("one_shadow_"):
		var keep := int(variant.trim_prefix("one_shadow_"))
		for index in shadowed_practicals.size():
			if index != keep: shadowed_practicals[index].shadow_enabled = false
	if variant == "flashlight_on" or variant == "flashlight_no_shadow" or variant == "flashlight_aba":
		game.progression.has_flashlight = true
		game.player.lamp.visible = true
		if variant == "flashlight_no_shadow": game.player.lamp.shadow_enabled = false
	for index in 120: await physics_frame
	if variant == "resolution_aba":
		var original_size := root.size
		var resolution_phases: Array[Dictionary] = []
		resolution_phases.append(await _sample_phase("1280_before", 90, "perf-resolution-aba-"))
		root.size = Vector2i(960, 540)
		resolution_phases.append(await _sample_phase("960_trial", 120, "perf-resolution-aba-"))
		root.size = original_size
		resolution_phases.append(await _sample_phase("1280_after", 120, "perf-resolution-aba-"))
		var resolution_aba := {"variant": variant, "original_size": [original_size.x, original_size.y], "trial_size": [960, 540], "content_scale_size": [root.content_scale_size.x, root.content_scale_size.y], "phases": resolution_phases}
		var resolution_output := FileAccess.open("res://../Evidence/phase1-perf-resolution-aba.json", FileAccess.WRITE)
		resolution_output.store_string(JSON.stringify(resolution_aba, "\t"))
		resolution_output.close()
		print("RENDER_PROBE ", JSON.stringify(resolution_aba))
		quit(0)
		return
	if variant == "beam_range_aba":
		var original_range: float = game.player.lamp.spot_range
		var range_phases: Array[Dictionary] = []
		range_phases.append(await _sample_phase("range_original_before"))
		game.player.lamp.spot_range = 9.0
		range_phases.append(await _sample_phase("range_9m"))
		game.player.lamp.spot_range = original_range
		range_phases.append(await _sample_phase("range_original_after"))
		var range_aba := {"variant": variant, "original_range_m": original_range, "trial_range_m": 9.0, "phases": range_phases}
		var range_output := FileAccess.open("res://../Evidence/phase1-perf-beam-range-aba.json", FileAccess.WRITE)
		range_output.store_string(JSON.stringify(range_aba, "\t"))
		range_output.close()
		print("RENDER_PROBE ", JSON.stringify(range_aba))
		quit(0)
		return
	if variant == "beam_aba":
		var beam_phases: Array[Dictionary] = []
		beam_phases.append(await _sample_phase("beam_on_before"))
		game.player._light_on = false
		game.player.lamp.visible = false
		beam_phases.append(await _sample_phase("beam_off"))
		game.player._light_on = true
		beam_phases.append(await _sample_phase("beam_on_after"))
		var beam_aba := {"variant": variant, "phases": beam_phases}
		var beam_output := FileAccess.open("res://../Evidence/phase1-perf-beam-aba.json", FileAccess.WRITE)
		beam_output.store_string(JSON.stringify(beam_aba, "\t"))
		beam_output.close()
		print("RENDER_PROBE ", JSON.stringify(beam_aba))
		quit(0)
		return
	if variant == "flashlight_aba":
		for light in shadowed_practicals: light.shadow_enabled = false
		var flash_phases: Array[Dictionary] = []
		flash_phases.append(await _sample_phase("flash_shadow_before"))
		game.player.lamp.shadow_enabled = false
		flash_phases.append(await _sample_phase("flash_no_shadow"))
		game.player.lamp.shadow_enabled = true
		flash_phases.append(await _sample_phase("flash_shadow_after"))
		var flash_aba := {"variant": variant, "phases": flash_phases, "practical_shadows": false, "flashlight_visible": game.player.lamp.visible}
		var flash_output := FileAccess.open("res://../Evidence/phase1-perf-flashlight-aba.json", FileAccess.WRITE)
		flash_output.store_string(JSON.stringify(flash_aba, "\t"))
		flash_output.close()
		print("RENDER_PROBE ", JSON.stringify(flash_aba))
		quit(0)
		return
	if variant == "shadow_aba":
		var phases: Array[Dictionary] = []
		phases.append(await _sample_phase("full_before"))
		shadowed_practicals[0].shadow_enabled = false
		phases.append(await _sample_phase("one_shadow_1"))
		shadowed_practicals[1].shadow_enabled = false
		phases.append(await _sample_phase("no_shadows"))
		for light in shadowed_practicals: light.shadow_enabled = true
		phases.append(await _sample_phase("full_after"))
		var aba := {"variant": variant, "phases": phases, "shadowed_practicals": shadowed_practicals.map(func(light: Light3D) -> Dictionary: return {"name": light.name, "position": [light.global_position.x, light.global_position.y, light.global_position.z]})}
		var aba_output := FileAccess.open("res://../Evidence/phase1-perf-shadow-aba.json", FileAccess.WRITE)
		aba_output.store_string(JSON.stringify(aba, "\t"))
		aba_output.close()
		print("RENDER_PROBE ", JSON.stringify(aba))
		quit(0)
		return
	var milliseconds: Array[float] = []
	var draw_calls: Array[int] = []
	var primitives: Array[int] = []
	var previous := Time.get_ticks_usec()
	for index in 180:
		await process_frame
		var current := Time.get_ticks_usec()
		milliseconds.append((current - previous) / 1000.0)
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		previous = current
	milliseconds.sort()
	draw_calls.sort()
	primitives.sort()
	var result := {
		"variant": variant,
		"renderer": RenderingServer.get_rendering_device() != null,
		"sample_count": milliseconds.size(),
		"frame_ms_median": milliseconds[90],
		"frame_ms_p95": milliseconds[171],
		"draw_calls_median": draw_calls[90],
		"primitives_median": primitives[90],
		"lights": light_count,
		"shadow_enabled_lights_before_probe": shadow_count,
		"shadowed_practicals": shadowed_practicals.map(func(light: Light3D) -> Dictionary: return {"name": light.name, "position": [light.global_position.x, light.global_position.y, light.global_position.z], "shadow_enabled_after_probe": light.shadow_enabled}),
		"occluders": occluders,
		"normal_mapped_surfaces_touched": normal_materials,
		"occlusion_culling": root.use_occlusion_culling,
		"flashlight_visible": game.player.lamp.visible,
		"window": [root.size.x, root.size.y],
		"camera_far_m": game.player.camera.far,
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	}
	var output_path := "res://../Evidence/phase1-perf-" + variant + ".json"
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		printerr("Cannot write ", output_path)
		quit(4)
		return
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../Evidence/phase1-perf-" + variant + ".png")
	print("RENDER_PROBE ", JSON.stringify(result))
	quit(0)

func _sample_phase(name: String, warmup_frames: int = 30, screenshot_prefix: String = "") -> Dictionary:
	for index in warmup_frames: await process_frame
	var milliseconds: Array[float] = []
	var calls: Array[int] = []
	var previous := Time.get_ticks_usec()
	for index in 180:
		await process_frame
		var current := Time.get_ticks_usec()
		milliseconds.append((current - previous) / 1000.0)
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		previous = current
	milliseconds.sort()
	calls.sort()
	await RenderingServer.frame_post_draw
	var prefix := screenshot_prefix if screenshot_prefix != "" else ("perf-flashlight-aba-" if game.player.lamp.visible else "perf-shadow-aba-")
	root.get_texture().get_image().save_png("res://../Evidence/" + prefix + name + ".png")
	return {"phase": name, "window": [root.size.x, root.size.y], "frame_ms_median": milliseconds[90], "frame_ms_p95": milliseconds[171], "draw_calls_median": calls[90], "sample_count": milliseconds.size()}

func _descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_descendants(child))
	return found
