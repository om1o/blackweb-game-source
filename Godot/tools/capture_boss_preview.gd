extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var folder := "D:/CodexTemp/Blackweb-BossPass"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
	var scene = load("res://scripts/boss_encounter.gd").new()
	scene.qa_mode = true
	root.add_child(scene)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(folder + "/boss-menu.png")
	scene._retry()
	scene.player.set_process_unhandled_input(false)
	scene.player._pitch = -0.10
	scene.dialogue.reset()
	scene.player.position = Vector3(0,.04,2.5)
	scene.player.set_view(0.0)
	scene.boss.set_physics_process(false)
	scene.boss.position = Vector3(0,.04,-2.5)
	scene.boss.rotation.y = PI
	scene.boss.state = scene.boss.State.STALK
	scene.boss.start_attack("ground_slam")
	scene.boss.animation.advance(0.2)
	scene.boss.animation.seek(1.5,true)
	scene.boss.animation.pause()
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(folder + "/boss-slam.png")
	scene.boss.state = scene.boss.State.STALK
	scene.boss.start_attack("marked_leap")
	scene.boss.animation.advance(0.2)
	scene.boss.animation.seek(1.4,true)
	scene.boss.animation.pause()
	for i in 15: await process_frame
	root.get_texture().get_image().save_png(folder + "/boss-leap.png")
	scene.dialogue.say("greeting")
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(folder + "/boss-dialogue.png")
	scene.queue_free()
	await process_frame
	quit()
