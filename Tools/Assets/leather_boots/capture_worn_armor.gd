extends SceneTree
var checks := 0
var failures: Array[String] = []
var player: CharacterBody3D
var review_camera: Camera3D
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print(("PASS " if value else "FAIL ")+label)
func capture(label: String, camera_position: Vector3, target := Vector3(0,0.95,0)) -> void:
	review_camera.position = camera_position
	review_camera.look_at(target)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/armor-native-"+label+".png")
	check(error == OK, label+" native capture saved")
func pose(clip: String, time: float, crouch := false, jump := false, knife := false) -> void:
	player._locomotion_pose.clear()
	player._luke_skeleton.clear_bones_global_pose_override()
	player._animation.play(clip)
	player._animation.seek(time,true)
	player._animation.pause()
	player._locomotion_pose.apply(1.0,crouch,jump,2.0,Vector3.FORWARD)
	player._action_kind = &"knife" if knife else &""
	player._action_time = .24 if knife else 0.
	player.selected_quick_index = 1 if knife else 0
	player._update_right_arm_pose(1.0)
	player._update_held_item_visuals(true,1.0)
func _run() -> void:
	for action in [&"move_left",&"move_right",&"move_forward",&"move_back",&"sprint",&"crouch",&"jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	root.size = Vector2i(1100,900)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.13,.14,.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.74,.79,.85)
	env.ambient_light_energy = .7
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45,-35,0)
	key.light_energy = 1.4
	stage.add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5,.05,5)
	floor_mesh.mesh = box
	floor_mesh.position.y = -.035
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.16,.17,.18)
	floor_material.roughness = .9
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = box.size
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = floor_mesh.position
	stage.add_child(floor_body)
	player = load("res://scripts/player.gd").new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var slots := [&"shirt",&"pants",&"hood",&"shoes"]
	var ids := [&"leather_shirt",&"leather_pants",&"leather_hood",&"leather_shoes"]
	for id in ids: player.add_item(id,1)
	var saved: Dictionary = player.survival_snapshot()
	saved.armor = {&"shirt":&"leather_shirt",&"pants":&"leather_pants",&"hood":&"leather_hood",&"shoes":&"leather_shoes"}
	check(player.restore_survival_state(saved), "saved armor restores before Luke is attached")
	player.attach_model(load("res://scenes/luke.tscn"))
	check(is_instance_valid(player._armor_visuals), "player attaches garment controller")
	if not is_instance_valid(player._armor_visuals):
		quit(1)
		return
	check(player._armor_visuals.visual_state().values().all(func(value): return value), "saved-before-attach displays all four pieces")
	for i in 4:
		check(player.unequip_armor(slots[i]) and not player._armor_visuals.visual_state()[slots[i]], str(slots[i])+" removes worn mesh")
		var cell := -1
		for index in 50:
			if player.inventory.item_at(index) == ids[i]: cell = index
		check(player.equip_armor(cell) and player._armor_visuals.visual_state()[slots[i]], str(slots[i])+" equips worn mesh without duplicating item")
		check(player.item_count(ids[i]) == 1, str(slots[i])+" inventory ownership conserved")
	review_camera = Camera3D.new()
	review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	review_camera.size = 2.1
	stage.add_child(review_camera)
	review_camera.make_current()
	player.visual.visible = true
	pose(player._idle_clip,.5)
	if "--diagnose-armor" in OS.get_cmdline_user_args():
		var highlight := StandardMaterial3D.new()
		highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		highlight.albedo_color = Color(1,0,1)
		player._armor_visuals._body.material_override = highlight
		review_camera.size = .85
		await capture("diagnostic-body",Vector3(2,1.6,-3.5),Vector3(0,1.42,0))
		player._armor_visuals._body.visible = false
		await capture("diagnostic-garment",Vector3(2,1.6,-3.5),Vector3(0,1.42,0))
		player._armor_visuals._body.visible = true
		player._armor_visuals._body.material_override = null
		review_camera.size = 2.1
	await capture("front", Vector3(2.0,1.3,-3.5))
	await capture("back", Vector3(-2.0,1.3,3.5))
	review_camera.size = .85
	await capture("front-detail",Vector3(2,1.6,-3.5),Vector3(0,1.42,0))
	await capture("back-detail",Vector3(-2,1.6,3.5),Vector3(0,1.42,0))
	review_camera.size = 2.1
	pose(player._walk_clip,.34)
	await capture("walk", Vector3(2.3,1.2,-3.1))
	player._locomotion_pose.clear()
	player._action_kind = &""
	player.active = true
	player._animation.play(player._idle_clip)
	player.set_physics_process(true)
	Input.action_press("crouch")
	for frame in 40: await physics_frame
	player.set_physics_process(false)
	Input.action_release("crouch")
	check(player.is_crouching(), "real crouch input reached crouching state")
	await capture("crouch", Vector3(2.3,1.1,-3.1),Vector3(0,.72,0))
	player._set_crouch(false)
	player._locomotion_pose.clear()
	player.set_physics_process(true)
	for frame in 10: await physics_frame
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for frame in 10: await physics_frame
	player.set_physics_process(false)
	check(player.position.y > 0.10, "real jump input lifted the player above the floor")
	await capture("jump", Vector3(2.3,1.2+player.position.y,-3.1),Vector3(0,.95+player.position.y,0))
	player.position = Vector3.ZERO
	pose(player._idle_clip,.5,false,false,true)
	await capture("knife", Vector3(2.3,1.2,-3.1))
	review_camera.size = .85
	await capture("knife-detail",Vector3(2,1.6,-3.5),Vector3(0,1.42,0))
	review_camera.size = 2.1
	pose(player._idle_clip,.5)
	for slot in slots: check(player.unequip_armor(slot), str(slot)+" final unequip accepted")
	check(player._armor_visuals.visual_state().values().all(func(value): return not value), "all garments hidden after final unequip")
	await capture("unequipped", Vector3(2.0,1.3,-3.5))
	var file := FileAccess.open("D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/armor-native-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":checks-failures.size(),"failures":failures},"  "))
	file.close()
	print("ARMOR_NATIVE ",checks-failures.size(),"/",checks," ",failures)
	player._cancel_item_action()
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("stop_all"): audio.stop_all()
	stage.queue_free()
	player = null
	review_camera = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
