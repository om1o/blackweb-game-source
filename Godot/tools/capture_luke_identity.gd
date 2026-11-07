extends SceneTree
## Native reference images of the actual imported protagonist, not concept art.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := OS.get_user_data_dir().path_join("luke-identity")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.06,.07,.075)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.85,.88,.92)
	world.environment.ambient_light_energy = .5
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,150,0)
	light.light_energy = 1.0
	stage.add_child(light)
	var luke := load("res://scenes/luke.tscn").instantiate() as Node3D
	stage.add_child(luke)
	var animation := luke.get_node("AnimationPlayer") as AnimationPlayer
	animation.play("idle")
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	for frame in 10: await process_frame
	for view in ["portrait","full-body"]:
		camera.size = .67 if view == "portrait" else 2.05
		camera.position = Vector3(.22,1.59,-2.0) if view == "portrait" else Vector3(.5,1.25,-2.8)
		camera.look_at(Vector3(0,1.52,0) if view == "portrait" else Vector3(0,.88,0))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view+".png"))
	print("Luke identity captures saved: " + output)
	quit()
