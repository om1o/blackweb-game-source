extends SceneTree
## Native QA of the CC0 juvenile and authored additive adult attack pose.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Spider review: house failed to load")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(35): await process_frame
	var mini: Node3D = game.get_node_or_null("MiniSpider1")
	if mini == null:
		printerr("Spider review: MiniSpider1 missing")
		quit(2)
		return
	var mini_visual: Node3D = mini.get_node_or_null("JuvenileAnimatedSpider")
	var mini_animations: AnimationPlayer = mini.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	print("JUVENILE_MODEL ", JSON.stringify({
		"visual_loaded": mini_visual != null,
		"visual_scale": mini_visual.scale if mini_visual != null else Vector3.ZERO,
		"animations": mini_animations.get_animation_list() if mini_animations != null else PackedStringArray(),
		"mesh_count": mini_visual.find_children("*", "MeshInstance3D", true, false).size() if mini_visual != null else 0,
	}))
	mini.activate(game.player)
	mini.set_physics_process(false)
	mini.global_position = Vector3(5.8, 0.44, -1.45)
	mini.rotation.y = PI
	await _view(game, Vector3(5.8, 0.44, 0.26), 0.0, -0.66)
	if not await _capture("spider-juvenile-native.png"):
		quit(3)
		return
	var fill := OmniLight3D.new()
	fill.name = "QAOnlySpiderFill"
	fill.position = Vector3(5.8, 1.22, -1.35)
	fill.light_color = Color(1.0, 0.88, 0.78)
	fill.light_energy = 0.48
	fill.omni_range = 2.6
	fill.shadow_enabled = false
	game.add_child(fill)
	for frame in range(4): await process_frame
	if not await _capture("spider-juvenile-qa-fill.png"):
		quit(4)
		return
	mini.deactivate()
	fill.queue_free()
	var adult = game.spider
	adult.activate(game.player)
	adult.set_physics_process(false)
	adult.global_position = Vector3(4.8, 0.45, 0.1)
	adult.rotation.y = PI * 0.5
	await _view(game, Vector3(2.2, 0.44, 0.1), -PI * 0.5, -0.42)
	var adult_fill := OmniLight3D.new()
	adult_fill.name = "QAOnlyAdultFill"
	adult_fill.position = Vector3(3.9, 1.7, 0.6)
	adult_fill.light_color = Color(1.0, 0.86, 0.78)
	adult_fill.light_energy = 0.42
	adult_fill.omni_range = 3.0
	adult_fill.shadow_enabled = false
	game.add_child(adult_fill)
	adult._set_state(adult.State.WINDUP)
	adult._state_elapsed = 0.60
	adult._update_animation()
	adult._update_attack_tell()
	print("ADULT_ATTACK_BONES ", JSON.stringify(adult._attack_bones.keys()))
	if not await _capture("spider-adult-bone-windup.png"):
		quit(5)
		return
	adult._set_state(adult.State.LUNGING)
	adult._state_elapsed = 0.33
	adult._update_animation()
	adult._update_attack_tell()
	if not await _capture("spider-adult-bone-lunge.png"):
		quit(6)
		return
	quit(0)


func _view(game: Node3D, position: Vector3, yaw: float, pitch: float) -> void:
	game.player.global_position = position
	game.player.set_view(yaw)
	game.player._pitch = pitch
	game.player.arm.spring_length = 0.10
	game.player.visual.hide()
	for frame in range(8): await process_frame


func _capture(filename: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../Evidence/" + filename)
	var code := root.get_texture().get_image().save_png(path)
	print("SPIDER_MODEL_CAPTURE ", path, " code=", code)
	return code == OK
