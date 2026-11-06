extends SceneTree
var game: Node
var results: Array = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	game.player.active = false
	paused = true
	game.player.lamp.visible = true
	var views := [Vector3(-4.3,1.82,.4), Vector3(.6,1.82,2.5), Vector3(4,1.82,-2.8)]
	var scales := [1.0, 0.75, 0.6, 1.0] if OS.get_cmdline_user_args().has("--compare-scaling") else [1.0,1.0]
	for scale in scales:
		root.scaling_3d_scale = scale
		for index in views.size():
			game.player.camera.global_position = views[index]
			game.player.camera.look_at(views[index]+Vector3(2,-.5,-.2))
			await create_timer(1.0,true).timeout
			var frames: Array[float] = []
			var start := Time.get_ticks_usec()
			var last := start
			while Time.get_ticks_usec()-start < 2500000:
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append((now-last)/1000.0)
				last = now
			frames.sort()
			results.append({"scale":scale,"view":index,"median_ms":frames[frames.size()/2],"p95_ms":frames[int(frames.size()*.95)],"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var output := "D:/CodexTemp/Blackweb-SmoothCombat/optimized.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("PROFILE ",JSON.stringify(results))
	quit()
