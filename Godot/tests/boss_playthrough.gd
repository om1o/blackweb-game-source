extends SceneTree
var frame_ms: Array[float] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene = load("res://scripts/boss_encounter.gd").new()
	scene.qa_mode = true
	root.add_child(scene)
	for i in 20: await process_frame
	scene._retry()
	scene.player.health = 10000.0
	scene.dialogue.reset()
	scene.boss.set_physics_process(false)
	var completed: Array[String] = []
	var elapsed := Time.get_ticks_usec()
	for entry: Dictionary in scene.boss.attacks:
		scene.boss.stop()
		scene.boss.position = Vector3(0,.04,-2.5)
		scene.player.position = Vector3(0,.04,1.2)
		scene.boss.state = scene.boss.State.STALK
		scene.boss.start_attack(entry.id)
		scene.boss.set_physics_process(true)
		var limit := 0
		while scene.boss.state == scene.boss.State.ATTACK and limit < 900:
			await process_frame
			var now := Time.get_ticks_usec()
			frame_ms.append(float(now-elapsed)/1000.0)
			elapsed = now
			limit += 1
		scene.boss.set_physics_process(false)
		if scene.boss.state != scene.boss.State.STALK:
			push_error("Attack did not finish: " + str(entry.id))
			quit(1)
			return
		completed.append(str(entry.id))
	frame_ms.sort()
	var sum := 0.0
	for value in frame_ms: sum += value
	var report := {"completed":completed,"frames":frame_ms.size(),"mean_frame_ms":sum/maxi(1,frame_ms.size()),"p95_frame_ms":frame_ms[int(frame_ms.size()*.95)],"renderer":RenderingServer.get_video_adapter_name(),"player_remaining_hp":scene.player.health,"boss_clips":scene.boss.animation_count}
	var file := FileAccess.open("D:/CodexTemp/Blackweb-BossPass/boss-playthrough.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BOSS_PLAYTHROUGH ",JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit()
