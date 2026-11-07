extends SceneTree
## Real engine render, using the same skeletal clips and combat code as gameplay.
## Godot --write-movie ...avi --fixed-fps 30 --script res://tools/render_boss_attacks.gd
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://scripts/boss_encounter.gd").new()
	scene.qa_mode = true
	root.add_child(scene)
	await process_frame
	scene._retry()
	scene.player.health = 100000.0
	scene.player.set_physics_process(false)
	scene.player.set_process_unhandled_input(false)
	scene.status_hud.hide()
	scene.dialogue.reset()
	var camera := Camera3D.new()
	camera.fov = 48
	camera.position = Vector3(6,4.0,7.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0,1.1,-1.4))
	camera.make_current()
	var fill := OmniLight3D.new()
	fill.light_color = Color("d5bfa3")
	fill.light_energy = 2.0
	fill.omni_range = 12
	camera.add_child(fill)
	scene.boss.set_physics_process(false)
	for data: Dictionary in scene.boss.attacks:
		scene.boss.stop()
		scene.boss.position = Vector3(0,.04,-3)
		scene.boss.rotation.y = PI
		scene.player.position = Vector3(0,.04,1.5)
		scene.boss.state = scene.boss.State.STALK
		scene.boss.start_attack(data.id)
		scene.boss.set_physics_process(true)
		scene.caption.text = str(data.name).to_upper()+"  /  "+str(data.hint)
		while scene.boss.state == scene.boss.State.ATTACK: await physics_frame
		scene.boss.set_physics_process(false)
		for i in 12: await physics_frame
	scene.free()
	quit()
