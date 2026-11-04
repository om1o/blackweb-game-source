extends SceneTree
## Runs the real BlackwebPlayer crouch/jump controls in a simple native QA stage.

const PlayerScript = preload("res://scripts/player.gd")
const ProgressionScript = preload("res://scripts/progression.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for action_name in ["crouch", "jump", "sprint", "move_left", "move_right", "move_forward", "move_back"]:
		if not InputMap.has_action(action_name): InputMap.add_action(action_name)
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8.0, 0.3, 8.0)
	collision.shape = floor_shape
	floor_body.position.y = -0.15
	floor_body.add_child(collision)
	stage.add_child(floor_body)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.15, 0.17, 0.19)
	floor.material_override = floor_material
	stage.add_child(floor)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.065, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.41, 0.45)
	env.ambient_light_energy = 0.55
	environment.environment = env
	stage.add_child(environment)
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
	var progression = ProgressionScript.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	progression.has_flashlight = true
	stage.add_child(progression)
	var player = PlayerScript.new()
	player.progression = progression
	stage.add_child(player)
	progression.player = player
	player.attach_model(load("res://scenes/luke.tscn"))
	player.active = true
	var camera := Camera3D.new()
	camera.fov = 53.0
	camera.position = Vector3(2.2, 1.45, 2.5)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)
	camera.current = true
	for frame in range(10): await physics_frame
	await _capture("player-standing-native.png")
	Input.action_press("crouch")
	for frame in range(30): await physics_frame
	print("Actual player crouch=", player.is_crouching(), " weight=", player._locomotion_pose.crouch_weight)
	await _capture("player-crouching-native.png")
	Input.action_release("crouch")
	for frame in range(30): await physics_frame
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for frame in range(10): await physics_frame
	print("Actual player airborne=", not player.is_on_floor(), " y=", player.global_position.y, " jump_weight=", player._locomotion_pose.jump_weight)
	await _capture("player-jumping-native.png")
	quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + name)
	var error := root.get_texture().get_image().save_png(path)
	print(name, " saved=", error == OK)
