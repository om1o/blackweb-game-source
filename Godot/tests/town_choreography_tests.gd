extends SceneTree
## Structural cinematic checks; native reference captures still judge the composition.
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: _run.call_deferred()
func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
func _run() -> void:
	var town := load("res://scripts/town_cinematic.gd").new() as Node3D
	root.add_child(town)
	await process_frame
	check(town._door_motion != null and town._door_motion.clips.has("Open_Door_Push"),"Acquired PINOC door push motion is available")
	check(get_nodes_in_group("town_parked_cars").size() == 3,"Three parked or abandoned cars establish the street")
	check(get_nodes_in_group("town_shopfronts").size() == 2,"Two shopfronts distinguish the town from repeated houses")
	check(town.spider.scale.x >= .55,"Cinematic spider silhouette is larger")
	var max_error := 0.0
	var minimum_foot_height := INF
	var contacts: Array = []
	for at in [0.0,8.0,12.5,13.2,13.8,17.2,25.8,33.0,35.0,36.0,37.0,38.0,38.5,39.0,39.5,40.0,40.5,41.0]:
		town.pose(at)
		var rig: Skeleton3D = town.skeleton
		for foot in ["Bip01 L Foot","Bip01 R Foot"]:
			var height := (rig.global_transform*rig.get_bone_global_pose(rig.find_bone(foot)).origin).y
			minimum_foot_height = minf(minimum_foot_height,height)
		for index in rig.get_bone_count():
			var parent := rig.get_bone_parent(index)
			if parent<0 or rig.get_bone_name(index)=="Bip01 Pelvis": continue
			var expected := rig.get_bone_pose_position(index).length()
			var measured := rig.get_bone_global_pose(index).origin.distance_to(rig.get_bone_global_pose(parent).origin)
			max_error = maxf(max_error,absf(expected-measured))
		if at >= 38.5 and at <= 40.0:
			var hand: Vector3 = rig.global_transform * rig.get_bone_global_pose(rig.find_bone("Bip01 L Hand")).origin
			var local_hand: Vector3 = town.door.to_local(hand)
			contacts.append({"time":at,"hand_in_door_space":[local_hand.x,local_hand.y,local_hand.z]})
	check(max_error < .0001,"Layered recoil and door motion retain bone lengths")
	check(minimum_foot_height > -.03,"Retargeted movement keeps both feet above the street")
	for row in contacts:
		if row.time == 39.0 or row.time == 39.5:
			check(absf(float(row.hand_in_door_space[2])-.10)<.025,"Pushing palm stays against the moving door at %.1f s" % row.time)
	town.pose(38.4)
	check(is_zero_approx(town.door.rotation.y),"Door remains shut during the physical approach")
	town.pose(39.5)
	check(town.door.rotation.y > .75,"Door moves inward during the pushing action")
	town.pose(41.6)
	check(town.actor.position.x > 6.5,"Luke crosses the open doorway before the cut to gameplay")
	var report := {"checks":checks,"failures":failures,"max_bone_length_error_m":max_error,"minimum_foot_bone_y_m":minimum_foot_height,"door_hand_samples":contacts}
	print("TOWN_CHOREOGRAPHY ",JSON.stringify(report))
	town.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
