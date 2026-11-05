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
var _knife_chest_bone := -1
var _knife_chest_override_applied := false
var _hand_candy: Node3D
var _view_candy: Node3D
var _hand_flare: Node3D
var _view_flare: Node3D
var _item_audio: ItemAudio
var _action_kind: StringName = &""
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
		if skeleton.find_bone("Bip01 L Hand") >= 0:
			var left_hand := BoneAttachment3D.new()
			left_hand.name = "LeftHandFlareMount"
			left_hand.bone_name = "Bip01 L Hand"
			skeleton.add_child(left_hand)
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
	return head_world - camera.global_basis.z * 0.09 + camera.global_basis.x * 0.025 - Vector3.UP * 0.045

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
	var sprinting := Input.is_action_pressed("sprint") and input.length_squared() > 0.04 and is_on_floor() and not _crouching and stamina > 0.0
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
	if _hurt_time > 0.0: speed *= 0.55
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 10.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 10.0)
	if not is_on_floor(): velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("jump") and not _crouching and stamina >= JUMP_COST:
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
		if not inventory.remove(id): return false
		add_battery(float(str(id).trim_prefix("battery_")))
		_item_audio.play_cue(&"switch")
		inventory_changed.emit()
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
			health = minf(100.0, health + 55.0)
			inventory.remove(id)
			health_changed.emit(health)
			inventory_changed.emit()
			return true
		&"flare":
			if _flare_remaining > 0.0: return false
			inventory.remove(id)
			_flare_remaining = 10.0
			_flare_light.visible = true
			_item_audio.play_cue(&"switch")
			inventory_changed.emit()
			return true
	return false

func reset_starting_inventory() -> void:
	_action_kind = &""
	_action_time = 0.0
	_action_effect_done = false
	if is_instance_valid(_item_audio): _item_audio.silence()
	inventory.reset()
	selected_quick_index = 0
	battery_charge = clampf(starting_battery_charge, 0.0, 100.0)
	_battery_reported = battery_charge
	_light_on = true
	_flicker_clock = 0.0
	_flicker_off_remaining = 0.0
	_flare_remaining = 0.0
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
	var duration := KNIFE_ACTION_DURATION if _action_kind == &"knife" else CANDY_ACTION_DURATION
	if _action_time >= duration:
		_action_kind = &""
		_action_time = 0.0
		_action_effect_done = false

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
		_hand_flashlight.position = _hand_flashlight.position.lerp(Vector3(0.065, 0.012, -0.01) if aim else Vector3(0.05, -0.01, -0.04), lift)
		# The torch's -Z axis is its lens direction. Resolve the camera aim in
		# hand space so turning or pitching never leaves the barrel pointing away
		# from the actual light cone.
		var hand_rotation := _hand_mount.global_basis.orthonormalized().get_rotation_quaternion()
		var camera_rotation := camera.global_basis.orthonormalized().get_rotation_quaternion()
		# A small outward cant leaves the cylindrical body readable from the
		# over-shoulder camera while keeping the view inside the beam cone.
		var beam_rotation := hand_rotation.inverse() * camera_rotation * Quaternion(Vector3.UP, -0.30)
		_hand_flashlight.quaternion = _hand_flashlight.quaternion.slerp(beam_rotation, lift)
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
		_hand_candy.position = Vector3.ZERO
		var candy_body := _hand_candy.get_node_or_null("CandyBarBody") as Node3D
		if candy_body: candy_body.position.x = lerpf(0.115, 0.075, raise)
		if is_instance_valid(_hand_mount) and is_instance_valid(_luke_skeleton):
			var grip_offset_world := camera.global_basis.x * lerpf(0.025, 0.012, raise) - Vector3.UP * 0.012
			_hand_candy.position = _hand_mount.global_basis.inverse() * grip_offset_world
			var head_index := _luke_skeleton.find_bone("Bip01 Head")
			if head_index >= 0:
				var mouth_world := _candy_mouth_world()
				var to_mouth := mouth_world - _hand_candy.global_position
				var ready_world := (Vector3.UP * 0.7 - camera.global_basis.z * 0.6 + camera.global_basis.x * 0.2).normalized()
				var bar_direction := ready_world.lerp(to_mouth.normalized(), raise) if to_mouth.length_squared() > 0.000001 else ready_world
				if bar_direction.length_squared() > 0.000001:
					var hand_local := (_hand_mount.global_basis.inverse() * bar_direction).normalized()
					_hand_candy.quaternion = Quaternion(Vector3.RIGHT, hand_local)
	if is_instance_valid(_view_candy):
		_view_candy.visible = fallback and (holding_candy or eating)
		_set_candy_bitten(_view_candy, eating and _action_effect_done)
		_view_candy.position = Vector3(0.41 - 0.12 * raise, -0.37 + 0.26 * raise, -0.54 - 0.16 * raise)
		_view_candy.rotation = Vector3(-0.15 - 0.4 * raise, -0.25, 0.17 + 0.14 * raise)
	if is_instance_valid(_hand_flare): _hand_flare.visible = _flare_remaining > 0.0
	if is_instance_valid(_view_flare): _view_flare.visible = _flare_remaining > 0.0 and (not show_visual or not is_instance_valid(_hand_flare))
	if is_instance_valid(_grip_fill):
		_grip_fill.visible = show_visual and (holding_torch or holding_knife or holding_candy or striking or eating)
		_grip_fill.light_energy = 0.55 if aim and holding_torch else 0.30
	var visible_torch := _hand_flashlight if show_visual and is_instance_valid(_hand_flashlight) else _view_flashlight
	if holding_torch and is_instance_valid(visible_torch):
		lamp.global_transform = Transform3D(visible_torch.global_basis.orthonormalized(), visible_torch.to_global(Vector3(0.0, 0.0, -0.13)))

func _update_right_arm_pose(delta: float) -> void:
	if not is_instance_valid(_luke_skeleton) or _right_upper_bone < 0 or _right_forearm_bone < 0 or _right_hand_bone < 0: return
	if _knife_chest_override_applied:
		_luke_skeleton.set_bone_global_pose_override(_knife_chest_bone, Transform3D.IDENTITY, 0.0, false)
		_knife_chest_override_applied = false
	if _knife_wrist_override_applied:
		_luke_skeleton.set_bone_global_pose_override(_right_hand_bone, Transform3D.IDENTITY, 0.0, false)
		_knife_wrist_override_applied = false
	var wanted := 1.0 if _light_on or selected_quick_item() == &"knife" or selected_quick_item() == &"candy_bar" or _action_kind != &"" else 0.0
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
	# Solve the hand target in camera/world space. The source mesh's +Z is
	# forward; the old fixed -Z target pulled the arm behind Luke's shoulder.
	var target_world := shoulder_world + facing * 0.16 + right * 0.30 - Vector3.UP * 0.04
	if _action_kind == &"knife":
		var slash_offset: Vector3 = _knife_pose_sample(_action_time).hand
		target_world = shoulder_world + right * slash_offset.x + Vector3.UP * slash_offset.y + facing * slash_offset.z
	elif _action_kind == &"candy_bar":
		var lift := _candy_raise_amount()
		var head_index := _luke_skeleton.find_bone("Bip01 Head")
		var head_world := _luke_skeleton.to_global(_luke_skeleton.get_bone_global_pose(head_index).origin) if head_index >= 0 else shoulder_world + Vector3.UP * 0.2
		var mouth_world := head_world + facing * 0.09 + right * 0.025 - Vector3.UP * 0.045
		# Hold the wrapper beside the mouth; the exposed end reaches the lips.
		# Sending the palm itself to the mouth hid the bar inside Luke's face.
		var bite_grip := mouth_world + right * 0.13 + facing * 0.025 - Vector3.UP * 0.01
		target_world = (shoulder_world + facing * 0.19 + right * 0.22 - Vector3.UP * 0.18).lerp(bite_grip, lift)
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
	_update_right_hand_grip()

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
		if selected_quick_item() == &"knife" or _action_kind == &"knife":
			var bone_name := _luke_skeleton.get_bone_name(index)
			if bone_name == "Bip01 R Finger0": curl = 0.60
			elif bone_name == "Bip01 R Finger01": curl = 0.70
		var base := _luke_skeleton.get_bone_global_pose(index)
		var curled := Transform3D(base.basis * Basis(Vector3.BACK, curl * weight), base.origin)
		_luke_skeleton.set_bone_global_pose_override(index, curled, 1.0, true)

func _tick_equipment(delta: float) -> void:
	_knife_cooldown = maxf(0.0, _knife_cooldown - delta)
	_flare_remaining = maxf(0.0, _flare_remaining - delta)
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
		_recovering = true
		_recovery_generation += 1
		var generation := _recovery_generation
		recovery_changed.emit(true)
		await get_tree().create_timer(1.1, false).timeout
		if _recovering and generation == _recovery_generation: progression.retry_checkpoint()

func restore_checkpoint() -> void:
	_recovery_generation += 1
	_action_kind = &""
	_action_time = 0.0
	_action_effect_done = false
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
