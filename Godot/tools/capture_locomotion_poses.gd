extends SceneTree
## Isolated native QA views of recovered Luke's standing, crouched, and jump poses.

const PoseScript = preload("res://scripts/locomotion_pose.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var luke = load("res://scenes/luke.tscn").instantiate()
	stage.add_child(luke)
	var rig: Skeleton3D = luke.find_children("*", "Skeleton3D", true, false)[0]
	var pose = PoseScript.new()
	if not pose.bind(rig):
		quit(1)
		return
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(5.0, 5.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.15, 0.17, 0.19)
	floor.material_override = floor_material
	stage.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 53.0
	camera.position = Vector3(2.2, 1.45, 2.5)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)
	camera.current = true
	var key := OmniLight3D.new()
	key.position = Vector3(1.8, 2.8, 1.6)
	key.light_energy = 2.0
	key.omni_range = 7.0
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 1.6, -1.0)
	fill.light_energy = 0.9
	fill.omni_range = 5.0
	stage.add_child(fill)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.065, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.41, 0.45)
	env.ambient_light_energy = 0.55
	environment.environment = env
	stage.add_child(environment)
	await process_frame
	await _capture("locomotion-stand-qa.png")
	for frame in range(30): pose.apply(1.0 / 60.0, true, false, 0.0, Vector3.FORWARD)
	await _capture("locomotion-crouch-qa.png")
	pose.clear()
	luke.position.y = 0.37
	for frame in range(20): pose.apply(1.0 / 60.0, false, true, 5.0, Vector3.FORWARD)
	await _capture("locomotion-jump-qa.png")
	quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + name)
	var error := root.get_texture().get_image().save_png(path)
	print(name, " saved=", error == OK)
