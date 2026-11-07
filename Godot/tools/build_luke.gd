extends SceneTree
## Run after editor import. Builds a standalone scene from licensed Rocketbox FBX.

const ASSETS := "res://assets/luke/"
const MODEL := ASSETS + "Export/Male_Adult_04.fbx"
const OUTPUT := "res://scenes/luke.tscn"
const CLIPS := {
	"idle": ASSETS + "Animations/m_idle_breathe_01.max.fbx",
	"walk": ASSETS + "Animations/m_walk_neutral.max.fbx",
	"run": ASSETS + "Animations/m_run_neutral.max.fbx",
}
const HEIGHT := 1.75
var failures: Array[String] = []
var report: Dictionary = {"source": MODEL, "height_m": HEIGHT, "clips": {}}
var replacement := false

func _initialize() -> void:
	replacement = "--replacement" in OS.get_cmdline_user_args()
	call_deferred("_build")

func _build() -> void:
	var source_path := "res://assets/third_party/rocketbox_luke_v2/luke_v2.glb" if replacement else MODEL
	report.source = source_path
	var packed := load(source_path) as PackedScene
	if not _check(packed != null, "Character FBX is imported"):
		_finish()
		return
	var luke := Node3D.new()
	luke.name = "Luke"
	root.add_child(luke)
	var model := packed.instantiate() as Node3D
	model.name = "Model"
	model.scene_file_path = ""
	luke.add_child(model)
	var skeleton := model.find_child("*Skeleton3D*", true, false) as Skeleton3D
	if not _check(skeleton != null, "Character has a skeleton"):
		_finish()
		return
	_prune_import(model)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	_check(meshes.size() == 1, "Expected one high-detail mesh; found %d" % meshes.size())
	for mesh in meshes:
		mesh.mesh = mesh.mesh.duplicate(true)
		mesh.skin = mesh.skin.duplicate(true)
		if replacement:
			# The source already has textured scalp geometry. Its extra hair cards
			# expose hard strips in Compatibility; retain the clean short-hair scalp.
			var clean := ArrayMesh.new()
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface)
				if "opacity" in material.resource_name.to_lower(): continue
				clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.mesh.surface_get_arrays(surface))
				clean.surface_set_material(clean.get_surface_count()-1,material)
			mesh.mesh=clean
		for surface in mesh.mesh.get_surface_count():
			var old_material: Material = mesh.mesh.surface_get_material(surface)
			mesh.mesh.surface_set_material(surface, _replacement_material(old_material) if replacement else _material(old_material.resource_name))
		# Raw source vertices are Z-up; skinning makes them Y-up. Cover moving poses.
		mesh.custom_aabb = AABB(Vector3(-1.0, -0.2, -1.0), Vector3(2.0, 2.5, 2.0))
		mesh.extra_cull_margin = 0.15
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.autoplay = "idle"
	luke.add_child(player)
	player.root_node = NodePath("..")
	player.deterministic = true
	var library := AnimationLibrary.new()
	library.add_animation("RESET", _rest_animation(luke, skeleton))
	for name: String in CLIPS:
		var animation := _import_clip(name, luke, skeleton)
		if animation:
			library.add_animation(name, animation)
	player.add_animation_library("", library)
	if not failures.is_empty():
		_finish()
		return
	# Eye and toe rest positions confirm that the source faces +Z.
	model.rotation.y = PI
	player.play("idle")
	player.advance(0.0)
	var bounds := _skinned_bounds(luke, meshes)
	_check(bounds.size.y > 1.5 and bounds.size.y < 2.2, "Plausible source height: " + str(bounds.size.y))
	model.scale = Vector3.ONE * (HEIGHT / bounds.size.y)
	model.position.y = -bounds.position.y * model.scale.y
	_validate(luke, skeleton, player, meshes)
	player.play("idle")
	player.advance(0.0)
	for child in luke.get_children():
		_set_owner(child, luke)
	var scene := PackedScene.new()
	_check(scene.pack(luke) == OK, "Scene packs")
	if failures.is_empty():
		_check(ResourceSaver.save(scene, OUTPUT) == OK, "Scene saves")
		_validate_saved_scene()
	report["bone_count"] = skeleton.get_bone_count()
	report["visible_meshes"] = meshes.size()
	report["model_scale"] = model.scale.x
	report["model_offset_y"] = model.position.y
	report["forward"] = "-Z"
	report["failures"] = failures
	var file := FileAccess.open("res://assets/third_party/rocketbox_luke_v2/validation.json" if replacement else ASSETS + "validation.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	luke.free()
	_finish()

func _prune_import(node: Node) -> void:
	for child in node.get_children():
		var label := String(child.name).to_lower()
		if child is AnimationPlayer or ("poly" in label and not "hipoly" in label):
			child.free()
		else:
			_prune_import(child)

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)

func _material(source_name: String) -> StandardMaterial3D:
	var part := "opacity" if "opacity" in source_name else ("head" if "head" in source_name else "body")
	var prefix := ASSETS + "Textures/m006_" + part
	var material := StandardMaterial3D.new()
	material.resource_name = "Luke_" + part
	material.albedo_color = Color.WHITE
	material.albedo_texture = load(prefix + "_color.tga") as Texture2D
	material.metallic = 0.0
	material.metallic_specular = 0.3
	material.roughness = 0.82 if part == "body" else 0.66
	if part == "opacity":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.38
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
	else:
		material.normal_enabled = true
		material.normal_texture = load(prefix + "_normal.tga") as Texture2D
		material.normal_scale = 0.8
	_check(material.albedo_texture != null, "Texture loaded for " + part)
	return material

func _replacement_material(source: Material) -> StandardMaterial3D:
	var material := source.duplicate(true) as StandardMaterial3D
	if material == null: material = StandardMaterial3D.new()
	var part := source.resource_name.to_lower()
	if part.begins_with("luke21_"):
		# Luke's custom variant carries separate clothing, skin and opaque curls.
		# Keep its coordinated factors; a second global tint would colour hands.
		material.metallic = 0.0
		material.metallic_specular = .25
		if "curls" in part:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = .35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.metallic_specular = 0.0
			material.roughness = 1.0
		_check(material.albedo_texture != null or "curls" in part,
			"Luke21 authored surface loaded: " + part)
		return material
	material.metallic = 0.0
	material.metallic_specular = .25
	material.roughness = .84 if "body" in part else .72
	if "body" in part: material.albedo_color = Color(.63,.68,.64)
	if "opacity" in part:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = .2
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_check(material.albedo_texture != null,"Replacement texture loaded: "+part)
	return material

func _rest_animation(luke: Node3D, skeleton: Skeleton3D) -> Animation:
	var animation := Animation.new()
	animation.length = 0.0
	for bone in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone)
		var path := NodePath(str(luke.get_path_to(skeleton)) + ":" + skeleton.get_bone_name(bone))
		for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var track := animation.add_track(type)
			animation.track_set_path(track, path)
			var value: Variant = rest.origin if type == Animation.TYPE_POSITION_3D else (rest.basis.get_rotation_quaternion() if type == Animation.TYPE_ROTATION_3D else rest.basis.get_scale())
			animation.track_insert_key(track, 0.0, value)
	return animation

func _import_clip(name: String, luke: Node3D, skeleton: Skeleton3D) -> Animation:
	if replacement: return _retarget_authored(name,luke,skeleton)
	var packed := load(CLIPS[name]) as PackedScene
	if not _check(packed != null, "Imported clip exists: " + name):
		return null
	var source := packed.instantiate()
	var source_player := source.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	if not _check(source_player != null, "AnimationPlayer exists: " + name):
		source.free()
		return null
	var clip: Animation
	for candidate in source_player.get_animation_list():
		if candidate != "RESET" and source_player.get_animation(candidate).get_track_count() > 0:
			clip = source_player.get_animation(candidate).duplicate(true)
			break
	if not _check(clip != null, "Animated clip exists: " + name):
		source.free()
		return null
	clip.resource_name = name
	clip.loop_mode = Animation.LOOP_LINEAR
	var removed_helpers := 0
	for track in range(clip.get_track_count() - 1, -1, -1):
		var path := clip.track_get_path(track)
		if path.get_subname_count() != 1:
			# MotionExtractionHelper and Biped Footsteps are authoring helpers, not
			# target bones. CharacterBody3D owns all world displacement.
			clip.remove_track(track)
			removed_helpers += 1
			continue
		var bone_name := String(path.get_subname(0))
		if replacement and bone_name=="Bip01" and skeleton.find_bone(bone_name)<0:
			# glTF keeps this FBX armature root as a node, not a deforming bone.
			# Its static transform is retained; CharacterBody owns displacement.
			clip.remove_track(track)
			removed_helpers+=1
			continue
		if not _check(skeleton.find_bone(bone_name) >= 0, name + " matches bone " + bone_name):
			continue
		clip.track_set_path(track, NodePath(str(luke.get_path_to(skeleton)) + ":" + bone_name))
		if bone_name == "Bip01" and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			for key in clip.track_get_key_count(track):
				var value: Vector3 = clip.track_get_key_value(track, key)
				value.x = 0.0
				value.z = 0.0
				clip.track_set_key_value(track, key, value)
	report["clips"][name] = {"duration_seconds": clip.length, "tracks": clip.get_track_count(), "removed_helper_tracks": removed_helpers}
	source.free()
	return clip

func _retarget_authored(name: String,luke: Node3D,skeleton: Skeleton3D) -> Animation:
	# Blender/glTF preserves the bind pose but changes bone local axes. Never
	# copy the original FBX's local keys onto these differently oriented bones.
	var motion = load("res://scripts/authored_motion.gd").new()
	motion.bind(skeleton)
	var id: String = {"idle":"Idle_Loop","walk":"Walk_Loop","run":"Jog_Fwd_Loop"}[name]
	var animation := Animation.new()
	animation.resource_name=name
	animation.length=float(motion.clips[id].duration)
	animation.loop_mode=Animation.LOOP_LINEAR
	for bone in skeleton.get_bone_count():
		var path := NodePath(str(luke.get_path_to(skeleton))+":"+skeleton.get_bone_name(bone))
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			var track := animation.add_track(type)
			animation.track_set_path(track,path)
	for i in range(ceili(animation.length*30.0)+1):
		motion.clear_overrides()
		skeleton.reset_bone_poses()
		var time := minf(animation.length,float(i)/30.0)
		motion.apply_clip(id,time,1.0,false,true)
		for bone in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(bone)
			var pose := skeleton.get_bone_global_pose(bone)
			if parent>=0: pose=skeleton.get_bone_global_pose(parent).affine_inverse()*pose
			animation.track_insert_key(bone*2,time,pose.origin)
			animation.track_insert_key(bone*2+1,time,pose.basis.get_rotation_quaternion())
	motion.clear_overrides()
	skeleton.reset_bone_poses()
	report["clips"][name]={"source":id,"duration_seconds":animation.length,"tracks":animation.get_track_count(),"retargeted":true}
	return animation

func _skinned_bounds(luke: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh in meshes:
		var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
		skeleton.force_update_all_bone_transforms()
		var skeleton_to_luke := luke.global_transform.affine_inverse() * skeleton.global_transform
		var binds: Array[Transform3D] = []
		for bind in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
			_check(bone >= 0, "Skin bind resolves")
			binds.append(skeleton_to_luke * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
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

func _validate(luke: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, meshes: Array[MeshInstance3D]) -> void:
	var baseline := _skinned_bounds(luke, meshes)
	_check(absf(baseline.position.y) < 0.0001, "Idle feet at local Y=0")
	_check(absf(baseline.size.y - HEIGHT) < 0.0001, "Idle height is 1.75 m")
	var head := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Bip01 Head")).origin
	var eye := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Bip01 REye")).origin
	_check((eye - head).z < 0.0, "Character faces local -Z")
	for name: String in CLIPS:
		var animation := player.get_animation(name)
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			_check(luke.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton, "Animation node resolves: " + str(path))
			_check(skeleton.find_bone(path.get_subname(0)) >= 0, "Animation bone resolves: " + str(path))
			if path.get_subname(0) == "Bip01" and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
				for key in animation.track_get_key_count(track):
					var position: Vector3 = animation.track_get_key_value(track, key)
					_check(absf(position.x) < 0.00001 and absf(position.z) < 0.00001, "No horizontal root displacement: " + name)
		var low := INF
		var high := -INF
		player.play(name)
		for sample in 9:
			player.seek(animation.length * float(sample) / 9.0, true)
			player.advance(0.0)
			var bounds := _skinned_bounds(luke, meshes)
			low = minf(low, bounds.position.y)
			high = maxf(high, bounds.end.y)
			_check(bounds.size.x < 2.0 and bounds.size.y < 2.2 and bounds.size.z < 2.0, "Skin remains bounded: " + name)
		_check(low > -0.08, "Feet do not sink more than 8 cm in " + name + ": " + str(low))
		report["clips"][name]["sampled_minimum_y"] = low
		report["clips"][name]["sampled_maximum_y"] = high
		print("CLIP ", name, " duration=", animation.length, " tracks=", animation.get_track_count(), " feet_min=", low, " top_max=", high)

func _validate_saved_scene() -> void:
	var scene := ResourceLoader.load(OUTPUT, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if not _check(scene != null, "Saved scene loads"):
		return
	var instance := scene.instantiate()
	var player := instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_check(player != null, "Saved AnimationPlayer exists")
	for clip: String in CLIPS:
		_check(player.has_animation(clip), "Saved clip exists: " + clip)
	instance.free()

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
	print("LUKE BUILD: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
