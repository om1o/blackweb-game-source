extends SceneTree
## Native only: --script res://tools/capture_town_references.gd -- --with-luke
## Default references omit Luke so outdated character identity cannot leak into generation.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var with_luke := OS.get_cmdline_user_args().has("--with-luke")
	var output := "D:/CodexTemp/Blackweb-Luke21/ReferenceFrames"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.msaa_3d = Viewport.MSAA_2X
	var town := load("res://scripts/town_cinematic.gd").new() as Node3D
	root.add_child(town)
	await process_frame
	town.actor.visible = with_luke
	var captures: Array = []
	var times := [8.0,11.0,39.0]
	if with_luke: times = [2.0,8.0,13.2,17.7,25.8,34.0,38.8,39.4,40.6]
	for at in times:
		town.pose(at)
		for warm_frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join("town-%04.1f-%s.png" % [at,"luke" if with_luke else "environment"])
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Cannot write town reference: " + path)
			quit(1)
			return
		captures.append({"time":at,"path":path,"actor_visible":with_luke})
	var report := {"scene_sha256":FileAccess.get_sha256("res://scripts/town_cinematic.gd"),"luke_sha256":FileAccess.get_sha256("res://scenes/luke.tscn"),"captures":captures}
	FileAccess.open(output.path_join("references-%s.json" % ("luke" if with_luke else "environment")),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TOWN_REFERENCES ",JSON.stringify(report))
	quit()
