extends SceneTree
## Build after shared editor import. --inspect reads raw GLB without writing cache.
const SOURCE := "res://assets/recovered/Arachnophobia/Content/Spider/SpiderAnimated.glb"
const OUTPUT := "res://scenes/spider_visual.tscn"
const RATES := {"Idle": 0.0, "Walk": 1.5, "Run": 0.7}
const HEIGHT := 0.64
const FPS := 60.0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var inspect := "--inspect" in OS.get_cmdline_user_args()
	var model: Node3D
	if inspect:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(SOURCE, state) != OK:
			push_error("Cannot read recovered spider GLB")
			quit(1)
			return
		model = document.generate_scene(state, FPS)
	else:
		var packed := load(SOURCE) as PackedScene
		if packed == null:
			push_error("Complete the shared editor import before building the spider visual")
			quit(1)
			return
		model = packed.instantiate()
	var visual := Node3D.new()
	visual.name = "SpiderVisual"
	root.add_child(visual)
	model.name = "Model"
	model.scene_file_path = ""
	visual.add_child(model)
	var skeleton := model.find_child("*Skeleton3D*", true, false) as Skeleton3D
	var imported_player := model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	if not _check(skeleton != null and imported_player != null, "Recovered skeleton and animations exist"):
		_finish()
		return
	_check(skeleton.get_bone_count() == 142, "Expected 142 recovered bones")
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	_check(meshes.size() == 1, "Expected one original mesh")
	var library := AnimationLibrary.new()
	library.add_animation("RESET", _rest_animation(visual, skeleton))
	for source_name: String in RATES:
		if _check(imported_player.has_animation(source_name), "Recovered clip exists: " + source_name):
			var source_clip := imported_player.get_animation(source_name)
			library.add_animation(source_name.to_lower(), _resample(source_clip, source_name, visual, skeleton))
	imported_player.free()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.autoplay = "idle"
	player.deterministic = true
	player.add_animation_library("", library)
	visual.add_child(player)
	if not failures.is_empty():
		_finish()
		return
	player.play("idle")
	player.advance(0.0)
	var bounds := _skinned_bounds(visual, meshes)
	_check(bounds.size.y > 0.4 and bounds.size.y < 1.2, "Source spider height is plausible: " + str(bounds.size.y))
	var center := (skeleton.get_bone_global_pose(skeleton.find_bone("Root")).origin + skeleton.get_bone_global_pose(skeleton.find_bone("Back")).origin) * 0.5
	center = skeleton.global_transform * center
	model.scale = Vector3.ONE * (HEIGHT / bounds.size.y)
	model.position = Vector3(-center.x, -bounds.position.y, -center.z) * model.scale.x
	# The original fang-to-abdomen direction is already local -Z. No yaw is added.
	for mesh in meshes:
		mesh.custom_aabb = AABB(Vector3(-1.7, -0.3, -1.0), Vector3(3.4, 1.8, 3.2))
		mesh.extra_cull_margin = 0.1
	_validate(visual, skeleton, player, meshes)
	player.play("idle")
	player.advance(0.0)
	visual.set_meta("source", SOURCE)
	visual.set_meta("source_rates", RATES)
	visual.set_meta("height_m", HEIGHT)
	visual.set_meta("leg_span_m", _skinned_bounds(visual, meshes).size.x)
	visual.set_meta("forward", "-Z")
	visual.set_meta("animation_sample_hz", FPS)
	if not inspect and failures.is_empty():
		for child in visual.get_children():
			_set_owner(child, visual)
		var scene := PackedScene.new()
		_check(scene.pack(visual) == OK, "Scene packs")
		_check(ResourceSaver.save(scene, OUTPUT) == OK, "Scene saves")
		var saved := ResourceLoader.load(OUTPUT, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		_check(saved != null, "Saved scene reloads")
		if saved:
			var instance := saved.instantiate()
			var saved_player := instance.get_node("AnimationPlayer") as AnimationPlayer
			for clip in ["idle", "walk", "run"]:
				_check(saved_player.has_animation(clip), "Saved clip exists: " + clip)
			instance.free()
	print("VISUAL scale=", model.scale.x, " offset=", model.position, " height=", HEIGHT, " span=", visual.get_meta("leg_span_m"), " facing=-Z")
	visual.free()
	_finish()

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)

func _rest_animation(visual: Node3D, skeleton: Skeleton3D) -> Animation:
	var clip := Animation.new()
	clip.length = 0.0
	for bone in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone)
		for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var track := clip.add_track(type)
			clip.track_set_path(track, NodePath(str(visual.get_path_to(skeleton)) + ":" + skeleton.get_bone_name(bone)))
			var value: Variant = rest.origin if type == Animation.TYPE_POSITION_3D else (rest.basis.get_rotation_quaternion() if type == Animation.TYPE_ROTATION_3D else rest.basis.get_scale())
			clip.track_insert_key(track, 0.0, value)
	return clip

func _resample(source: Animation, source_name: String, visual: Node3D, skeleton: Skeleton3D) -> Animation:
	var clip := Animation.new()
	clip.resource_name = source_name.to_lower()
	clip.loop_mode = Animation.LOOP_LINEAR
	var frozen := source_name == "Idle"
	clip.length = 1.0 if frozen else source.length / float(RATES[source_name])
	var samples := 0 if frozen else ceili(clip.length * FPS)
	var key_total := 0
	for source_track in source.get_track_count():
		var source_path := source.track_get_path(source_track)
		if not _check(source_path.get_subname_count() == 1, "Source track is a bone: " + str(source_path)):
			continue
		var bone_name := String(source_path.get_subname(0))
		var bone := skeleton.find_bone(bone_name)
		if not _check(bone >= 0, "Target bone exists: " + bone_name):
			continue
		var type := source.track_get_type(source_track)
		if not _check(type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D], "Source uses transform tracks"):
			continue
		var track := clip.add_track(type)
		clip.track_set_path(track, NodePath(str(visual.get_path_to(skeleton)) + ":" + bone_name))
		var first: Variant = _sample(source, source_track, 0.0)
		var values: Array = []
		for sample in samples + 1:
			var fraction := 0.0 if samples == 0 else float(sample) / float(samples)
			var value: Variant = _sample(source, source_track, fraction * source.length)
			if type == Animation.TYPE_POSITION_3D and bone_name == "Root":
				# Root's parent is rotated: remove XZ in skeleton space, not bone space.
				var parent_basis := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).basis
				var movement: Vector3 = parent_basis * (value - first)
				movement.x = 0.0
				movement.z = 0.0
				value = first + parent_basis.inverse() * movement
			values.append(value)
		var constant := true
		for value: Variant in values:
			if not _equivalent(values[0], value):
				constant = false
				break
		if constant:
			clip.track_insert_key(track, 0.0, values[0])
			key_total += 1
		else:
			for sample in values.size():
				clip.track_insert_key(track, clip.length * float(sample) / float(samples), values[sample])
			key_total += values.size()
	print("RESAMPLED ", clip.resource_name, " source_seconds=", source.length, " source_rate=", RATES[source_name], " seconds=", clip.length, " tracks=", clip.get_track_count(), " keys=", key_total)
	return clip

func _sample(clip: Animation, track: int, time: float) -> Variant:
	match clip.track_get_type(track):
		Animation.TYPE_POSITION_3D: return clip.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D: return clip.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D: return clip.scale_track_interpolate(track, time)
	return null

func _equivalent(a: Variant, b: Variant) -> bool:
	if a is Quaternion:
		return absf(a.dot(b)) > 0.9999999
	return a.distance_squared_to(b) < 0.0000000001

func _skinned_bounds(visual: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh in meshes:
		var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
		skeleton.force_update_all_bone_transforms()
		var transform_to_visual := visual.global_transform.affine_inverse() * skeleton.global_transform
		var binds: Array[Transform3D] = []
		for index in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(index)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
			_check(bone >= 0, "Skin bind resolves")
			binds.append(transform_to_visual * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := int(weights.size() / vertices.size())
			for vertex in vertices.size():
				var position := Vector3.ZERO
				for influence in stride:
					var index := vertex * stride + influence
					position += (binds[bones[index]] * vertices[vertex]) * weights[index]
				minimum = minimum.min(position)
				maximum = maximum.max(position)
	return AABB(minimum, maximum - minimum)

func _validate(visual: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, meshes: Array[MeshInstance3D]) -> void:
	var bounds := _skinned_bounds(visual, meshes)
	_check(absf(bounds.position.y) < 0.0001, "Idle feet at local Y=0")
	_check(absf(bounds.size.y - HEIGHT) < 0.0001, "Height matches collider")
	var fangs := (skeleton.get_bone_global_pose(skeleton.find_bone("Fang_R")).origin + skeleton.get_bone_global_pose(skeleton.find_bone("Fang_L")).origin) * 0.5
	var back := skeleton.get_bone_global_pose(skeleton.find_bone("Back")).origin
	_check(fangs.z < back.z, "Fangs face local -Z")
	for name in ["idle", "walk", "run"]:
		var clip := player.get_animation(name)
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			_check(visual.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton, "Animation path resolves")
			_check(skeleton.find_bone(path.get_subname(0)) >= 0, "Animation bone resolves")
		var lowest := INF
		var highest := -INF
		var start_root := Vector3.ZERO
		var maximum_root_drift := 0.0
		player.play(name)
		for sample in 13:
			player.seek(clip.length * float(sample) / 13.0, true)
			player.advance(0.0)
			var pose_bounds := _skinned_bounds(visual, meshes)
			lowest = minf(lowest, pose_bounds.position.y)
			highest = maxf(highest, pose_bounds.end.y)
			_check(pose_bounds.size.x < 3.0 and pose_bounds.size.y < 1.2 and pose_bounds.size.z < 3.0, "Bounded skin in " + name)
			var root_position := skeleton.get_bone_global_pose(skeleton.find_bone("Root")).origin
			root_position.y = 0.0
			if sample == 0:
				start_root = root_position
			maximum_root_drift = maxf(maximum_root_drift, root_position.distance_to(start_root))
		_check(lowest > -0.06, "Feet remain above -6cm in " + name)
		_check(maximum_root_drift < 0.001, "No horizontal root displacement in " + name)
		print("VALIDATED ", name, " minimum_y=", lowest, " maximum_y=", highest, " horizontal_root_drift=", maximum_root_drift)

func _set_owner(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_set_owner(child, owner_node)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		push_error(message)
	return condition

func _finish() -> void:
	print("SPIDER VISUAL: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
