extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(900, 700)
	var path := "res://assets/generated/candy_blender/candy_variants.glb"
	var target := "res://../Tools/Assets/candy_blender_variants-godot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: path = args[0]
	if args.size() > 1: target = args[1]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), state)
	if err != OK:
		push_error("Candy GLB load failed: %s" % err)
		quit(1)
		return
	var model := doc.generate_scene(state)
	root.add_child(model)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.14, 0.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.35
	root.add_child(environment)
	for camera in model.find_children("*", "Camera3D", true, false): camera.current = true
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	err = image.save_png(ProjectSettings.globalize_path(target))
	print("Candy rendered export: ", path, " => ", target, "; error=", err)
	quit(0 if err == OK else 2)
