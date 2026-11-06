extends Node3D
## Real 3D set and skinned actor; no artwork cards or video backdrops.
const LENGTH := 42.0
const BRICK := "res://assets/recovered/Arachnophobia/Content/VHExterior/Textures/T_Brick_D_01.png"
const BRICK_NORMAL := "res://assets/recovered/Arachnophobia/Content/VHExterior/Textures/T_Brick_N_01.png"
const SILK := "res://assets/generated/web_master/web_masters.glb"
var camera: Camera3D
var actor: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var door: Node3D
var spider: Node3D
var elapsed := 0.0
var reduced_motion := false
var _head := -1
var _jaw := -1
var _jaw_rest := Quaternion.IDENTITY
var _silks: Array[Node3D] = []
var _mat_brick: StandardMaterial3D
var _mat_trim: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_roof: StandardMaterial3D
var _silk_master: Node
var _strand_material: ShaderMaterial
var _voice_envelope: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists("res://data/town_voice_envelope.json"):
		_voice_envelope = JSON.parse_string(FileAccess.get_file_as_string("res://data/town_voice_envelope.json")).get("samples",[])
	_mat_brick = material(Color(.61,.55,.50), .88)
	_mat_brick.albedo_texture = load(BRICK)
	_mat_brick.normal_enabled = true
	_mat_brick.normal_texture = load(BRICK_NORMAL)
	_mat_brick.uv1_triplanar = true
	_mat_brick.uv1_scale = Vector3.ONE * 1.5
	_mat_trim = material(Color(.13,.15,.14),.75)
	_mat_glass = material(Color(.025,.041,.049),.12)
	_mat_roof = material(Color(.065,.07,.075),.8)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.012,.021,.029)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.38,.49,.61)
	world.environment.ambient_light_energy = .42
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.fog_enabled = true
	world.environment.fog_light_color = Color(.06,.09,.12)
	world.environment.fog_density = .013
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38,-25,0)
	moon.light_color = Color(.57,.70,.86)
	moon.light_energy = .7
	moon.shadow_enabled = true
	add_child(moon)
	var paving := material(Color(.28,.30,.32),.7)
	paving.albedo_texture = load("res://assets/recovered/Arachnophobia/Content/VHExterior/Textures/T_Concrete_D_01.png")
	paving.normal_enabled = true
	paving.normal_texture = load("res://assets/recovered/Arachnophobia/Content/VHExterior/Textures/T_Concrete_N_01.png")
	paving.uv1_triplanar = true
	paving.uv1_scale = Vector3.ONE*.6
	var asphalt := paving.duplicate() as StandardMaterial3D
	asphalt.albedo_color = Color(.065,.075,.085)
	asphalt.roughness = .3
	box(self,"WetRoad",Vector3(0,-.1,-16),Vector3(18,.2,66),asphalt)
	for side in [-1,1]:
		box(self,"RaisedPavement",Vector3(side*5.0,0,-16),Vector3(2,.16,66),paving)
		for z in range(-44,12,3): box(self,"PavementJoint",Vector3(side*5.0,.085,z),Vector3(2,.006,.016),_mat_trim)
	for z in range(-43,12,5): box(self,"RoadMark",Vector3(0,.006,z),Vector3(.075,.01,2),material(Color(.35,.30,.17),.9))
	_silk_master = load(SILK).instantiate()
	_strand_material = ShaderMaterial.new()
	var strand_shader := Shader.new()
	strand_shader.code = "shader_type spatial; render_mode cull_disabled; void vertex(){VERTEX += NORMAL * 0.0025;} void fragment(){ALBEDO=vec3(0.42,0.45,0.44); ROUGHNESS=1.0; SPECULAR=0.0;}"
	_strand_material.shader = strand_shader
	var web_cards: Array[Dictionary] = []
	for row in range(-1,4):
		for side in [-1,1]:
			_build_house(Vector3(side*9.0,.08,-8-row*13), side == 1 and row == 1)
			_lamp(Vector3(side*4.0,.08,-5-row*13))
		_add_web("WebSaggingCanopy",Vector3(0,4.8,-8-row*13),Vector3(3,1.25,2),0)
		_add_web("WebRadialTorn",Vector3(-3.7,2.3,-10-row*13),Vector3.ONE*1.7,PI*.5)
		_add_web("WebRadialTorn",Vector3(3.7,2.6,-11-row*13),Vector3.ONE*1.8,-PI*.5)
		for side in [-1,1]:
			web_cards.append({"center":Vector3(side*5.85,2,-8-row*13),"u":Vector3(0,0,6),"v":Vector3(0,3.4,0),"normal":Vector3(-side,0,0)})
		web_cards.append({"center":Vector3(0,3.5,-9-row*13),"u":Vector3(9,0,0),"v":Vector3(0,3.4,0),"normal":Vector3.BACK})
	var silk_mesh := MeshInstance3D.new()
	var silk_arrays := ArrayMesh.new()
	var surfaces = preload("res://scripts/environment_surfaces.gd")
	silk_arrays.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surfaces.card_arrays(web_cards))
	silk_arrays.surface_set_material(0,surfaces.orb_material())
	silk_mesh.mesh = silk_arrays
	add_child(silk_mesh)
	# A fallen lamp and dense strands force Luke onto the right-hand pavement.
	var fallen := Node3D.new()
	add_child(fallen)
	fallen.position = Vector3(-2.1,.35,-18)
	fallen.rotation.z = -1.23
	box(fallen,"FallenStreetlight",Vector3(0,2.4,0),Vector3(.13,4.8,.13),_mat_trim)
	_add_web("WebRadialTorn",Vector3(0,1.6,-18),Vector3(2.4,1.7,1.4),0)
	_silk_master.free()
	actor = load("res://scenes/luke.tscn").instantiate()
	actor.name = "CinematicLuke"
	add_child(actor)
	skeleton = actor.find_child("Skeleton3D",true,false)
	animation = actor.get_node("AnimationPlayer")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_head = skeleton.find_bone("Bip01 Head")
	_jaw = skeleton.find_bone("Bip01 MJaw")
	_jaw_rest = skeleton.get_bone_pose_rotation(_jaw)
	spider = load("res://scenes/spider_visual.tscn").instantiate()
	spider.name = "StreetSpider"
	spider.scale = Vector3.ONE * .22
	add_child(spider)
	camera = Camera3D.new()
	camera.fov = 52
	camera.far = 95
	add_child(camera)
	camera.make_current()
	var face_fill := OmniLight3D.new()
	face_fill.light_color = Color(.68,.75,.83)
	face_fill.light_energy = .65
	face_fill.omni_range = 6
	camera.add_child(face_fill)
	pose(0)

func material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _build_house(at: Vector3, destination: bool) -> void:
	var house := Node3D.new()
	house.name = "LukesHome" if destination else "GreyhavenHouse"
	house.position = at
	house.rotation.y = -PI*.5 if at.x > 0 else PI*.5
	add_child(house)
	box(house,"RearWall",Vector3(0,1.5,-3),Vector3(8,3,.25),_mat_brick)
	for side in [-1,1]:
		box(house,"SideWall",Vector3(side*3.9,1.5,0),Vector3(.25,3,6),_mat_brick)
		box(house,"FrontWall",Vector3(side*2.35,1.5,3),Vector3(3.3,3,.25),_mat_brick)
	box(house,"DoorLintel",Vector3(0,2.65,3),Vector3(1.4,.7,.25),_mat_brick)
	# Overhanging pitched roof, window recesses, lintels and frames are geometry.
	for side in [-1,1]:
		var roof := box(house,"PitchedRoof",Vector3(side*2.1,3.6,0),Vector3(4.8,.16,6.8),_mat_roof)
		roof.rotation.z = -side*.27
	for x in [-2.7,2.7]:
		box(house,"WindowRecess",Vector3(x,1.75,3.035),Vector3(1.45,1.5,.12),_mat_trim)
		box(house,"WindowGlass",Vector3(x,1.75,3.11),Vector3(1.24,1.26,.04),_mat_glass)
		box(house,"WindowCrossbar",Vector3(x,1.75,3.15),Vector3(1.3,.055,.08),_mat_trim)
		box(house,"WindowMullion",Vector3(x,1.75,3.15),Vector3(.055,1.3,.08),_mat_trim)
		box(house,"StoneSill",Vector3(x,.98,3.16),Vector3(1.6,.12,.32),_mat_trim)
	box(house,"DarkHall",Vector3(0,1.1,0),Vector3(1.36,2.25,.15),material(Color(.009,.007,.006),1))
	var hinge := Node3D.new()
	house.add_child(hinge)
	hinge.position = Vector3(-.58,0,3.16)
	box(hinge,"TimberDoor",Vector3(.58,1.05,0),Vector3(1.16,2.1,.09),material(Color(.12,.075,.04),.8))
	for y in [.55,1.55]: box(hinge,"DoorPanel",Vector3(.58,y,.06),Vector3(.88,.75,.04),_mat_trim)
	box(hinge,"BrassHandle",Vector3(1.0,1.0,.14),Vector3(.06,.2,.09),material(Color(.43,.31,.13),.25))
	box(house,"FrontStep",Vector3(0,.08,3.45),Vector3(1.7,.16,.9),_mat_trim)
	if destination:
		door = hinge
		var porch := OmniLight3D.new()
		porch.position = Vector3(0,2.6,3.7)
		porch.light_color = Color(1,.63,.29)
		porch.light_energy = 1.3
		porch.omni_range = 5
		house.add_child(porch)
		box(house,"PorchBulb",Vector3(0,2.65,3.4),Vector3(.15,.24,.15),material(Color(1,.7,.35),.3))
	_add_web("WebFurnitureCocoon",at + Vector3(0,0,2.0),Vector3(2.0,2.0,2.0),0)
	_add_web("WebSaggingCanopy",at + Vector3(0,3.5,0),Vector3(2.4,1.1,2),0)

func _lamp(at: Vector3) -> void:
	box(self,"StreetLampPost",at+Vector3(0,2.6,0),Vector3(.12,5.2,.12),_mat_trim)
	box(self,"LampHead",at+Vector3(0,5.2,0),Vector3(.5,.16,.32),_mat_trim)
	var light := OmniLight3D.new()
	light.position = at+Vector3(0,4.9,0)
	light.light_color = Color(.62,.75,.77)
	light.light_energy = 1.8
	light.omni_range = 9
	add_child(light)

func _add_web(kind: String, at: Vector3, size: Vector3, yaw: float) -> void:
	var source := _silk_master.find_child(kind,true,false) as Node3D
	if source == null: return
	var web := source.duplicate() as Node3D
	web.position = at
	web.scale = size
	web.rotation.y = yaw
	for mesh in web.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = _strand_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if web is MeshInstance3D: web.material_override = _strand_material
	add_child(web)
	_silks.append(web)

func _turn_bone(index: int, axis_world: Vector3, amount: float) -> void:
	if index < 0: return
	var bone := skeleton.get_bone_global_pose(index)
	var axis := skeleton.global_basis.inverse() * axis_world
	bone.basis = Basis(axis.normalized(),amount) * bone.basis
	skeleton.set_bone_global_pose_override(index,bone,1.0,true)

func _travel_progress(time: float, start: float, end: float) -> float:
	var duration := end-start
	var phase := clampf(time-start,0.0,duration)
	var ramp := 0.5
	var distance := phase-ramp*.5
	if phase < ramp: distance = phase*phase/(2.0*ramp)
	elif phase > duration-ramp: distance = duration-ramp-pow(duration-phase,2)/(2.0*ramp)
	return distance/(duration-ramp)

func pose(time: float) -> void:
	elapsed = clampf(time,0,LENGTH)
	var t := elapsed
	skeleton.clear_bones_global_pose_override()
	# Deterministic skeletal crossfade, including offline rendering and seeking.
	# Seeking a single clip discarded AnimationPlayer's ordinary crossfade.
	var weight := 1.0-smoothstep(8.5,9.0,t)
	weight = maxf(weight, smoothstep(21,21.5,t)*(1.0-smoothstep(30.5,31,t)))
	weight = maxf(weight, smoothstep(35,35.5,t)*(1.0-smoothstep(40.5,41,t)))
	animation.play("idle")
	animation.seek(fmod(t,animation.get_animation("idle").length),true)
	var idle_pose: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): idle_pose.append(skeleton.get_bone_pose(bone))
	animation.play("walk")
	animation.seek(fmod(t,animation.get_animation("walk").length),true)
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose(bone,idle_pose[bone].interpolate_with(skeleton.get_bone_pose(bone),weight))
	actor.position = Vector3(-2.3,.08,lerpf(3.5,-5.95,_travel_progress(t,0,9)))
	actor.rotation.y = 0
	if t >= 9 and t < 21:
		actor.position.z += .45*sin(PI*clampf((t-12)/2,0,1))
		actor.rotation.y = .3*sin((t-9)*.45)
	if t >= 21:
		actor.position = Vector3(-2.3,.08,-5.95).lerp(Vector3(3.5,.08,-17.3),_travel_progress(t,21,31))
		actor.rotation.y = lerp_angle(.3*sin(12*.45),-.47,smoothstep(21,21.5,t))
	if t >= 31:
		actor.position = Vector3(3.5,.08,-17.3).lerp(Vector3(6.4,.08,-21),smoothstep(35,41,t))
		actor.rotation.y = lerp_angle(-.47,-.665,smoothstep(31,32,t))
	var reaction := sin(smoothstep(12,15,t)*PI)*.85
	var alert := smoothstep(8.5,9.5,t)*(1.0-smoothstep(20.5,21.5,t))
	_turn_bone(_head,Vector3.UP, sin(t*.8)*lerpf(.12,.45,alert))
	_turn_bone(skeleton.find_bone("Bip01 Spine2"),Vector3.RIGHT,reaction*.35)
	# Authored recoil: both arms rise defensively, then settle back into breathing.
	_turn_bone(skeleton.find_bone("Bip01 R UpperArm"),actor.global_basis.x,reaction*.9)
	_turn_bone(skeleton.find_bone("Bip01 L UpperArm"),actor.global_basis.x,reaction*.8)
	_turn_bone(skeleton.find_bone("Bip01 R Forearm"),actor.global_basis.x,reaction*.8)
	skeleton.set_bone_pose_rotation(_jaw,_jaw_rest)
	var frame := clampi(int(t*25),0,maxi(0,_voice_envelope.size()-2))
	if _voice_envelope.size()>1:
		var mouth := lerpf(float(_voice_envelope[frame]),float(_voice_envelope[frame+1]),fmod(t*25,1))
		_turn_bone(_jaw,actor.global_basis.x,mouth*.16)
	spider.position = Vector3(lerpf(2.0,-3.5,smoothstep(10,14,t)),.10,-8.5)
	spider.rotation.y = PI*.5
	var spider_anim := spider.find_child("*AnimationPlayer*",true,false) as AnimationPlayer
	if spider_anim != null and not spider_anim.get_animation_list().is_empty():
		var spider_clip: StringName = spider_anim.get_animation_list()[0]
		for candidate in spider_anim.get_animation_list():
			if "walk" in candidate.to_lower(): spider_clip = candidate
		spider_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		spider_anim.play(spider_clip)
		spider_anim.seek(fmod(t, maxf(.1,spider_anim.get_animation(spider_clip).length)),true)
	if door != null: door.rotation.y = -1.1*smoothstep(36,39,t)
	for i in _silks.size(): _silks[i].rotation.z = sin(t*.65+i)*.008
	var target := actor.position + Vector3(0,1.25,0)
	if t < 6:
		camera.position = actor.position + Vector3(-2.5,1.65,-4)
	elif t < 10:
		camera.position = Vector3(2.5,3.0,1.2)
		target = Vector3(-.4,2,-24)
	elif t < 12:
		camera.position = Vector3(-.4,.43,-5.2)
		target = spider.position+Vector3(0,.16,0)
	elif t < 16:
		camera.position = actor.position+Vector3(-.75,1.5,-2.1)
		target = actor.position+Vector3(0,1.15,0)
	elif t < 21:
		camera.position = actor.position + Vector3(-.55,1.65,-1.5)
		target = actor.position+Vector3(0,1.48,0)
	elif t < 31:
		camera.position = actor.position+Vector3(-3,2.2,3.2)
		target = actor.position+Vector3(1,1,-3)
	else:
		camera.position = Vector3(1.2,1.8,-23.5)
		target = actor.position+Vector3(0,1.2,0)
	camera.look_at(target)
