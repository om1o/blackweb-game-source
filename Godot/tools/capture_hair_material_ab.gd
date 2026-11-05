extends SceneTree
## Hair-only native A/B; the game, camera, lights, pose and source textures are frozen.

var game: Node3D
var player: BlackwebPlayer
var inspection: Camera3D
var fill: OmniLight3D
var hair: StandardMaterial3D
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	player = game.player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(12): await physics_frame
	player.set_physics_process(false)
	player._animation.pause()
	player.visual.show()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio_and_hide_ui(game)
	hair = _duplicate_hair(player.visual)
	if hair == null:
		push_error("Luke opacity material missing")
		quit(1)
		return
	inspection = Camera3D.new()
	inspection.fov = 48.0
	inspection.near = 0.02
	root.add_child(inspection)
	fill = OmniLight3D.new()
	fill.light_energy = 0.45
	fill.omni_range = 0.9
	fill.shadow_enabled = false
	root.add_child(fill)
	var skeleton := player._luke_skeleton
	var head_index := skeleton.find_bone("Bip01 Head")
	var centre := skeleton.to_global(skeleton.get_bone_global_pose(head_index).origin) + Vector3.UP * 0.10
	var right := player.visual.global_basis.x.normalized()
	var back := player.visual.global_basis.z.normalized()
	for side in [-1.0, 1.0]:
		inspection.global_position = centre + back * 0.61 + right * side * 0.30 + Vector3.UP * 0.12
		inspection.look_at(centre, Vector3.UP)
		inspection.current = true
		fill.global_position = centre + back * 0.20 + right * side * 0.24 + Vector3.UP * 0.16
		for candidate in ["before", "coverage", "specular"]:
			hair.metallic_specular = 0.3 if candidate == "before" else 0.0
			hair.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE if candidate == "coverage" else BaseMaterial3D.ALPHA_ANTIALIASING_OFF
			hair.alpha_antialiasing_edge = 0.20 if candidate == "coverage" else 0.3
			for frame in range(4): await process_frame
			await RenderingServer.frame_post_draw
			var label: String = candidate + ("-left" if side < 0.0 else "-right")
			var filename := "hair-material-" + label + ".png"
			var saved := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Evidence/" + filename)) == OK
			rows.append({"label": label, "saved": saved, "camera_transform": inspection.global_transform,
				"light_position": fill.global_position, "light_energy": fill.light_energy,
				"specular": hair.metallic_specular, "alpha_antialiasing_mode": hair.alpha_antialiasing_mode,
				"alpha_antialiasing_edge": hair.alpha_antialiasing_edge, "scissor": hair.alpha_scissor_threshold,
				"texture": hair.albedo_texture.resource_path})
			print("Hair native capture ", filename)
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/hair-material-ab.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "frozen actual-house Luke hair material comparison", "rows": rows,
		"msaa_3d": root.msaa_3d, "rendering_method": RenderingServer.get_current_rendering_method(),
		"pose": "paused actual Luke idle rig", "source_textures_modified": false}, "  "))
	file.close()
	game.queue_free()
	inspection.queue_free()
	fill.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if rows.size() == 6 and rows.all(func(row): return row.saved) else 1)

func _duplicate_hair(node: Node) -> StandardMaterial3D:
	if node is MeshInstance3D:
		for surface in node.get_surface_override_material_count():
			var material: Material = node.get_active_material(surface)
			if material is StandardMaterial3D and material.resource_name == "Luke_opacity":
				var duplicate := material.duplicate() as StandardMaterial3D
				node.set_surface_override_material(surface, duplicate)
				return duplicate
	for child in node.get_children():
		var found := _duplicate_hair(child)
		if found != null: return found
	return null

func _stop_audio_and_hide_ui(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	if node is CanvasLayer: node.hide()
	for child in node.get_children(): _stop_audio_and_hide_ui(child)
