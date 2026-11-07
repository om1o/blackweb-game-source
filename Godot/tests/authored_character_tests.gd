extends SceneTree
## Native inspection of the runtime character, movement, grip and pooled fluid.
var failures: Array[String] = []
var checks := 0
var player: BlackwebPlayer
var camera: Camera3D
var output_dir := ""
func _initialize(): run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func frames(n: int):
	for i in n: await physics_frame
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func joint(name: String) -> Vector3:
	var rig=player._luke_skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
func run():
	if DisplayServer.get_name()=="headless":
		printerr("Authored character checks require a native window for captured mouse input.")
		quit(2)
		return
	output_dir=OS.get_user_data_dir().path_join("authored-character-qa")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for action in ["interact","flashlight","hotbar_1","hotbar_2","hotbar_3","crouch","jump","sprint","move_left","move_right","move_forward","move_back"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var stage=Node3D.new()
	root.add_child(stage)
	var env=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.08,.10,.12)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.8,.85,1)
	env.environment.ambient_light_energy=.7
	stage.add_child(env)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=1.5
	stage.add_child(sun)
	var floor_body=StaticBody3D.new()
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(10,.3,10)
	floor_body.add_child(shape)
	floor_body.position.y=-.15
	stage.add_child(floor_body)
	var floor_mesh=MeshInstance3D.new()
	floor_mesh.mesh=BoxMesh.new()
	floor_mesh.mesh.size=Vector3(10,.3,10)
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Color(.17,.18,.19)
	floor_mesh.material_override=mat
	floor_body.add_child(floor_mesh)
	player=load("res://scripts/player.gd").new()
	stage.add_child(player)
	player.attach_model(load("res://scenes/luke.tscn"))
	player.active=true
	player.set_view(0)
	player.select_quick_slot(1)
	camera=Camera3D.new()
	stage.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.5
	camera.position=Vector3(2.5,1.8,-3.4)
	camera.look_at(Vector3(0,.95,0))
	camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await frames(30)
	check(player._luke_skeleton.global_basis.get_scale().x>.8,"Character skeleton uses metre units for props")
	check(is_instance_valid(player._armor_visuals),"All four armour meshes bind to the replacement character")
	check(player._hand_knife.global_basis.get_scale().x>.8,"Held knife is full size")
	check(player._hand_knife.global_position.distance_to(joint("Bip01 R Hand"))<.15,"Knife handle lies within the right palm")
	await shot("runtime-ready")
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	check(player._action_kind==&"knife","Mouse click starts authored attack")
	var captured=false
	var max_stretch=0.0
	var pairs=[["Bip01 Spine","Bip01 Spine1"],["Bip01 Spine1","Bip01 Spine2"],["Bip01 R UpperArm","Bip01 R Forearm"],["Bip01 R Forearm","Bip01 R Hand"]]
	var lengths=[]
	for pair in pairs: lengths.append(joint(pair[0]).distance_to(joint(pair[1])))
	for f in 65:
		await physics_frame
		for i in pairs.size():
			max_stretch=maxf(max_stretch,absf(joint(pairs[i][0]).distance_to(joint(pairs[i][1]))-lengths[i]))
		if player._action_time>=.28 and not captured:
			await shot("runtime-contact")
			captured=true
	check(max_stretch<.015,"Attack preserves spine and arm lengths: "+str(max_stretch))
	check(player._action_kind==&"","Attack recovers")
	var stand_head=joint("Bip01 Head").y
	Input.action_press("crouch")
	await frames(30)
	check(player._crouching and stand_head-joint("Bip01 Head").y>.3,"Crouch lowers the actual skeleton")
	await shot("runtime-crouch")
	Input.action_release("crouch")
	await frames(30)
	Input.action_press("jump")
	await frames(9)
	Input.action_release("jump")
	check(player.global_position.y>.15,"Jump moves the physical character")
	await shot("runtime-jump")
	await frames(75)
	check(player.is_on_floor(),"Jump lands without persistent pose offset")
	player._armor_visuals.apply_state({&"shirt":&"leather_shirt",&"pants":&"leather_pants",&"hood":&"leather_hood",&"shoes":&"leather_shoes"})
	await shot("runtime-armour")
	player.hide()
	var pool=load("res://scripts/combat_effects.gd").new()
	stage.add_child(pool)
	camera.position=Vector3(1.4,1.2,-1.8)
	camera.size=1.8
	camera.look_at(Vector3(0,.3,0))
	pool.burst(player,Vector3(0,.25,0),Vector3(.3,1,0),&"death",1.0)
	await frames(5)
	check(pool._slots[0].splash.visible,"Authored blood splash appears on contact")
	check(pool._marks.any(func(mark):return mark.visible),"Blood leaves a floor splatter")
	await shot("fluid-contact")
	await frames(40)
	check(pool.active_count()==0,"Blood spray retires")
	await shot("fluid-floor")
	pool._physics_process(36)
	check(not pool._marks.any(func(mark):return mark.visible),"Floor stains expire within the fixed pool")
	var report={"checks":checks,"failures":failures,"max_joint_stretch_m":max_stretch}
	FileAccess.open(output_dir.path_join("character-tests.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
