extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.msaa_3d = Viewport.MSAA_2X
	var town = load("res://scripts/town_cinematic.gd").new()
	root.add_child(town)
	var output := ProjectSettings.globalize_path("res://../Evidence/Town3D")
	DirAccess.make_dir_recursive_absolute(output)
	for t in [2.0,8.0,11.0,13.5,17.7,25.8,34.0,39.0]:
		town.pose(t)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/shot-%.1f.png" % t)
		if town.actor.position.y < 0: errors.append("Actor below ground")
	var start: Vector3 = town.actor.position
	town.pose(2)
	if start.distance_to(town.actor.position) < 10: errors.append("Actor does not traverse the set")
	town.pose(17.3)
	var jaw: Transform3D = town.skeleton.get_bone_global_pose_override(town._jaw)
	town.pose(17.4)
	if jaw.is_equal_approx(town.skeleton.get_bone_global_pose_override(town._jaw)): errors.append("No voiced jaw reaction")
	print("TOWN_SCENE ",JSON.stringify({"errors":errors,"silk_instances":town._silks.size()}))
	quit(0 if errors.is_empty() else 1)
