extends Node3D
## Enclosed outdoor combat space. Architecture is merged by material after build;
## repeated ironwork and branches share surfaces instead of hundreds of draw calls.
const EXTERIOR := "res://assets/recovered/Arachnophobia/Content/VHExterior/Textures/"
const Surfaces = preload("res://scripts/environment_surfaces.gd")
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var web_master: Node
var shadow_light: DirectionalLight3D

func _ready() -> void:
	name = "OutdoorGarden"
	_rng.seed = 1204
	_make_materials()
	_lighting()
	_box("Courtyard",Vector3(0,-.16,0),Vector3(22,.32,27),"paving",true)
	_box("TownGround",Vector3(0,-.3,-25),Vector3(100,.25,90),"soil")
	for x in [-10.5,10.5]:
		_box("GardenBoundary",Vector3(x,1.0,0),Vector3(.5,2,27),"brick",true)
		_box("Coping",Vector3(x,2.04,0),Vector3(.68,.16,27),"stone")
		for z in range(-13,14,3):
			_box("Pier",Vector3(x,1.3,z),Vector3(.8,2.6,.8),"brick")
			_box("PierCap",Vector3(x,2.65,z),Vector3(.96,.16,.96),"stone")
		for z in range(-52,53):
			_box("IronSpear",Vector3(x,2.45,z*.25),Vector3(.028,.85,.028),"iron")
		for h in [2.17,2.65]: _box("IronRail",Vector3(x,h,0),Vector3(.045,.045,27),"iron")
	for x in [-6.4,6.4]:
		_box("RearWall",Vector3(x,1.3,-13.2),Vector3(8.1,2.6,.5),"brick",true)
		_box("RearCoping",Vector3(x,2.63,-13.2),Vector3(8.2,.18,.7),"stone")
	# Gate silhouettes the greenhouse. It is visibly locked during this encounter.
	_box("GateCollision",Vector3(0,1.5,-13.15),Vector3(4.3,3,.18),"invisible",true)
	for x in range(-8,9):
		_box("GateBar",Vector3(x*.25,1.35,-13.1),Vector3(.045,2.7,.055),"iron")
	for y in [.24,1.3,2.45]: _box("GateCross",Vector3(0,y,-13.12),Vector3(4.2,.07,.08),"iron")
	_house(Vector3(0,0,16.4),0,true)
	_greenhouse(Vector3(0,0,-21))
	for side in [-1,1]:
		for z in [-30,-45]: _house(Vector3(side*18,0,z),side*.25,false)
		for z in [-8.0,-2.0,4.0]:
			_box("GardenBed",Vector3(side*8.7,.22,z),Vector3(2.5,.44,4),"stone")
			_box("DarkSoil",Vector3(side*8.7,.45,z),Vector3(2.2,.03,3.7),"soil")
			# Keep all detailed debris beyond the clear fighting lane.
			for i in 8:
				var at := Vector3(side*(8.1+_rng.randf()*.9),.47,z+_rng.randf_range(-1.6,1.6))
				_branch(at,at+Vector3(_rng.randf_range(-.3,.3),_rng.randf_range(.25,.75),.1),.025)
		for z in [-18,-8,6]: _tree(Vector3(side*13.0,0,z))
	for z in range(-12,13,2):
		for x in range(-9,10,2):
			_box("PavingJoint",Vector3(x,.003,z),Vector3(1.98,.004,.013),"soil")
	for i in 20:
		var at := Vector3(_rng.randf_range(-9.5,9.5),.016,_rng.randf_range(-12,12))
		if absf(at.x)<4.0: at.x += 4.6 * (1 if at.x>=0 else -1)
		_box("BrokenMasonry",at+Vector3.UP*.035,Vector3(.22,.07,.12),"brick",false,Vector3(0,_rng.randf()*TAU,0))
	_flush()
	_webs_and_stains()
	var sign := Label3D.new()
	sign.text = "RESEARCH ANNEX\nKEEP GATE CLOSED"
	sign.position = Vector3(0,1.75,-12.96)
	sign.font_size = 36
	sign.pixel_size = .008
	sign.modulate = Color("b7afa0")
	add_child(sign)

func _make_materials() -> void:
	for entry in [["brick","8f8275",.86],["paving","656b69",.60],["stone","686963",.85],["wood","282821",.9],["roof","25292b",.72],["iron","1c2221",.43],["glass","182c30",.17],["soil","151916",.95],["warm","c7864d",.6]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(entry[1])
		m.roughness = entry[2]
		_materials[entry[0]] = m
	for key in ["brick","paving","stone"]:
		var m: StandardMaterial3D = _materials[key]
		var texture := "Brick" if key=="brick" else "Concrete"
		m.albedo_texture = load(EXTERIOR+"T_"+texture+"_D_01.png")
		m.normal_enabled = true
		m.normal_texture = load(EXTERIOR+"T_"+texture+"_N_01.png")
		m.normal_scale = .65
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * (.9 if key=="brick" else .35)
	var lamp: StandardMaterial3D = _materials.warm
	lamp.emission_enabled = true
	lamp.emission = Color("d39457")
	lamp.emission_energy_multiplier = 1.3

func _lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("050a10")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9ab2c6")
	env.ambient_light_energy = .26
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("0b141c")
	env.fog_density = .012
	world.environment = env
	add_child(world)
	shadow_light = DirectionalLight3D.new()
	shadow_light.name = "GardenMoon"
	shadow_light.rotation_degrees = Vector3(-48,-30,0)
	shadow_light.light_color = Color("b4c9de")
	shadow_light.light_energy = .68
	shadow_light.shadow_enabled = true
	shadow_light.directional_shadow_max_distance = 36.0
	shadow_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(shadow_light)
	for datum in [[Vector3(-4,3.4,9),Color("edb878"),3.4,17.0],[Vector3(5,3.8,-9),Color("9bbab8"),3.0,17.0],[Vector3(0,2.5,-21),Color("b7432f"),4.0,13.0]]:
		var light := OmniLight3D.new()
		light.position = datum[0]
		light.light_color = datum[1]
		light.light_energy = datum[2]
		light.omni_range = datum[3]
		add_child(light)

func _box(label: String, at: Vector3, size: Vector3, key: String, solid := false, angles := Vector3.ZERO) -> void:
	if key != "invisible":
		var mesh := BoxMesh.new()
		mesh.size = size
		if not _batches.has(key): _batches[key] = []
		_batches[key].append([mesh,Transform3D(Basis.from_euler(angles),at)])
	if solid:
		var body := StaticBody3D.new()
		body.name = label
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.transform = Transform3D(Basis.from_euler(angles),at)
		add_child(body)

func _house(at: Vector3, yaw: float, hero: bool) -> void:
	var basis := Basis(Vector3.UP,yaw)
	# Front faces the garden (-Z); roof pitches, gutters, deep sills and boarded
	# window recesses are modeled layers with actual thickness.
	_box("HouseBoundary",at+Vector3(0,2.2,0),Vector3(12,4.4,7),"brick",hero)
	for side in [-1,1]:
		_box("RoofPitch",at+basis*Vector3(side*3.0,4.8,0),Vector3(6.8,.16,8),"roof",false,Vector3(0,yaw,-side*.32))
		_box("Gutter",at+Vector3(side*6.35,3.8,0),Vector3(.13,.14,8),"iron")
	_box("Chimney",at+Vector3(-3,5.4,1.5),Vector3(.8,2.3,.9),"brick")
	_box("ChimneyCap",at+Vector3(-3,6.6,1.5),Vector3(1,.15,1.1),"stone")
	for x in [-4.0,3.8]:
		for y in [1.7,3.2]:
			_box("WindowFrame",at+Vector3(x,y,-3.55),Vector3(1.7,1.15,.16),"wood")
			_box("WindowPane",at+Vector3(x,y,-3.65),Vector3(1.43,.91,.04),"glass")
			_box("WindowMullion",at+Vector3(x,y,-3.69),Vector3(.06,1,.07),"stone")
			_box("WindowCrossbar",at+Vector3(x,y,-3.70),Vector3(1.45,.05,.07),"stone")
			_box("WindowSill",at+Vector3(x,y-.58,-3.70),Vector3(1.85,.13,.37),"stone")
		if hero: _box("WindowBoard",at+Vector3(x,1.6,-3.8),Vector3(2,.18,.08),"wood",false,Vector3(0,0,.18))
	_box("HouseDoorFrame",at+Vector3(0,1.3,-3.55),Vector3(1.6,2.6,.22),"stone")
	_box("HouseDoor",at+Vector3(0,1.2,-3.7),Vector3(1.32,2.4,.1),"wood")
	for y in [.6,1.6]: _box("DoorPanel",at+Vector3(0,y,-3.77),Vector3(1.02,.72,.05),"roof")
	_box("PorchStep",at+Vector3(0,.08,-3.9),Vector3(2.1,.16,.9),"stone")
	_box("PorchBulb",at+Vector3(-1.15,2.8,-3.8),Vector3(.15,.24,.12),"warm")

func _greenhouse(at: Vector3) -> void:
	_box("AnnexPlinth",at+Vector3(0,.22,0),Vector3(8,.44,9),"stone")
	for side in [-1,1]:
		for z in range(-4,5,2):
			_box("GreenhousePost",at+Vector3(side*4,1.8,z),Vector3(.11,3.2,.11),"iron")
			_box("RoofRafter",at+Vector3(side*2,3.8,z),Vector3(4.4,.10,.10),"iron",false,Vector3(0,0,-side*.38))
		_box("GreenhouseGlass",at+Vector3(side*4,1.9,0),Vector3(.04,2.8,8),"glass")
	for x in range(-4,5,2):
		_box("FrontFrame",at+Vector3(x,1.8,4),Vector3(.10,3.2,.12),"iron")
	_box("GreenhouseRidge",at+Vector3(0,4.65,0),Vector3(.12,.12,8.5),"iron")
	_box("AnnexLight",at+Vector3(0,2.9,3.9),Vector3(2,.08,.08),"warm")

func _branch(a: Vector3, b: Vector3, radius: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius*.42
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	cylinder.rings = 1
	if not _batches.has("wood"): _batches.wood = []
	_batches.wood.append([cylinder,Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5)])

func _tree(at: Vector3) -> void:
	var top := at+Vector3(.3,6.5,0)
	_branch(at,top,.31)
	for i in 8:
		var a := at+Vector3(.15,2.1+i*.45,0)
		var angle := i*2.399
		var b := a+Vector3(cos(angle)*2,1.6,sin(angle)*2)
		_branch(a,b,.10)
		_branch(b,b+Vector3(cos(angle+.5),1.1,sin(angle+.5)),.045)

func _flush() -> void:
	for key: String in _batches:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in _batches[key]: surface.append_from(part[0],0,part[1])
		var node := MeshInstance3D.new()
		node.name = "MergedGarden_"+key
		node.mesh = surface.commit()
		node.material_override = _materials[key]
		add_child(node)
	_batches.clear()

func _webs_and_stains() -> void:
	web_master = load("res://assets/generated/web_master/web_masters.glb").instantiate()
	for x in [-8.0,-4.5,4.5,8.0]:
		_web("WebRadialTorn",Vector3(x,2,-12.8),Vector3(1.2,1.2,1.2),0)
		_web("WebRadialTorn",Vector3(x,2.9,12.65),Vector3(1.3,1.3,1.3),PI)
	for side in [-1,1]:
		for z in [-8,2,10]:
			_web("WebRadialTorn",Vector3(side*10.1,2.4,z),Vector3.ONE*1.3,side*PI*.5)
	_web("WebSaggingCanopy",Vector3(0,4.9,-11.5),Vector3(3.2,.7,1.4),0)
	_web("WebSaggingCanopy",Vector3(0,5.2,11.7),Vector3(3.1,.65,1.3),0)
	_web("WebFurnitureCocoon",Vector3(8.7,.7,-6),Vector3(1.3,1.5,2.5),.2)
	_web("WebRadialTorn",Vector3(0,3.3,-16),Vector3(2.7,1.8,1.5),0)
	web_master.free()
	var stains: Array[Dictionary] = []
	for at in [Vector3(-6,.015,-4),Vector3(5,.014,6),Vector3(3,.013,-9)]:
		stains.append({"center":at,"u":Vector3(3,0,0),"v":Vector3(0,0,2.5),"normal":Vector3.UP})
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,Surfaces.card_arrays(stains))
	var pools := MeshInstance3D.new()
	pools.mesh = mesh
	pools.material_override = Surfaces.goo_material(true)
	pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pools)

func _web(label: String, at: Vector3, size: Vector3, yaw: float) -> void:
	var source := web_master.find_child(label,true,false) as Node3D
	if not source: return
	var web := source.duplicate() as Node3D
	web.position = at
	web.scale = size
	web.rotation.y = yaw
	add_child(web)
