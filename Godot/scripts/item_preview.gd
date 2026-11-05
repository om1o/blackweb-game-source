class_name BlackwebItemPreview
extends Node
## One small isolated render per selected item, never a continuously drawn scene.
signal preview_ready(texture: Texture2D, item_id: StringName)
var _viewport: SubViewport
var _scene: Node3D
var _camera: Camera3D
var _model: Node3D
var _request := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.name = "SelectedItemOnce"
	_viewport.size = Vector2i(256, 256)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_scene = Node3D.new()
	_viewport.add_child(_scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.TRANSPARENT
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.83, .88, .82)
	world.environment.ambient_light_energy = .65
	_scene.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_color = Color(.91, .93, .85)
	key.light_energy = 1.5
	key.shadow_enabled = false
	_scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25, 140, 0)
	fill.light_color = Color(.65, .74, .68)
	fill.light_energy = .7
	_scene.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 35
	_camera.near = .001
	_camera.far = 100
	_scene.add_child(_camera)
	_camera.make_current()

func show_model(source: Node3D, item_id: StringName) -> void:
	clear()
	if not is_instance_valid(source) or not is_instance_valid(_viewport):
		preview_ready.emit(null, item_id)
		return
	_model = Node3D.new()
	_scene.add_child(_model)
	_copy_meshes(source, _model, Transform3D.IDENTITY, true)
	var meshes := _model.find_children("*", "MeshInstance3D", false, false)
	if meshes.is_empty():
		preview_ready.emit(null, item_id)
		return
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var box: AABB = mesh.transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_model.position = -bounds.get_center()
	var radius := maxf(.015, bounds.size.length() * .5)
	# The held knife/torch shaft runs along Z. A side-biased view keeps its
	# length readable instead of looking almost directly into the handle.
	_camera.position = Vector3(1.8, .8, .7).normalized() * radius * 3.4
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_publish_after_draw(_request, item_id)

func _copy_meshes(source: Node3D, target: Node3D, parent_transform: Transform3D, is_root: bool = false) -> void:
	if not is_root and not source.visible: return
	var placement := parent_transform if is_root else parent_transform * source.transform
	if source is MeshInstance3D and source.mesh != null:
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.material_override = source.material_override
		copy.material_overlay = source.material_overlay
		copy.transform = placement
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index in range(source.get_surface_override_material_count()):
			copy.set_surface_override_material(index, source.get_surface_override_material(index))
		target.add_child(copy)
	for child in source.get_children():
		if child is Node3D: _copy_meshes(child, target, placement)

func _publish_after_draw(request: int, item_id: StringName) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	if not is_inside_tree() or request != _request: return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	preview_ready.emit(_viewport.get_texture(), item_id)

func clear() -> void:
	_request += 1
	if is_instance_valid(_model):
		_model.hide()
		_model.queue_free()
	if is_instance_valid(_viewport): _viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
