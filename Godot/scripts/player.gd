class_name BlackwebPlayer
extends CharacterBody3D

signal focus_changed(text: String)
signal health_changed(value: float)
signal recovery_changed(active: bool)
signal stamina_changed(value: float)
signal flashlight_changed(on: bool)
signal battery_changed(value: float)
signal inventory_changed()
signal quick_slot_changed(index: int)

const ItemAudio = preload("res://scripts/item_audio.gd")
const InventoryGrid = preload("res://scripts/inventory_grid.gd")
const LocomotionPose = preload("res://scripts/locomotion_pose.gd")
const CandyWrapperTexture = preload("res://assets/generated/candy_wrapper_aged_v1.png")
const SupplyModels = preload("res://scripts/supply_models.gd")

var progression: Node
var camera: Camera3D
var pivot: Node3D
var arm: SpringArm3D
var lamp: SpotLight3D
var visual: Node3D
var spawn_transform := Transform3D.IDENTITY
var active := false
var health := 100.0
var sensitivity := 0.0024
var _pitch := -0.09
var _yaw := 0.0
var _spawn_yaw := 0.0
var _recovering := false
var _recovery_generation := 0
var _hurt_time := 0.0
var _focused: Node3D
var _focus_prompt := ""
var _light_on := true
var starting_battery_charge := 22.0
var battery_charge := 22.0
var _battery_reported := 22.0
var _flicker_clock := 0.0
var _flicker_off_remaining := 0.0
var _beam_scan_remaining := 0.0
var _knife_cooldown := 0.0
var _flare_remaining := 0.0
var _flare_light: OmniLight3D
var _grip_fill: OmniLight3D
var _hand_flashlight: Node3D
var _view_flashlight: Node3D
var _hand_mount: BoneAttachment3D
var _luke_skeleton: Skeleton3D
var _locomotion_pose: BlackwebLocomotionPose = LocomotionPose.new()
var _right_upper_bone := -1
var _right_forearm_bone := -1
var _right_hand_bone := -1
var _right_grip_fingers: Array[Dictionary] = []
var _arm_pose_weight := 0.0
var _hand_knife: Node3D
var _view_knife: Node3D
var _knife_wrist_override_applied := false
var _item_wrist_override_applied := false
var _knife_chest_bone := -1
var _knife_chest_override_applied := false
var _hand_candy: Node3D
var _view_candy: Node3D
var _hand_flare: Node3D
var _view_flare: Node3D
var _left_hand_mount: BoneAttachment3D
var _left_arm_bones: Array[int] = []
var _left_grip_fingers: Array[Dictionary] = []
var _hand_battery: Node3D
var _view_battery: Node3D
var _hand_bandage: Node3D
var _view_bandage: Node3D
var _hand_bandage_roll: Node3D
var _reload_flashlight: Node3D
var _hand_unlit_flare: Node3D
var _view_unlit_flare: Node3D
var _placed_flare: Node3D
var _item_audio: ItemAudio
var _action_kind: StringName = &""
var _action_item_id: StringName = &""
var _action_time := 0.0
var _action_effect_done := false
var _lens_meshes: Array[MeshInstance3D] = []
var _lens_on_material: StandardMaterial3D
var _lens_off_material: StandardMaterial3D
var _lens_glowing := false
var inventory: BlackwebInventoryGrid = InventoryGrid.new()
var selected_quick_index := 0
var _animation: AnimationPlayer
var _walk_clip := ""
var _idle_clip := ""
var _run_clip := ""
var stamina := 100.0
var _stamina_reported := 100.0
var _stamina_recovery_delay := 0.0
var _crouching := false
var _capsule_shape: CollisionShape3D
var _standing_capsule: CapsuleShape3D
var _crouching_capsule: CapsuleShape3D
var _standing_clearance: BoxShape3D

const STAMINA_DRAIN := 23.0
const STAMINA_RECOVERY := 17.0
const JUMP_COST := 9.0
const JUMP_SPEED := 5.0
const BATTERY_DRAIN_PER_SECOND := 0.22
const KNIFE_DAMAGE := 4.0
const KNIFE_HIT_TIME := 0.24
const KNIFE_ACTION_DURATION := 0.68
const KNIFE_REACH := 1.55
const CANDY_HEAL_TIME := 0.78
const CANDY_ACTION_DURATION := 1.16
const PALM_GRIP := Vector3(0.076, 0.025, -0.006)
const CANDY_WRAPPER_CENTRE := 0.039
const CANDY_EXPOSED_TIP := 0.0685
const BATTERY_INSERT_TIME := 1.05
const BATTERY_ACTION_DURATION := 1.65
const BANDAGE_HEAL_TIME := 2.25
const BANDAGE_ACTION_DURATION := 2.8
const FLARE_IGNITE_TIME := 0.5
const FLARE_ACTION_DURATION := 0.95
const REAL_FLASHLIGHT_PATH := "res://assets/third_party/poly_haven/small_plastic_torch/small_plastic_torch_1k.gltf"
const REAL_KNIFE_PATH := "res://assets/third_party/poly_haven/fish_knife/fish_knife_1k.gltf"

func _ready() -> void:
	add_to_group("player")
	battery_charge = clampf(starting_battery_charge, 0.0, 100.0)
	_battery_reported = battery_charge
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.25
	_capsule_shape = CollisionShape3D.new()
	_standing_capsule = CapsuleShape3D.new()
	_standing_capsule.radius = 0.27
	_standing_capsule.height = 1.75
	_crouching_capsule = CapsuleShape3D.new()
	_crouching_capsule.radius = 0.27
	_crouching_capsule.height = 1.1
	_standing_clearance = BoxShape3D.new()
	_standing_clearance.size = Vector3(0.50, 0.62, 0.50)
	_capsule_shape.shape = _standing_capsule
	_capsule_shape.position.y = 0.875
	add_child(_capsule_shape)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.48, 0)
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.position.x = 0.32
	arm.spring_length = 1.85
	arm.margin = 0.12
	arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.12
	arm.shape = probe
	pivot.add_child(arm)
	arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.06
	camera.far = 35.0
	arm.add_child(camera)
	camera.current = true
	lamp = SpotLight3D.new()
	lamp.position = Vector3(0.12, -0.08, -0.1)
	lamp.light_color = Color(0.89, 0.94, 1)
	lamp.light_energy = 1.45
	lamp.light_specular = 0.14
	lamp.spot_range = 12.5
	lamp.spot_angle = 27.0
	lamp.spot_angle_attenuation = 0.5
	lamp.shadow_enabled = true
	lamp.shadow_normal_bias = 2.0
	lamp.shadow_bias = 0.15
	lamp.visible = false
	camera.add_child(lamp)
	_flare_light = OmniLight3D.new()
	_flare_light.name = "HeldFlareLight"
	_flare_light.position = Vector3(0.0, 1.0, 0.0)
	_flare_light.light_color = Color(1.0, 0.31, 0.13)
	_flare_light.light_energy = 1.35
	_flare_light.omni_range = 5.0
	_flare_light.shadow_enabled = false
	_flare_light.visible = false
	add_child(_flare_light)
	visual = Node3D.new()
	add_child(visual)
	_item_audio = ItemAudio.new()
	_item_audio.name = "StarterItemAudio"
	add_child(_item_audio)
	_make_lens_materials()
	_view_flashlight = _make_flashlight_model()
	_view_flashlight.name = "VisibleCameraFlashlight"
	_view_flashlight.position = Vector3(0.39, -0.30, -0.62)
	_view_flashlight.rotation = Vector3(-0.12, -0.12, 0.25)
	_view_flashlight.scale = Vector3.ONE * 0.85
	_view_flashlight.hide()
	camera.add_child(_view_flashlight)
	_view_knife = _make_knife_model()
	_view_knife.name = "VisibleCameraKnife"
	_view_knife.position = Vector3(0.43, -0.39, -0.58)
	_view_knife.rotation = Vector3(-0.3, -0.5, 0.5)
	camera.add_child(_view_knife)
	_view_knife.hide()
	_view_candy = _make_candy_model()
	_view_candy.name = "VisibleCameraCandy"
	_view_candy.position = Vector3(0.41, -0.37, -0.54)
	_view_candy.rotation = Vector3(-0.15, -0.25, 0.17)
	camera.add_child(_view_candy)
	_view_candy.hide()
	_view_flare = _make_flare_model()
	_view_flare.name = "VisibleCameraFlare"
	_view_flare.position = Vector3(-0.40, -0.32, -0.56)
	_view_flare.rotation = Vector3(-0.2, 0.25, -0.12)
	camera.add_child(_view_flare)
	_view_flare.hide()
	_view_battery = _make_supply_model("BatteryCell")
	_view_battery.name = "VisibleCameraBattery"
	camera.add_child(_view_battery)
	_view_bandage = _make_supply_model("BandagePack")
	_view_bandage.name = "VisibleCameraBandage"
	camera.add_child(_view_bandage)
	_view_unlit_flare = _make_supply_model("FlareStick")
	_view_unlit_flare.name = "VisibleCameraUnlitFlare"
	camera.add_child(_view_unlit_flare)
	for supply in [_view_battery, _view_bandage, _view_unlit_flare]: supply.hide()

func attach_model(scene: PackedScene, model_scale := 1.0) -> void:
	var model := scene.instantiate()
	visual.add_child(model)
	model.scale *= model_scale
	_animation = model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	if _animation:
		for clip in _animation.get_animation_list():
			if "walk" in clip.to_lower(): _walk_clip = clip
			if "idle" in clip.to_lower(): _idle_clip = clip
			if "run" in clip.to_lower(): _run_clip = clip
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		_luke_skeleton = skeleton
		_locomotion_pose.bind(skeleton)
		_right_upper_bone = skeleton.find_bone("Bip01 R UpperArm")
		_right_forearm_bone = skeleton.find_bone("Bip01 R Forearm")
		_right_hand_bone = skeleton.find_bone("Bip01 R Hand")
		_knife_chest_bone = skeleton.find_bone("Bip01 Spine1")
		# This recovered idle rig has open fingers. Bend the existing phalanges
		# around the prop shaft instead of leaving the torch balanced on a palm.
		for grip_bone in [
			["Bip01 R Finger0", -0.55], ["Bip01 R Finger01", -0.50],
			["Bip01 R Finger1", 0.85], ["Bip01 R Finger11", 0.75], ["Bip01 R Finger12", 0.35],
			["Bip01 R Finger2", 0.95], ["Bip01 R Finger21", 0.80], ["Bip01 R Finger22", 0.40],
			["Bip01 R Finger3", 0.95], ["Bip01 R Finger31", 0.80], ["Bip01 R Finger32", 0.40],
			["Bip01 R Finger4", 0.80], ["Bip01 R Finger41", 0.70], ["Bip01 R Finger42", 0.35],
		]:
			var grip_index := skeleton.find_bone(grip_bone[0])
			if grip_index >= 0:
				_right_grip_fingers.append({"index": grip_index, "curl": grip_bone[1]})
		if skeleton.find_bone("Bip01 R Hand") >= 0:
			var hand := BoneAttachment3D.new()
			hand.name = "RightHandFlashlightMount"
			hand.bone_name = "Bip01 R Hand"
			skeleton.add_child(hand)
			_hand_mount = hand
			_hand_flashlight = _make_flashlight_model()
			_hand_flashlight.name = "HeldFlashlight"
			_hand_flashlight.position = Vector3(0.065, 0.012, -0.01)
			_hand_flashlight.scale = Vector3.ONE * 1.45
			hand.add_child(_hand_flashlight)
			_grip_fill = OmniLight3D.new()
			_grip_fill.name = "EquipmentBounce"
			_grip_fill.position = Vector3(0.06, 0.005, -0.025)
			_grip_fill.light_color = Color(0.82, 0.86, 0.78)
			_grip_fill.light_energy = 0.55
			_grip_fill.omni_range = 0.75
			_grip_fill.shadow_enabled = false
			_grip_fill.visible = false
			hand.add_child(_grip_fill)
			_hand_knife = _make_knife_model()
			_hand_knife.name = "HeldWornKnife"
			# The knife origin is its handle centre. The shaft crosses the
			# closed palm, and the wrist moves the hand and blade together.
			_hand_knife.position = Vector3(0.076, 0.025, -0.006)
			_hand_knife.rotation = Vector3(0.0, PI, 0.0)
			hand.add_child(_hand_knife)
			_hand_knife.hide()
			_hand_candy = _make_candy_model()
			_hand_candy.name = "HeldCandyBar"
			_hand_candy.position = Vector3.ZERO
			hand.add_child(_hand_candy)
			_hand_candy.hide()
			_hand_battery = _make_supply_model("BatteryCell")
			_hand_battery.name = "HeldBatteryCell"
			_hand_bandage = _make_supply_model("BandagePack")
			_hand_bandage.name = "HeldBandagePack"
			_hand_bandage_roll = _make_supply_model("BandageRoll")
			_hand_bandage_roll.name = "HeldGauzeRoll"
			_hand_unlit_flare = _make_supply_model("FlareStick")
			_hand_unlit_flare.name = "HeldUnlitFlare"
			for supply in [_hand_battery, _hand_bandage, _hand_bandage_roll, _hand_unlit_flare]:
				hand.add_child(supply)
				supply.hide()
		if skeleton.find_bone("Bip01 L Hand") >= 0:
			var left_hand := BoneAttachment3D.new()
			left_hand.name = "LeftHandFlareMount"
			left_hand.bone_name = "Bip01 L Hand"
			skeleton.add_child(left_hand)
			_left_hand_mount = left_hand
			for bone_name in ["Bip01 L UpperArm", "Bip01 L Forearm", "Bip01 L Hand"]:
				_left_arm_bones.append(skeleton.find_bone(bone_name))
			for finger in range(5):
				for segment in ["", "1", "2"]:
					var bone_index := skeleton.find_bone("Bip01 L Finger%d%s" % [finger, segment])
					if bone_index >= 0: _left_grip_fingers.append({"index": bone_index, "curl": 0.8 if finger > 0 else -0.5})
			_reload_flashlight = _make_flashlight_model()
			_reload_flashlight.name = "SupportedReloadFlashlight"
			left_hand.add_child(_reload_flashlight)
			_reload_flashlight.hide()
			_hand_flare = _make_flare_model()
			_hand_flare.name = "HeldFlare"
			_hand_flare.position = Vector3(-0.02, -0.06, -0.10)
			_hand_flare.rotation = Vector3(0.0, 0.0, -PI * 0.5)
			left_hand.add_child(_hand_flare)
			_hand_flare.hide()

func _make_lens_materials() -> void:
	_lens_on_material = StandardMaterial3D.new()
	_lens_on_material.albedo_color = Color(0.82, 0.91, 0.85)
	_lens_on_material.emission_enabled = true
	_lens_on_material.emission = Color(0.62, 0.76, 0.68)
	_lens_on_material.emission_energy_multiplier = 1.5
	_lens_off_material = StandardMaterial3D.new()
	_lens_off_material.albedo_color = Color(0.25, 0.29, 0.28)
	_lens_off_material.roughness = 0.28

func _make_flashlight_model() -> Node3D:
	if ResourceLoader.exists(REAL_FLASHLIGHT_PATH):
		var source = load(REAL_FLASHLIGHT_PATH)
		if source is PackedScene:
			var real_model := Node3D.new()
			var imported: Node3D = source.instantiate()
			imported.name = "PolyHavenSmallPlasticTorch"
			# Source is 0.23 m long and points toward +Z; the held beam points -Z.
			imported.rotation.y = PI
			real_model.add_child(imported)
			var real_lens_shape := CylinderMesh.new()
			real_lens_shape.top_radius = 0.018
			real_lens_shape.bottom_radius = 0.018
			real_lens_shape.height = 0.003
			var real_lens := MeshInstance3D.new()
			real_lens.name = "SwitchableLens"
			real_lens.mesh = real_lens_shape
			real_lens.material_override = _lens_off_material
			real_lens.position.z = -0.118
			real_lens.rotation.x = PI * 0.5
			real_model.add_child(real_lens)
			_lens_meshes.append(real_lens)
			return real_model
	var handle := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.15, 0.16)
	metal.metallic = 0.45
	metal.roughness = 0.55
	var tube := CylinderMesh.new()
	tube.top_radius = 0.036
	tube.bottom_radius = 0.036
	tube.height = 0.23
	var shaft := MeshInstance3D.new()
	shaft.name = "FlashlightBody"
	shaft.mesh = tube
	shaft.material_override = metal
	shaft.rotation.x = PI * 0.5
	handle.add_child(shaft)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.052
	rim.bottom_radius = 0.044
	rim.height = 0.055
	var head := MeshInstance3D.new()
	head.name = "FlashlightHead"
	head.mesh = rim
	head.material_override = metal
	head.position.z = -0.125
	head.rotation.x = PI * 0.5
	handle.add_child(head)
	var lens_shape := CylinderMesh.new()
	lens_shape.top_radius = 0.041
	lens_shape.bottom_radius = 0.041
	lens_shape.height = 0.005
	var lens := MeshInstance3D.new()
	lens.name = "FlashlightLens"
	lens.mesh = lens_shape
	lens.material_override = _lens_off_material
	lens.position.z = -0.154
	lens.rotation.x = PI * 0.5
	handle.add_child(lens)
	_lens_meshes.append(lens)
	return handle

func _make_knife_model() -> Node3D:
	if ResourceLoader.exists(REAL_KNIFE_PATH):
		var source = load(REAL_KNIFE_PATH)
		if source is PackedScene:
			var weathered_knife := Node3D.new()
			var imported: Node3D = source.instantiate()
			imported.name = "PolyHavenWeatheredFishKnife"
			# The source steel blade runs along +Y, with its wooden grip on -Y.
			# Rotate the steel point along -Z and centre the grip in the fist.
			imported.rotation.x = -PI * 0.5
			imported.position.y = -0.04
			imported.position.z = -0.065
			imported.scale = Vector3.ONE * 1.35
			# The recovered fish knife has a broad wooden grip and a fillet-thin
			# steel blade. Reshape its separate meshes into a worn dagger profile
			# while preserving the imported CC0 textures and mesh detail.
			var source_grip := imported.find_child("fish_knife_handle", true, false) as MeshInstance3D
			var source_blade := imported.find_child("fish_knife_blade", true, false) as MeshInstance3D
			if source_grip != null: source_grip.scale = Vector3(0.75, 0.65, 0.90)
			if source_blade != null: source_blade.scale = Vector3(1.65, 2.25, 1.40)
			weathered_knife.add_child(imported)
			if source_grip != null:
				var grip_centre := imported.transform * source_grip.transform * source_grip.mesh.get_aabb().get_center()
				imported.position -= grip_centre
			return weathered_knife
	var model := Node3D.new()
	var worn_steel := StandardMaterial3D.new()
	worn_steel.albedo_color = Color(0.35, 0.37, 0.35)
	worn_steel.metallic = 0.6
	worn_steel.roughness = 0.62
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.15, 0.11, 0.09)
	grip.roughness = 0.94
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.023
	handle_mesh.bottom_radius = 0.029
	handle_mesh.height = 0.115
	var handle := MeshInstance3D.new()
	handle.name = "WornKnifeGrip"
	handle.mesh = handle_mesh
	handle.material_override = grip
	handle.rotation.x = PI * 0.5
	handle.position.z = -0.035
	model.add_child(handle)
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.075, 0.019, 0.018)
	var guard := MeshInstance3D.new()
	guard.name = "WornKnifeGuard"
	guard.mesh = guard_mesh
	guard.material_override = worn_steel
	guard.position.z = -0.105
	model.add_child(guard)
	var blade_mesh := CylinderMesh.new()
	blade_mesh.top_radius = 0.027
	blade_mesh.bottom_radius = 0.002
	blade_mesh.height = 0.19
	blade_mesh.radial_segments = 4
	var blade := MeshInstance3D.new()
	blade.name = "WornKnifeBlade"
	blade.mesh = blade_mesh
	blade.material_override = worn_steel
	blade.rotation.x = PI * 0.5
	blade.position.z = -0.207
	model.add_child(blade)
	for part in model.get_children(): part.position.z += 0.035
	return model

func _make_candy_model() -> Node3D:
	var model := Node3D.new()
	# The wrapper stays near the fingers; the exposed end turns toward the mouth.
	var body := Node3D.new()
	body.name = "CandyBarBody"
	body.position.x = 0.115
	body.rotation.x = PI
	model.add_child(body)
	var candy_path := "res://assets/generated/candy_blender/candy_variants.glb"
	if ResourceLoader.exists(candy_path):
		var packed := load(candy_path) as PackedScene
		if packed != null:
			var imported := packed.instantiate()
			for variant_name in ["CandyReady", "CandyBitten"]:
				var variant := imported.find_child(variant_name, true, false) as Node3D
				if variant == null: continue
				variant.owner = null
				for child in variant.find_children("*", "Node", true, false): child.owner = null
				variant.get_parent().remove_child(variant)
				body.add_child(variant)
				variant.transform = Transform3D.IDENTITY
				variant.visible = variant_name == "CandyReady"
				for part in variant.find_children("*", "MeshInstance3D", true, false):
					for surface in range(part.mesh.get_surface_count()):
						var material := part.mesh.surface_get_material(surface) as StandardMaterial3D
						if material != null and material.resource_name == "Candy_WornWrapper":
							var wrapper := material.duplicate() as StandardMaterial3D
							wrapper.albedo_color = Color(0.90, 0.85, 0.80)
							wrapper.albedo_texture = CandyWrapperTexture
							wrapper.roughness = 0.93
							part.set_surface_override_material(surface, wrapper)
			imported.free()
			if body.has_node("CandyReady") and body.has_node("CandyBitten"):
				return model
	var cocoa := StandardMaterial3D.new()
	cocoa.albedo_color = Color(0.145, 0.074, 0.043)
	cocoa.roughness = 0.78
	var raised_cocoa := StandardMaterial3D.new()
	raised_cocoa.albedo_color = Color(0.18, 0.095, 0.055)
	raised_cocoa.roughness = 0.82
	var foil := StandardMaterial3D.new()
	foil.albedo_color = Color(0.35, 0.35, 0.34)
	foil.metallic = 0.62
	foil.roughness = 0.55
	var worn_paper := StandardMaterial3D.new()
	worn_paper.albedo_color = Color(0.9, 0.85, 0.81)
	worn_paper.albedo_texture = CandyWrapperTexture
	worn_paper.roughness = 0.9
	var faded_print := StandardMaterial3D.new()
	faded_print.albedo_color = Color(0.48, 0.37, 0.25)
	faded_print.roughness = 0.96
	_add_candy_piece(body, "ChocolateBase", Vector3(0.128, 0.015, 0.054), Vector3.ZERO, cocoa)
	for x in [0.017, 0.044]:
		for z in [-0.014, 0.014]:
			_add_candy_piece(body, "MouldedChocolateSquare", Vector3(0.024, 0.004, 0.024), Vector3(x, 0.0095, z), raised_cocoa)
	_add_candy_piece(body, "CrinkledFoilCuff", Vector3(0.025, 0.020, 0.060), Vector3(0.0, 0.0, 0.0), foil)
	_add_candy_piece(body, "WornCandyWrapper", Vector3(0.073, 0.022, 0.062), Vector3(-0.039, 0.0, 0.0), worn_paper)
	_add_candy_piece(body, "FadedUnbrandedStripe", Vector3(0.050, 0.0008, 0.010), Vector3(-0.043, 0.0115, 0.0), faded_print)
	for z in [-0.024, 0.018]:
		var crease := _add_candy_piece(body, "FoilCrease", Vector3(0.020, 0.0008, 0.003), Vector3(0.0, 0.011, z), faded_print)
		crease.rotation.y = 0.32
	return model

func _candy_raise_amount() -> float:
	if _action_kind != &"candy_bar": return 0.0
	if _action_time < 0.32: return smoothstep(0.0, 0.32, _action_time)
	if _action_time <= 0.82: return 1.0
	return 1.0 - smoothstep(0.82, CANDY_ACTION_DURATION, _action_time)

func _candy_mouth_world() -> Vector3:
	var head_index := _luke_skeleton.find_bone("Bip01 Head")
	var head_world := _luke_skeleton.to_global(_luke_skeleton.get_bone_global_pose(head_index).origin)
	# Calibrated against the visible lip line on the recovered rig. Use Luke's
	# anatomical facing, not the independent camera pitch.
	return head_world - visual.global_basis.z.normalized() * 0.09 + visual.global_basis.x.normalized() * 0.025 + Vector3.UP * 0.01

func _set_candy_bitten(model: Node3D, bitten: bool) -> void:
	var ready := model.get_node_or_null("CandyBarBody/CandyReady") as Node3D
	var bitten_model := model.get_node_or_null("CandyBarBody/CandyBitten") as Node3D
	if ready != null: ready.visible = not bitten
	if bitten_model != null: bitten_model.visible = bitten

func _add_candy_piece(parent: Node3D, piece_name: String, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.material_override = material
	piece.position = offset
	parent.add_child(piece)
	return piece

func _make_flare_model() -> Node3D:
	var model := Node3D.new()
	var imported := SupplyModels.make_variant("FlareStick")
	var casing := StandardMaterial3D.new()
	casing.albedo_color = Color(0.52, 0.12, 0.08)
	casing.roughness = 0.85
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.42, 0.18)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.30, 0.08)
	flame.emission_energy_multiplier = 2.0
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.014
	shaft_mesh.bottom_radius = 0.017
	shaft_mesh.height = 0.20
	var shaft := MeshInstance3D.new()
	shaft.name = "FlareTube"
	shaft.mesh = shaft_mesh
	shaft.material_override = casing
	shaft.rotation.x = PI * 0.5
	shaft.position.z = -0.07
	if imported != null:
		imported.rotation.x = -PI * 0.5
		imported.position.z = -0.07
		model.add_child(imported)
		shaft.free()
	else:
		model.add_child(shaft)
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.025
	tip_mesh.height = 0.05
	tip_mesh.radial_segments = 8
	tip_mesh.rings = 4
	var tip := MeshInstance3D.new()
	tip.name = "FlareEmber"
	tip.mesh = tip_mesh
	tip.material_override = flame
	tip.position.z = -0.18
	model.add_child(tip)
	return model

func _make_supply_model(variant: String) -> Node3D:
	var imported := SupplyModels.make_variant(variant)
	if imported != null: return imported
	# Missing optional art must not break inventory or use actions.
	var fallback := Node3D.new()
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.10, 0.025, 0.065) if variant.begins_with("Bandage") else Vector3(0.015, 0.05, 0.015)
	mesh.mesh = shape
	fallback.add_child(mesh)
	return fallback

func _update_flashlight_lenses() -> void:
	var glowing := lamp.visible
	if glowing == _lens_glowing: return
	_lens_glowing = glowing
	for lens in _lens_meshes:
		if is_instance_valid(lens): lens.material_override = _lens_on_material if glowing else _lens_off_material

func _unhandled_input(event: InputEvent) -> void:
	if not active or _recovering: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -1.05, 0.65)
	if event.is_action_pressed("interact") and is_instance_valid(_focused):
		_focused.interact()
	if event.is_action_pressed("flashlight"):
		var torch_slot := inventory.equipped.find(&"flashlight")
		if torch_slot >= 0 and torch_slot != selected_quick_index:
			select_quick_slot(torch_slot)
		else:
			use_item(&"flashlight")
	for quick_index in range(3):
		if event.is_action_pressed("hotbar_%d" % (quick_index + 1)):
			select_quick_slot(quick_index)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		use_selected_item()

func _physics_process(delta: float) -> void:
	if not active or _recovering:
		velocity = Vector3.ZERO
		if is_instance_valid(lamp): lamp.visible = false
		_update_flashlight_lenses()
		if _animation and not _idle_clip.is_empty() and _animation.current_animation != _idle_clip:
			_animation.play(_idle_clip, 0.18)
		_set_focus_prompt("")
		return
	_hurt_time = maxf(0.0, _hurt_time - delta)
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch and not _crouching:
		_set_crouch(true)
	elif not wants_crouch and _crouching and _can_stand():
		_set_crouch(false)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y)
	var busy_with_supply := _action_kind in [&"battery", &"bandage", &"flare"]
	var sprinting := Input.is_action_pressed("sprint") and input.length_squared() > 0.04 and is_on_floor() and not _crouching and stamina > 0.0 and not busy_with_supply
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		_stamina_recovery_delay = 0.55
	else:
		_stamina_recovery_delay = maxf(0.0, _stamina_recovery_delay - delta)
		if _stamina_recovery_delay <= 0.0: stamina = minf(100.0, stamina + STAMINA_RECOVERY * delta)
	if absf(stamina - _stamina_reported) >= 0.5 or (stamina == 100.0 and _stamina_reported != 100.0):
		_stamina_reported = stamina
		stamina_changed.emit(stamina)
	var speed := 1.05 if _crouching else (3.2 if sprinting else 2.0)
	if busy_with_supply: speed *= 0.55
	if _hurt_time > 0.0: speed *= 0.55
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 10.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 10.0)
	if not is_on_floor(): velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("jump") and not _crouching and stamina >= JUMP_COST and not busy_with_supply:
		velocity.y = JUMP_SPEED
		stamina -= JUMP_COST
		_stamina_reported = stamina
		stamina_changed.emit(stamina)
		_stamina_recovery_delay = 0.55
	else: velocity.y = -0.5
	move_and_slide()
	pivot.rotation = Vector3(_pitch, _yaw, 0)
	pivot.position.y = move_toward(pivot.position.y, 1.03 if _crouching else 1.48, delta * 2.4)
	if direction.length_squared() > 0.02:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-12.0 * delta))
	if _animation:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var clip := _walk_clip if horizontal_speed > 0.15 else _idle_clip
		if horizontal_speed > 2.3 and not _run_clip.is_empty(): clip = _run_clip
		_animation.speed_scale = clampf(horizontal_speed / (2.8 if clip == _run_clip else 1.7), 0.6, 1.4) if horizontal_speed > 0.15 else 1.0
		if not clip.is_empty() and _animation.current_animation != clip: _animation.play(clip, 0.18)
	_locomotion_pose.apply(delta, _crouching, not is_on_floor(), velocity.y, -camera.global_basis.z)
	_tick_item_action(delta)
	if _light_on or selected_quick_item() == &"knife" or _action_kind != &"": visual.rotation.y = lerp_angle(visual.rotation.y, _yaw, minf(1.0, delta * 8.0))
	_update_left_supply_arm()
	_update_right_arm_pose(delta)
	# Keep the camera from showing the inside of Luke when a wall shortens the arm.
	var show_visual := camera.global_position.distance_to(global_position + Vector3.UP * 1.3) > 0.58
	if visual.visible != show_visual: visual.visible = show_visual
	_update_held_item_visuals(show_visual, delta)
	_tick_equipment(delta)
	_update_focus()
	if global_position.y < -50.0: take_damage(1000.0)

func _update_focus() -> void:
	_focused = null
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * 4.8
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 8)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var candidate = hit.collider
		if candidate is BlackwebInteraction and global_position.distance_to(candidate.global_position) < 2.1:
			# A camera peeking around a corner cannot reach through a wall.
			var reach := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.35, candidate.global_position, 1)
			reach.exclude = [get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(reach).is_empty(): _focused = candidate
	_set_focus_prompt(_focused.prompt() if is_instance_valid(_focused) else "")

func _set_focus_prompt(text: String) -> void:
	if text == _focus_prompt: return
	_focus_prompt = text
	focus_changed.emit(text)

func flashlight_available() -> bool:
	return true # Luke begins with a weak battery torch; the house pickup is a backup.

func add_battery(amount: float) -> float:
	if amount <= 0.0: return battery_charge
	battery_charge = clampf(battery_charge + amount, 0.0, 100.0)
	_battery_reported = battery_charge
	battery_changed.emit(battery_charge)
	return battery_charge

func add_item(id: StringName, count: int = 1) -> int:
	var before := item_count(id)
	var after := inventory.add(id, count)
	if after != before: inventory_changed.emit()
	return after

func add_battery_pack(charge_points: float) -> bool:
	var points := clampi(roundi(charge_points), 1, 100)
	var id := StringName("battery_%d" % points)
	var before := item_count(id)
	return add_item(id, 1) > before

func item_count(id: StringName) -> int:
	if id == &"battery":
		var packs := 0
		for cell in inventory.slots:
			if str(cell.get("id", "")).begins_with("battery_"):
				packs += int(cell.get("count", 0))
		return packs
	return inventory.count(id)

func inventory_counts() -> Dictionary:
	var counts := {&"flashlight": item_count(&"flashlight"), &"knife": item_count(&"knife"),
		&"candy_bar": item_count(&"candy_bar"), &"bandage": item_count(&"bandage"),
		&"flare": item_count(&"flare"), &"battery": item_count(&"battery")}
	return counts

func inventory_slots() -> Array[Dictionary]:
	return inventory.snapshot()

func equipped_items() -> Array[StringName]:
	return inventory.equipped.duplicate()

func equip_inventory_cell(cell_index: int, quick_index: int) -> bool:
	if _action_kind != &"": return false
	var equipped := inventory.equip_cell(cell_index, quick_index)
	if equipped:
		if quick_index == selected_quick_index and selected_quick_item() != &"flashlight" and _light_on:
			_light_on = false
		inventory_changed.emit()
		flashlight_changed.emit(_light_on)
		quick_slot_changed.emit(selected_quick_index)
	return equipped

func is_item_equipped(id: StringName) -> bool:
	return inventory.is_equipped(id) and item_count(id) > 0

func use_quick_slot(quick_index: int) -> bool:
	return use_item(inventory.quick_item(quick_index))

func selected_quick_item() -> StringName:
	return inventory.quick_item(selected_quick_index)

func select_quick_slot(quick_index: int) -> bool:
	if quick_index < 0 or quick_index >= inventory.equipped.size() or _action_kind != &"": return false
	var id := inventory.quick_item(quick_index)
	if id == &"" or item_count(id) <= 0: return false
	selected_quick_index = quick_index
	var new_light_on := id == &"flashlight" and battery_charge > 0.0
	if _light_on != new_light_on:
		_light_on = new_light_on
		flashlight_changed.emit(_light_on)
	quick_slot_changed.emit(selected_quick_index)
	return true

func use_selected_item() -> bool:
	return use_quick_slot(selected_quick_index)

func use_item(id: StringName) -> bool:
	if not active or _recovering or _action_kind != &"" or not is_item_equipped(id): return false
	if str(id).begins_with("battery_"):
		if battery_charge >= 99.9: return false
		_start_item_action(&"battery", id)
		_item_audio.play_cue(&"unwrap")
		return true
	match id:
		&"flashlight":
			_light_on = not _light_on
			_item_audio.play_cue(&"switch")
			flashlight_changed.emit(_light_on)
			return true
		&"knife":
			if _knife_cooldown > 0.0: return false
			_knife_cooldown = 0.75
			_action_kind = &"knife"
			_action_time = 0.0
			_action_effect_done = false
			return true
		&"candy_bar":
			if health >= 100.0: return false
			_action_kind = &"candy_bar"
			_action_time = 0.0
			_action_effect_done = false
			_item_audio.play_cue(&"unwrap")
			return true
		&"bandage":
			if health >= 100.0: return false
			_start_item_action(&"bandage", id)
			_item_audio.play_cue(&"unwrap")
			return true
		&"flare":
			if _flare_remaining > 0.0: return false
			_start_item_action(&"flare", id)
			return true
	return false

func _start_item_action(kind: StringName, item_id: StringName) -> void:
	if kind in [&"battery", &"bandage"] and _flare_remaining > 0.0:
		_place_burning_flare()
	_action_kind = kind
	_action_item_id = item_id
	_action_time = 0.0
	_action_effect_done = false

func _place_burning_flare() -> void:
	if is_instance_valid(_placed_flare): return
	var forward_drop := global_position - camera.global_basis.z.slide(Vector3.UP).normalized() * 0.3
	var held_position := _hand_flare.global_position if is_instance_valid(_hand_flare) else global_position + Vector3.UP
	var ray_height := maxf(global_position.y + 0.25, held_position.y) + 0.1
	var surface: Dictionary = {}
	# A supply action can begin during a jump. Land on world collision rather
	# than using Luke's airborne feet as an imaginary floor. Prefer the forward
	# drop, with the surface directly below Luke as a nearby fallback.
	for candidate in [forward_drop, global_position]:
		var from := Vector3(candidate.x, ray_height, candidate.z)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, 1, [get_rid()])
		surface = get_world_3d().direct_space_state.intersect_ray(query)
		if not surface.is_empty() and surface.normal.y > 0.5: break
		surface = {}
	if surface.is_empty(): return
	var end: Vector3 = surface.position + Vector3.UP * 0.04
	_placed_flare = _make_flare_model()
	_placed_flare.name = "PlacedBurningFlare"
	add_child(_placed_flare)
	_placed_flare.top_level = true
	_placed_flare.global_position = held_position
	_placed_flare.global_rotation = Vector3(0.0, _yaw + 0.4, 0.0)
	var fall := create_tween()
	fall.tween_property(_placed_flare, "global_position", end, 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _clear_placed_flare() -> void:
	if is_instance_valid(_placed_flare): _placed_flare.queue_free()
	_placed_flare = null

func _cancel_item_action() -> void:
	_action_kind = &""
	_action_item_id = &""
	_action_time = 0.0
	_action_effect_done = false

func _item_action_duration() -> float:
	match _action_kind:
		&"knife": return KNIFE_ACTION_DURATION
		&"candy_bar": return CANDY_ACTION_DURATION
		&"battery": return BATTERY_ACTION_DURATION
		&"bandage": return BANDAGE_ACTION_DURATION
		&"flare": return FLARE_ACTION_DURATION
	return 0.0

func reset_starting_inventory() -> void:
	_cancel_item_action()
	if is_instance_valid(_item_audio): _item_audio.silence()
	inventory.reset()
	selected_quick_index = 0
	battery_charge = clampf(starting_battery_charge, 0.0, 100.0)
	_battery_reported = battery_charge
	_light_on = true
	_flicker_clock = 0.0
	_flicker_off_remaining = 0.0
	_flare_remaining = 0.0
	_clear_placed_flare()
	if is_instance_valid(_flare_light): _flare_light.visible = false
	inventory_changed.emit()
	quick_slot_changed.emit(selected_quick_index)
	battery_changed.emit(battery_charge)
	flashlight_changed.emit(_light_on)

func _tick_item_action(delta: float) -> void:
	if _action_kind == &"": return
	var previous_time := _action_time
	_action_time += delta
	if _action_kind == &"knife" and previous_time < 0.14 and _action_time >= 0.14:
		_item_audio.play_cue(&"knife_swing")
	if not _action_effect_done and _action_kind == &"knife" and _action_time >= KNIFE_HIT_TIME:
		_action_effect_done = true
		if _knife_strike(): _item_audio.play_cue(&"knife_hit")
	elif not _action_effect_done and _action_kind == &"candy_bar" and _action_time >= CANDY_HEAL_TIME:
		_action_effect_done = true
		if item_count(&"candy_bar") > 0:
			health = minf(100.0, health + 30.0)
			inventory.remove(&"candy_bar")
			health_changed.emit(health)
			inventory_changed.emit()
			_item_audio.play_cue(&"eat")
	elif not _action_effect_done and _action_kind == &"battery" and _action_time >= BATTERY_INSERT_TIME:
		_action_effect_done = true
		if inventory.remove(_action_item_id):
			add_battery(float(str(_action_item_id).trim_prefix("battery_")))
			_item_audio.play_cue(&"switch")
			inventory_changed.emit()
	elif not _action_effect_done and _action_kind == &"bandage" and _action_time >= BANDAGE_HEAL_TIME:
		_action_effect_done = true
		if inventory.remove(_action_item_id):
			health = minf(100.0, health + 55.0)
			health_changed.emit(health)
			inventory_changed.emit()
			_item_audio.play_cue(&"unwrap")
	elif not _action_effect_done and _action_kind == &"flare" and _action_time >= FLARE_IGNITE_TIME:
		_action_effect_done = true
		if inventory.remove(_action_item_id):
			_flare_remaining = 10.0
			_flare_light.visible = true
			_item_audio.play_cue(&"switch")
			inventory_changed.emit()
	var duration := _item_action_duration()
	if _action_time >= duration:
		_cancel_item_action()

func _update_held_item_visuals(show_visual: bool, delta: float) -> void:
	var held_item := selected_quick_item()
	var holding_torch := _action_kind == &"" and held_item == &"flashlight" and is_item_equipped(&"flashlight")
	var holding_knife := held_item == &"knife" and is_item_equipped(&"knife")
	var holding_candy := held_item == &"candy_bar" and is_item_equipped(&"candy_bar")
	var striking := _action_kind == &"knife"
	var eating := _action_kind == &"candy_bar"
	var fallback := not show_visual or not is_instance_valid(_hand_mount)
	var lift := minf(1.0, delta * 10.0)
	var aim := _light_on and battery_charge > 0.0
	if is_instance_valid(_hand_flashlight):
		_hand_flashlight.visible = holding_torch
		# Keep the barrel fixed inside the palm. The wrist follows the beam;
		# rotating only the model slid the torch through stationary fingers.
		_hand_flashlight.position = PALM_GRIP
		_hand_flashlight.rotation = Vector3(0.0, PI, 0.0)
	if is_instance_valid(_view_flashlight):
		_view_flashlight.visible = fallback and holding_torch
		_view_flashlight.position = _view_flashlight.position.lerp(Vector3(0.37, -0.23, -0.65) if aim else Vector3(0.39, -0.38, -0.54), lift)
		_view_flashlight.rotation = _view_flashlight.rotation.lerp(Vector3(0.0, 0.0, 0.20) if aim else Vector3(-0.31, -0.12, 0.40), lift)
	var knife_pose := _knife_pose_sample(_action_time if striking else 0.0)
	if is_instance_valid(_hand_knife):
		_hand_knife.visible = holding_knife or striking
		_hand_knife.position = Vector3(0.076, 0.025, -0.006)
		_hand_knife.rotation = Vector3(0.0, PI, 0.0)
	if is_instance_valid(_view_knife):
		_view_knife.visible = fallback and (holding_knife or striking)
		var knife_offset: Vector3 = knife_pose.hand
		var knife_direction: Vector3 = knife_pose.blade
		_view_knife.position = Vector3(knife_offset.x + 0.13, knife_offset.y - 0.35, -knife_offset.z - 0.42)
		_view_knife.quaternion = Quaternion(Vector3.FORWARD, Vector3(knife_direction.x, knife_direction.y, -knife_direction.z).normalized())
	var raise := _candy_raise_amount()
	if is_instance_valid(_hand_candy):
		_hand_candy.visible = holding_candy or eating
		_set_candy_bitten(_hand_candy, eating and _action_effect_done)
		_hand_candy.position = PALM_GRIP
		_hand_candy.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		var candy_body := _hand_candy.get_node_or_null("CandyBarBody") as Node3D
		if candy_body: candy_body.position.x = CANDY_WRAPPER_CENTRE
	if is_instance_valid(_view_candy):
		_view_candy.visible = fallback and (holding_candy or eating)
		_set_candy_bitten(_view_candy, eating and _action_effect_done)
		_view_candy.position = Vector3(0.41 - 0.12 * raise, -0.37 + 0.26 * raise, -0.54 - 0.16 * raise)
		_view_candy.rotation = Vector3(-0.15 - 0.4 * raise, -0.25, 0.17 + 0.14 * raise)
	if is_instance_valid(_hand_flare): _hand_flare.visible = _flare_remaining > 0.0 and not is_instance_valid(_placed_flare)
	if is_instance_valid(_view_flare): _view_flare.visible = _flare_remaining > 0.0 and not is_instance_valid(_placed_flare) and (not show_visual or not is_instance_valid(_hand_flare))
	_update_supply_visuals(show_visual)
	if is_instance_valid(_grip_fill):
		_grip_fill.visible = show_visual and (holding_torch or holding_knife or holding_candy or striking or eating or _holding_supply())
		_grip_fill.light_energy = 0.55 if aim and holding_torch else 0.30
	var visible_torch := _hand_flashlight if show_visual and is_instance_valid(_hand_flashlight) else _view_flashlight
	if holding_torch and is_instance_valid(visible_torch):
		lamp.global_transform = Transform3D(visible_torch.global_basis.orthonormalized(), visible_torch.to_global(Vector3(0.0, 0.0, -0.13)))

func _update_right_arm_pose(delta: float) -> void:
	if not is_instance_valid(_luke_skeleton) or _right_upper_bone < 0 or _right_forearm_bone < 0 or _right_hand_bone < 0: return
	if _knife_chest_override_applied:
		_luke_skeleton.set_bone_global_pose_override(_knife_chest_bone, Transform3D.IDENTITY, 0.0, false)
		_knife_chest_override_applied = false
	if _knife_wrist_override_applied or _item_wrist_override_applied:
		_luke_skeleton.set_bone_global_pose_override(_right_hand_bone, Transform3D.IDENTITY, 0.0, false)
		_knife_wrist_override_applied = false
		_item_wrist_override_applied = false
	var wanted := 1.0 if selected_quick_item() in [&"flashlight", &"knife", &"candy_bar"] or _action_kind != &"" or _holding_supply() else 0.0
	_arm_pose_weight = move_toward(_arm_pose_weight, wanted, delta * 4.5)
	_luke_skeleton.set_bone_global_pose_override(_right_upper_bone, Transform3D.IDENTITY, 0.0, false)
	_luke_skeleton.set_bone_global_pose_override(_right_forearm_bone, Transform3D.IDENTITY, 0.0, false)
	if _arm_pose_weight <= 0.001:
		_update_right_hand_grip()
		return
	if _action_kind == &"knife" and _knife_chest_bone >= 0:
		var chest := _luke_skeleton.get_bone_global_pose(_knife_chest_bone)
		var up_local := (_luke_skeleton.global_basis.inverse() * Vector3.UP).normalized()
		var twist := Basis(up_local, float(_knife_pose_sample(_action_time).torso))
		_luke_skeleton.set_bone_global_pose_override(_knife_chest_bone, Transform3D(twist * chest.basis, chest.origin), 1.0, true)
		_knife_chest_override_applied = true
	var upper_base := _luke_skeleton.get_bone_global_pose(_right_upper_bone)
	var forearm_base := _luke_skeleton.get_bone_global_pose(_right_forearm_bone)
	var hand_base := _luke_skeleton.get_bone_global_pose(_right_hand_bone)
	var shoulder := upper_base.origin
	var upper_length := forearm_base.origin.distance_to(shoulder)
	var lower_length := hand_base.origin.distance_to(forearm_base.origin)
	# The recovered skeleton can report an unposed chain for the first render
	# tick. Do not construct a Quaternion from those zero-length directions.
	if upper_length < 0.02 or lower_length < 0.02: return
	var shoulder_world := _luke_skeleton.to_global(shoulder)
	var facing := -camera.global_basis.z.normalized()
	var right := camera.global_basis.x.normalized()
	var contact_item := &"candy_bar" if _action_kind == &"candy_bar" or (_action_kind == &"" and selected_quick_item() == &"candy_bar") else (&"flashlight" if _action_kind == &"" and selected_quick_item() == &"flashlight" else &"")
	var contact_basis := _item_grip_world_basis(contact_item)
	# Solve the hand target in camera/world space. The source mesh's +Z is
	# forward; the old fixed -Z target pulled the arm behind Luke's shoulder.
	var target_world := shoulder_world + facing * 0.16 + right * 0.30 - Vector3.UP * 0.04
	if _action_kind == &"knife":
		var slash_offset: Vector3 = _knife_pose_sample(_action_time).hand
		target_world = shoulder_world + right * slash_offset.x + Vector3.UP * slash_offset.y + facing * slash_offset.z
	elif _action_kind == &"candy_bar":
		var lift := _candy_raise_amount()
		var local_tip := PALM_GRIP + Basis(Vector3.UP, -PI * 0.5) * Vector3(CANDY_WRAPPER_CENTRE + CANDY_EXPOSED_TIP, 0.0, 0.0)
		var bite_wrist := _candy_mouth_world() - contact_basis * local_tip
		target_world = (shoulder_world + facing * 0.19 + right * 0.22 - Vector3.UP * 0.18).lerp(bite_wrist, lift)
	elif _action_kind == &"battery":
		var tail := _reload_torch_center_world() - _reload_torch_direction() * 0.12
		var approach := smoothstep(0.42, BATTERY_INSERT_TIME, _action_time)
		var insert_hand := tail - _reload_torch_direction() * lerpf(0.13, 0.035, approach)
		target_world = target_world.lerp(insert_hand, _supply_action_lift())
	elif _action_kind == &"bandage":
		var wrap := clampf((_action_time - 0.5) / 1.65, 0.0, 1.0) * TAU * 2.0
		var contact := _bandage_contact_world() + facing * (0.025 * cos(wrap)) + Vector3.UP * (0.025 * sin(wrap))
		target_world = target_world.lerp(contact + right * 0.060 + Vector3.UP * 0.055, _supply_action_lift())
	elif _action_kind == &"flare":
		target_world = target_world.lerp(_left_supply_target() + facing * 0.035 + right * 0.055, _supply_action_lift())
	var target := _luke_skeleton.to_local(target_world)
	var to_target := target - shoulder
	if to_target.length_squared() < 0.000001: return
	var reach := clampf(to_target.length(), 0.08, upper_length + lower_length - 0.015)
	var direction := to_target.normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + reach * reach) / (2.0 * reach)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var guide := _luke_skeleton.global_basis.inverse() * (Vector3.DOWN * 0.9 + right * 0.35 - facing * 0.15)
	var bend_vector := guide - direction * guide.dot(direction)
	if bend_vector.length_squared() < 0.000001: return
	var bend := bend_vector.normalized()
	var elbow := shoulder + direction * along + bend * height
	var adjusted_hand := shoulder + direction * reach
	var upper_current := (forearm_base.origin - shoulder).normalized()
	var lower_current := (hand_base.origin - forearm_base.origin).normalized()
	if (elbow - shoulder).length_squared() < 0.000001 or (adjusted_hand - elbow).length_squared() < 0.000001: return
	var upper_rotation := Quaternion(upper_current, (elbow - shoulder).normalized())
	var lower_rotation := Quaternion(lower_current, (adjusted_hand - elbow).normalized())
	_luke_skeleton.set_bone_global_pose_override(_right_upper_bone, Transform3D(Basis(upper_rotation) * upper_base.basis, shoulder), _arm_pose_weight, true)
	_luke_skeleton.set_bone_global_pose_override(_right_forearm_bone, Transform3D(Basis(lower_rotation) * forearm_base.basis, elbow), _arm_pose_weight, true)
	if selected_quick_item() == &"knife" or _action_kind == &"knife":
		# Turn the wrist itself; rotating only the prop would slide its handle
		# through otherwise stationary fingers during the diagonal sweep.
		var blade: Vector3 = _knife_pose_sample(_action_time if _action_kind == &"knife" else 0.0).blade
		var desired_world := (right * blade.x + Vector3.UP * blade.y + facing * blade.z).normalized()
		var desired_local := (_luke_skeleton.global_basis.inverse() * desired_world).normalized()
		var hand_pose := _luke_skeleton.get_bone_global_pose(_right_hand_bone)
		var current_axis := hand_pose.basis.z.normalized()
		var wrist_rotation := Quaternion(desired_local, -0.55) * Quaternion(current_axis, desired_local)
		_luke_skeleton.set_bone_global_pose_override(_right_hand_bone, Transform3D(Basis(wrist_rotation) * hand_pose.basis, adjusted_hand), _arm_pose_weight, true)
		_knife_wrist_override_applied = true
	elif contact_item != &"":
		var contact_local := (_luke_skeleton.global_basis.inverse() * contact_basis).orthonormalized()
		_luke_skeleton.set_bone_global_pose_override(_right_hand_bone, Transform3D(contact_local, adjusted_hand), _arm_pose_weight, true)
		_item_wrist_override_applied = true
	_update_right_hand_grip()

func _item_grip_world_basis(item: StringName) -> Basis:
	var facing := -camera.global_basis.z.normalized()
	var right := camera.global_basis.x.normalized()
	var shaft := (camera.global_basis * Basis(Vector3.UP, -0.30) * Vector3.FORWARD).normalized()
	if item == &"candy_bar":
		var ready := (Vector3.UP * 0.70 + facing * 0.60 + right * 0.20).normalized()
		var biting := (-right * 0.96 - facing * 0.10 + Vector3.UP * 0.24).normalized()
		shaft = ready.slerp(biting, _candy_raise_amount()).normalized()
	var fingers := (Vector3.UP - shaft * Vector3.UP.dot(shaft)).normalized()
	return Basis(fingers, shaft.cross(fingers).normalized(), shaft)

func _holding_supply() -> bool:
	var item := selected_quick_item()
	return _action_kind in [&"battery", &"bandage", &"flare"] or (item_count(item) > 0 and (str(item).begins_with("battery_") or item in [&"bandage", &"flare"]))

func _supply_action_lift() -> float:
	var duration := _item_action_duration()
	return smoothstep(0.0, 0.4, _action_time) * (1.0 - smoothstep(duration - 0.3, duration, _action_time))

func _left_supply_target() -> Vector3:
	var shoulder := global_position + Vector3.UP * (1.25 if not _crouching else 0.83)
	if _left_arm_bones.size() == 3 and _left_arm_bones[0] >= 0:
		shoulder = _luke_skeleton.to_global(_luke_skeleton.get_bone_global_pose(_left_arm_bones[0]).origin)
	var facing := -camera.global_basis.z.normalized()
	var right := camera.global_basis.x.normalized()
	# Work beside the right side of the torso so the shoulder camera can see
	# both hands. A centre-chest target hid the complete action behind Luke.
	return shoulder + facing * 0.20 + right * 0.48 - Vector3.UP * 0.18

func _reload_torch_direction() -> Vector3:
	return (Vector3.UP * 0.84 - camera.global_basis.z * 0.54).normalized()

func _reload_torch_center_world() -> Vector3:
	var hand_position := _left_supply_target()
	if is_instance_valid(_left_hand_mount): hand_position = _left_hand_mount.global_position
	return hand_position - camera.global_basis.z * 0.025

func _bandage_contact_world() -> Vector3:
	if _left_arm_bones.size() != 3: return _left_supply_target()
	var elbow := _luke_skeleton.to_global(_luke_skeleton.get_bone_global_pose(_left_arm_bones[1]).origin)
	var wrist := _luke_skeleton.to_global(_luke_skeleton.get_bone_global_pose(_left_arm_bones[2]).origin)
	return elbow.lerp(wrist, 0.78) + Vector3.UP * 0.025

func _update_left_supply_arm() -> void:
	if not is_instance_valid(_luke_skeleton) or _left_arm_bones.size() != 3 or _left_arm_bones.has(-1): return
	for bone in _left_arm_bones:
		_luke_skeleton.set_bone_global_pose_override(bone, Transform3D.IDENTITY, 0.0, false)
	for finger in _left_grip_fingers:
		_luke_skeleton.set_bone_global_pose_override(finger.index, Transform3D.IDENTITY, 0.0, false)
	var busy := _action_kind in [&"battery", &"bandage", &"flare"]
	var holding_lit_flare := _flare_remaining > 0.0 and not is_instance_valid(_placed_flare)
	if not busy and not holding_lit_flare: return
	var weight := _supply_action_lift() if busy else 1.0
	if holding_lit_flare: weight = 1.0
	var upper := _luke_skeleton.get_bone_global_pose(_left_arm_bones[0])
	var lower := _luke_skeleton.get_bone_global_pose(_left_arm_bones[1])
	var hand := _luke_skeleton.get_bone_global_pose(_left_arm_bones[2])
	var a := lower.origin.distance_to(upper.origin)
	var b := hand.origin.distance_to(lower.origin)
	if a < 0.02 or b < 0.02: return
	var target_world := _left_supply_target()
	if holding_lit_flare and not busy:
		target_world = _luke_skeleton.to_global(upper.origin) - camera.global_basis.x * 0.17 - camera.global_basis.z * 0.25 - Vector3.UP * 0.06
	var to_target := _luke_skeleton.to_local(target_world) - upper.origin
	var reach := clampf(to_target.length(), 0.08, a + b - 0.015)
	var direction := to_target.normalized()
	var along := (a * a - b * b + reach * reach) / (2.0 * reach)
	var height := sqrt(maxf(0.0, a * a - along * along))
	var guide := _luke_skeleton.global_basis.inverse() * (Vector3.DOWN - camera.global_basis.x * 0.35)
	var bend := guide - direction * guide.dot(direction)
	if bend.length_squared() < 0.000001: return
	var elbow := upper.origin + direction * along + bend.normalized() * height
	var adjusted_hand := upper.origin + direction * reach
	var upper_turn := Quaternion((lower.origin - upper.origin).normalized(), (elbow - upper.origin).normalized())
	var lower_turn := Quaternion((hand.origin - lower.origin).normalized(), (adjusted_hand - elbow).normalized())
	_luke_skeleton.set_bone_global_pose_override(_left_arm_bones[0], Transform3D(Basis(upper_turn) * upper.basis, upper.origin), weight, true)
	_luke_skeleton.set_bone_global_pose_override(_left_arm_bones[1], Transform3D(Basis(lower_turn) * lower.basis, elbow), weight, true)
	if _action_kind != &"bandage":
		for finger in _left_grip_fingers:
			var base := _luke_skeleton.get_bone_global_pose(finger.index)
			_luke_skeleton.set_bone_global_pose_override(finger.index, Transform3D(base.basis * Basis(Vector3.BACK, float(finger.curl)), base.origin), weight, true)

func _update_supply_visuals(show_visual: bool) -> void:
	var held := selected_quick_item()
	var battery := (_action_kind == &"battery" and not _action_effect_done) or (_action_kind == &"" and str(held).begins_with("battery_") and item_count(held) > 0)
	var bandage := _action_kind == &"" and held == &"bandage" and item_count(held) > 0
	var wrapping := _action_kind == &"bandage"
	var unlit_flare := (_action_kind == &"flare" and not _action_effect_done) or (_action_kind == &"" and _flare_remaining <= 0.0 and held == &"flare" and item_count(held) > 0)
	var fallback := not show_visual or not is_instance_valid(_hand_mount)
	if is_instance_valid(_hand_battery):
		_hand_battery.visible = battery
		_hand_battery.position = Vector3(0.075, 0.012, 0.0)
		var direction := _reload_torch_direction() if _action_kind == &"battery" else Vector3.UP
		_hand_battery.quaternion = Quaternion(Vector3.UP, (_hand_mount.global_basis.inverse() * direction).normalized())
	if is_instance_valid(_hand_bandage):
		_hand_bandage.visible = bandage
		_hand_bandage.position = Vector3(0.075, 0.015, 0.0)
		var right := camera.global_basis.x.normalized()
		var back := camera.global_basis.z.normalized()
		_hand_bandage.global_basis = Basis(right, back, right.cross(back))
	if is_instance_valid(_hand_bandage_roll):
		_hand_bandage_roll.visible = wrapping
		_hand_bandage_roll.global_position = _hand_mount.global_position - camera.global_basis.z * 0.035 + Vector3.UP * 0.015
		_hand_bandage_roll.global_basis = Basis(Quaternion(Vector3.RIGHT, camera.global_basis.x.normalized()))
	if is_instance_valid(_hand_unlit_flare):
		_hand_unlit_flare.visible = unlit_flare
		_hand_unlit_flare.position = Vector3(0.075, 0.015, 0.0)
		_hand_unlit_flare.quaternion = Quaternion(Vector3.UP, (_hand_mount.global_basis.inverse() * Vector3.UP).normalized())
	if is_instance_valid(_reload_flashlight):
		_reload_flashlight.visible = _action_kind == &"battery"
		if _reload_flashlight.visible:
			_reload_flashlight.global_position = _reload_torch_center_world()
			_reload_flashlight.global_basis = Basis(Quaternion(Vector3.FORWARD, _reload_torch_direction()))
	if is_instance_valid(_placed_flare) and _flare_remaining > 0.0:
		_flare_light.global_position = _placed_flare.to_global(Vector3(0, 0, -0.18)) + Vector3.UP * 0.04
	elif is_instance_valid(_hand_flare) and _flare_remaining > 0.0:
		_hand_flare.position = Vector3(-0.055, 0.015, 0.0)
		_hand_flare.quaternion = Quaternion(Vector3.FORWARD, (_left_hand_mount.global_basis.inverse() * (Vector3.UP - camera.global_basis.x * 0.3).normalized()).normalized())
		_flare_light.global_position = _hand_flare.to_global(Vector3(0, 0, -0.18))
	if is_instance_valid(_view_battery):
		_view_battery.visible = fallback and battery
		_view_battery.position = Vector3(0.38, -0.30, -0.48)
	if is_instance_valid(_view_bandage):
		_view_bandage.visible = fallback and (bandage or wrapping)
		_view_bandage.position = Vector3(0.34 - 0.10 * _supply_action_lift() if wrapping else 0.34, -0.29, -0.50)
	if is_instance_valid(_view_unlit_flare):
		_view_unlit_flare.visible = fallback and unlit_flare
		_view_unlit_flare.position = Vector3(0.36, -0.32, -0.50)

func _knife_pose_sample(time: float) -> Dictionary:
	# Camera-space X/right, Y/up, Z/forward. A short raised windup leads into
	# one curved diagonal cut, a follow-through, then a longer recovery.
	var ready := Vector3(0.30, -0.04, 0.16)
	var windup := Vector3(0.36, 0.22, 0.10)
	# Finish beside the inner-right guard. Crossing behind the torso hid the
	# complete follow-through from the production shoulder camera.
	var finish := Vector3(0.08, -0.40, 0.22)
	var ready_blade := Vector3(0.50, 0.08, 0.82).normalized()
	var windup_blade := Vector3(0.80, 0.60, 0.10).normalized()
	var finish_blade := Vector3(-0.80, -0.65, 0.35).normalized()
	if time <= 0.14:
		var windup_weight := smoothstep(0.0, 0.14, time)
		return {"hand": ready.lerp(windup, windup_weight), "blade": ready_blade.slerp(windup_blade, windup_weight), "torso": -0.18 * windup_weight}
	if time <= 0.34:
		var cut := clampf((time - 0.14) / 0.20, 0.0, 1.0)
		var hand := windup.bezier_interpolate(Vector3(0.35, 0.20, 0.45), Vector3(0.10, -0.16, 0.58), finish, cut)
		return {"hand": hand, "blade": windup_blade.slerp(finish_blade, cut), "torso": lerpf(-0.18, 0.45, cut)}
	var recovery := smoothstep(0.39, KNIFE_ACTION_DURATION, time)
	return {"hand": finish.lerp(ready, recovery), "blade": finish_blade.slerp(ready_blade, recovery), "torso": 0.45 * (1.0 - recovery)}

func _update_right_hand_grip() -> void:
	var weight := 1.0 if selected_quick_item() != &"" or _action_kind != &"" else 0.0
	# Pose overrides survive the recovered idle AnimationPlayer, which writes
	# over ordinary per-bone pose rotations after the physics tick.
	for grip_bone in _right_grip_fingers:
		var index: int = grip_bone.index
		_luke_skeleton.set_bone_global_pose_override(index, Transform3D.IDENTITY, 0.0, false)
	if weight <= 0.0: return
	for grip_bone in _right_grip_fingers:
		var index: int = grip_bone.index
		var curl: float = grip_bone.curl
		if selected_quick_item() in [&"knife", &"flashlight", &"candy_bar"] or _action_kind in [&"knife", &"candy_bar"]:
			var bone_name := _luke_skeleton.get_bone_name(index)
			if bone_name == "Bip01 R Finger0": curl = 0.60
			elif bone_name == "Bip01 R Finger01": curl = 0.70
		var base := _luke_skeleton.get_bone_global_pose(index)
		var curled := Transform3D(base.basis * Basis(Vector3.BACK, curl * weight), base.origin)
		_luke_skeleton.set_bone_global_pose_override(index, curled, 1.0, true)

func _tick_equipment(delta: float) -> void:
	_knife_cooldown = maxf(0.0, _knife_cooldown - delta)
	_flare_remaining = maxf(0.0, _flare_remaining - delta)
	if _flare_remaining <= 0.0: _clear_placed_flare()
	_flare_light.visible = _flare_remaining > 0.0
	var powered := _light_on and selected_quick_item() == &"flashlight" and _action_kind == &"" and is_item_equipped(&"flashlight") and battery_charge > 0.0
	if powered:
		battery_charge = maxf(0.0, battery_charge - BATTERY_DRAIN_PER_SECOND * delta)
		if battery_charge <= 25.0:
			_flicker_clock += delta
			_flicker_off_remaining = maxf(0.0, _flicker_off_remaining - delta)
			var interval := 1.55 if battery_charge <= 8.0 else 4.2
			if _flicker_clock >= interval:
				_flicker_clock = 0.0
				_flicker_off_remaining = 0.20 if battery_charge <= 8.0 else 0.08
				_item_audio.play_cue(&"flicker")
		else:
			_flicker_clock = 0.0
			_flicker_off_remaining = 0.0
	lamp.visible = powered and battery_charge > 0.0 and _flicker_off_remaining <= 0.0
	lamp.light_energy = 1.85 if progression.has_flashlight else 1.45
	_update_flashlight_lenses()
	if absf(battery_charge - _battery_reported) >= 0.5 or (battery_charge <= 0.0 and _battery_reported > 0.0):
		_battery_reported = battery_charge
		battery_changed.emit(battery_charge)
	_beam_scan_remaining -= delta
	if lamp.visible and _beam_scan_remaining <= 0.0:
		_beam_scan_remaining = 0.12
		_scan_flashlight_beam(0.12)

func _scan_flashlight_beam(sample_seconds: float) -> void:
	# Gameplay aim uses the shoulder camera's unobstructed view. The physical
	# cone still starts at the torch lens, which remains within its 27° spread.
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var space := get_world_3d().direct_space_state
	var tested := 0
	for group in [&"spider", &"mini_spider"]:
		for candidate in get_tree().get_nodes_in_group(group):
			if tested >= 12: return
			tested += 1
			if not is_instance_valid(candidate) or not candidate is CollisionObject3D or not candidate.visible or not candidate.has_method("apply_flashlight_beam"): continue
			var centre: Vector3 = candidate.global_position + Vector3.UP * (0.3 if group == &"spider" else 0.14)
			var toward: Vector3 = centre - origin
			if toward.length() > 9.0 or toward.length_squared() < 0.01 or forward.dot(toward.normalized()) < 0.91: continue
			var ray := PhysicsRayQueryParameters3D.create(origin, centre, 1 | 4, [get_rid()])
			var hit := space.intersect_ray(ray)
			if not hit.is_empty() and hit.collider == candidate:
				candidate.apply_flashlight_beam(0.6 + 0.4 * battery_charge / 100.0, sample_seconds)

func _knife_strike() -> bool:
	var origin := global_position + Vector3.UP * 0.65
	var facing := -camera.global_basis.z
	var closest: Node3D
	var distance := KNIFE_REACH
	for group in [&"mini_spider", &"spider"]:
		for candidate in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(candidate) or not candidate is Node3D or not candidate.visible or not candidate.has_method("take_damage"): continue
			if candidate.has_method("is_alive") and not candidate.is_alive(): continue
			var toward: Vector3 = candidate.global_position + Vector3.UP * 0.25 - origin
			var length := toward.length()
			if length >= distance or length < 0.01 or facing.dot(toward.normalized()) < 0.35: continue
			var ray := PhysicsRayQueryParameters3D.create(origin, candidate.global_position + Vector3.UP * 0.25, 1, [get_rid()])
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			closest = candidate
			distance = length
	if is_instance_valid(closest):
		closest.call("take_damage", KNIFE_DAMAGE)
		return true
	return false

func _set_crouch(enabled: bool) -> void:
	_crouching = enabled
	_capsule_shape.shape = _crouching_capsule if enabled else _standing_capsule
	_capsule_shape.position.y = 0.55 if enabled else 0.875

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _standing_clearance
	query.transform = global_transform * Transform3D(Basis(), Vector3(0, 1.43, 0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func is_crouching() -> bool:
	return _crouching

func take_damage(amount: float) -> void:
	if _recovering or not active or _hurt_time > 0.0: return
	health = maxf(0.0, health - amount)
	_hurt_time = 0.65
	health_changed.emit(health)
	if health <= 0.0:
		_cancel_item_action()
		_recovering = true
		_recovery_generation += 1
		var generation := _recovery_generation
		recovery_changed.emit(true)
		await get_tree().create_timer(1.1, false).timeout
		if _recovering and generation == _recovery_generation: progression.retry_checkpoint()

func restore_checkpoint() -> void:
	_recovery_generation += 1
	_cancel_item_action()
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	health = 100.0
	_yaw = _spawn_yaw
	_pitch = -0.09
	pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	visual.rotation.y = _yaw
	_hurt_time = 0.0
	stamina = 100.0
	_stamina_reported = stamina
	_stamina_recovery_delay = 0.0
	_set_crouch(false)
	_locomotion_pose.clear()
	pivot.position.y = 1.48
	_recovering = false
	health_changed.emit(health)
	stamina_changed.emit(stamina)
	battery_changed.emit(battery_charge)
	inventory_changed.emit()
	flashlight_changed.emit(_light_on)
	recovery_changed.emit(false)

func is_recovering() -> bool:
	return _recovering

func set_view(yaw: float) -> void:
	if not active:
		_spawn_yaw = yaw
		visual.rotation.y = yaw
	_yaw = yaw
	pivot.rotation.y = yaw
