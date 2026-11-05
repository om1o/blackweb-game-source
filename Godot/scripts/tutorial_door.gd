class_name BlackwebTutorialDoor
extends Node3D

const HandleScript = preload("res://scripts/tutorial_door_handle.gd")

var progression: Node
var frame_template: Node3D
var hinge_template: Node3D
var creak_stream: AudioStream
var door_label := "door"
var opened := false
var _hinge: Node3D
var _tween: Tween
var locked := false
signal locked_interaction

func _ready() -> void:
	add_to_group("tutorial_door")
	if frame_template != null:
		var frame: Node3D = frame_template.duplicate()
		frame.name = "RecoveredDoorFrame"
		frame.position = Vector3(0.132, -1.0, 0.0)
		frame.rotation = Vector3(0.0, PI / 2.0, 0.0)
		add_child(frame)
	if hinge_template != null:
		_hinge = hinge_template.duplicate()
		_hinge.name = "RecoveredDoorHinge"
		_hinge.position = Vector3(0.22, -0.97727933, 0.604)
		add_child(_hinge)
		var body := StaticBody3D.new()
		body.name = "MovingDoorCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(0.0, 1.08, -0.59)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.07, 2.17, 1.18)
		shape.shape = box
		body.add_child(shape)
		_hinge.add_child(body)
		if door_label == "vault door": _add_vault_facing()
	for side in [-1.0, 1.0]:
		var handle = HandleScript.new()
		handle.name = "EntryHandle" if side < 0.0 else "ReturnHandle"
		handle.position = Vector3(side * 0.57, 0.0, -0.48)
		handle.progression = progression
		handle.door = self
		add_child(handle)
	if creak_stream != null:
		var creak := AudioStreamPlayer3D.new()
		creak.name = "RecoveredDoorCreak"
		creak.stream = creak_stream
		creak.volume_db = -18.0
		creak.max_distance = 12.0
		add_child(creak)

func toggle() -> void:
	if locked:
		locked_interaction.emit()
		return
	if not is_instance_valid(_hinge): return
	opened = not opened
	if is_instance_valid(_tween): _tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_tween.tween_property(_hinge, "rotation:y", -1.46 if opened else 0.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var creak := get_node_or_null("RecoveredDoorCreak") as AudioStreamPlayer3D
	if creak != null: creak.play()

func reset_closed() -> void:
	if is_instance_valid(_tween): _tween.kill()
	opened = false
	if is_instance_valid(_hinge): _hinge.rotation.y = 0.0

func _add_vault_facing() -> void:
	# A reinforced company storage door remains on the recovered hinge, so the
	# same 0.62 s opening animation and collision serve both directions.
	var steel := StandardMaterial3D.new()
	steel.resource_name = "Scuffed dark steel vault facing"
	steel.albedo_color = Color(0.72, 0.74, 0.75)
	steel.albedo_texture = load("res://assets/third_party/poly_haven/metal_plate_02/textures/metal_plate_02_diff_1k.jpg")
	steel.normal_enabled = true
	steel.normal_texture = load("res://assets/third_party/poly_haven/metal_plate_02/textures/metal_plate_02_nor_gl_1k.jpg")
	steel.normal_scale = 0.35
	steel.metallic = 0.52
	steel.roughness = 0.73
	var arm := load("res://assets/third_party/poly_haven/metal_plate_02/textures/metal_plate_02_arm_1k.jpg")
	steel.roughness_texture = arm
	steel.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	steel.metallic_texture = arm
	steel.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.045, 2.02, 1.07)
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		panel.name = "VaultSteelFacing"
		panel.mesh = panel_mesh
		panel.material_override = steel
		panel.position = Vector3(side * 0.075, 1.08, -0.59)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.set_meta("asset_origin", "Original Blackweb reinforced vault-door facing")
		_hinge.add_child(panel)
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.15
		ring_mesh.outer_radius = 0.19
		var wheel := MeshInstance3D.new()
		wheel.name = "VaultWheel"
		wheel.mesh = ring_mesh
		wheel.material_override = steel
		wheel.position = Vector3(side * 0.112, 1.13, -0.53)
		wheel.rotation.z = PI * 0.5
		wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hinge.add_child(wheel)
		var boss := MeshInstance3D.new()
		boss.name = "VaultWheelHub"
		var boss_mesh := CylinderMesh.new()
		boss_mesh.top_radius = 0.055
		boss_mesh.bottom_radius = 0.055
		boss_mesh.height = 0.035
		boss.mesh = boss_mesh
		boss.material_override = steel
		boss.position = Vector3(side * 0.125, 1.13, -0.53)
		boss.rotation.z = PI * 0.5
		boss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hinge.add_child(boss)
