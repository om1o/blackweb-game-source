extends SceneTree
## Real spawn/camera/physics fixture. No extra light is used for captures.
var game: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _body_shape(enemy: Node) -> CollisionShape3D:
	for child in enemy.get_children():
		if child is CollisionShape3D: return child
	return null

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "The real tutorial loads")
	if not game._loaded:
		quit(1)
		return
	game._resume()
	game.progression.set_process(false)
	game.set_process(false)
	game.progression._elapsed = 7.9
	game._update_early_sighting(0.1)
	_check(not game._sighting_spider.active, "Arrival remains safe before the eight-second grace period")
	game.progression._elapsed = 8.1
	game._update_early_sighting(0.1)
	var juvenile = game._sighting_spider
	juvenile.set_physics_process(false)
	await physics_frame
	await physics_frame
	game.player.set_physics_process(false)
	_check(juvenile.active and juvenile.visible, "Starter reliably becomes a visible fightable enemy")
	_check(juvenile.scale.is_equal_approx(Vector3.ONE), "The enlarged juvenile keeps an unscaled physics root")
	var body := _body_shape(juvenile)
	var shape := body.shape as CapsuleShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = body.global_transform
	query.collision_mask = 1
	query.exclude = [juvenile.get_rid()]
	_check(game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(),
		"The larger starter body spawns outside all walls and furniture")
	var volumes: Array = juvenile.get_hurt_spheres()
	_check(volumes.size() == 2 and float(volumes[0].radius) > 0.15 and float(volumes[1].radius) > 0.19,
		"Weapon targets grow with the juvenile's actual head and abdomen")
	var camera: Camera3D = game.player.camera
	var center: Vector3 = volumes[0].center
	var projected := camera.unproject_position(center)
	var screen := root.get_visible_rect()
	_check(not camera.is_position_behind(center) and screen.has_point(projected),
		"The starting spider's body is inside the untouched arrival camera frame")
	_check(projected.x > screen.size.x * 0.40 and projected.x < screen.size.x * 0.68,
		"The starter body is between the lower-left meters and lower-right equipment HUD")
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, center, 1)
	_check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),
		"No furniture or wall hides the starter from the arrival camera")
	var left := camera.unproject_position(center - camera.global_basis.x * float(volumes[0].radius))
	var right := camera.unproject_position(center + camera.global_basis.x * float(volumes[0].radius))
	_check(left.distance_to(right) > screen.size.x * 0.018,
		"The juvenile head occupies at least 1.8 percent of screen width at arrival")
	_check(juvenile._bite_audio.max_distance >= 8.0 and juvenile._bite_audio.unit_size > 2.0,
		"A single spatial contact voice makes nearby juveniles locatable")
	juvenile.apply_flashlight_beam(1.0, 0.2)
	_check(is_equal_approx(juvenile.light_speed_factor, 0.8), "The flashlight still slows the larger juvenile")
	var adult = game.spider
	adult.activate(game.player)
	adult.set_physics_process(false)
	var adult_capsule := _body_shape(adult).shape as CapsuleShape3D
	_check(is_equal_approx(adult_capsule.radius, adult._navigation._shape.radius)
		and is_equal_approx(adult_capsule.height, adult._navigation._shape.height),
		"Adult route checks use the same enlarged body as physical movement")
	var adult_volumes: Array = adult.get_hurt_spheres()
	_check(float(adult_volumes[0].radius) > 0.28 and float(adult_volumes[1].radius) >= 0.32,
		"The adult has matching enlarged pose-following weapon targets")
	_check(not adult._attack_tell_light.visible and is_zero_approx(adult._attack_tell_light.light_energy),
		"Readability does not add a supernatural light or a shadow pass")
	var emissive := false
	for actor in [juvenile, adult]:
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material != null and material.emission_enabled: emissive = true
	_check(not emissive, "Both creature materials stay non-emissive")
	adult.deactivate()
	var capture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture = argument.trim_prefix("--capture=")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture)
	juvenile.receive_hit(4.0, center, Vector3.UP)
	_check(is_equal_approx(juvenile.health, 8.0), "The larger tutorial enemy still takes three worn-knife hits")
	print(JSON.stringify({"suite": "spider visibility", "checks": checks, "failures": failures,
		"starter_head_screen_px": str(projected), "starter_head_width_px": left.distance_to(right),
		"viewport": str(screen.size), "spawn": str(juvenile.position)}))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
