extends SceneTree
## Run after Godot has imported the recovered GLBs:
## godot --headless --path <Godot project> --script res://tools/build_house.gd
## Optional user arguments: --manifest=res://... --output=res://... --report=res://...
## Exit 0 = complete, 2 = partial scene saved, 1 = fatal/input/save failure.
## GLB vertices are ALREADY converted to meters/Godot basis by the exporter.
## Only the manifest's world transforms are converted here. Never scale GLB vertices again.

const ASSET_ROOT := "res://assets/recovered"
const RecoveredMaterials = preload("res://tools/recovered_materials.gd")
const DEFAULT_MANIFEST := "res://data/recovered_components.json"
const DEFAULT_SCENE := "res://scenes/recovered_house.tscn"
const DEFAULT_REPORT := "res://data/house_import_report.json"
const STRUCTURE_WORDS := ["wall", "floor", "ceiling", "roof", "stair", "foundation", "door", "window", "beam", "pillar", "column", "railing", "fence", "porch"]
const FURNITURE_WORDS := ["sofa", "couch", "table", "chair", "bed", "wardrobe", "cabinet", "fridge", "refrigerator", "stove", "oven", "counter", "desk", "shelf", "dresser", "bathtub", "toilet", "sink", "bench", "piano"]
const CLUTTER_WORDS := ["bottle", "plate", "cup", "mug", "spoon", "fork", "knife", "food", "fruit", "toy", "gift", "present", "flower", "paper", "letter", "photo", "picture", "remote", "keys", "phone", "flashlight", "lamp", "candle", "shoe", "pillow", "curtain", "towel", "web", "spider"]

var _manifest_path: String = DEFAULT_MANIFEST
var _scene_path: String = DEFAULT_SCENE
var _report_path: String = DEFAULT_REPORT
var _asset_index: Dictionary = {}
var _report: Dictionary = {}
var _house: Node3D
var _house_bounds: AABB
var _has_house_bounds := false
var _materials = RecoveredMaterials.new(ASSET_ROOT)


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	_manifest_path = _argument("--manifest=", DEFAULT_MANIFEST)
	_scene_path = _argument("--output=", DEFAULT_SCENE)
	_report_path = _argument("--report=", DEFAULT_REPORT)
	_report = {
		"schema_version": 1,
		"manifest": _manifest_path,
		"asset_root": ASSET_ROOT,
		"scene": _scene_path,
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"coordinate_contract": "GLB vertices already converted; UE world cm (X,Y,Z) -> meters (X,Z,Y)*0.01; quaternion (x,y,z,w) -> (x,z,y,-w); scale -> (X,Z,Y)",
		"material_policy": "Runtime UE overrides applied by verified GLB surface order from recovered JSON; supported primary channels only. Original GLB resources remain unchanged; layered shader fidelity is partial.",
		"material_overrides_applied": false,
		"source_component_count": 0,
		"indexed_glb_count": 0,
		"placed": [], "missing": [], "ambiguous": [], "invalid": [],
		"resource_failures": [], "collision_skipped": [], "errors": [],
		"collision_body_count": 0, "collision_shape_count": 0,
		"collision_triangle_count": 0, "scene_saved": false, "complete": false
	}
	if not _is_project_path(_manifest_path) or not _is_project_path(_scene_path) or not _is_project_path(_report_path):
		# Do not write a diagnostic through an invalid, potentially external report path.
		push_error("Manifest, scene, and report paths must stay within this project (res://).")
		quit(1)
		return
	if _manifest_path == _scene_path or _manifest_path == _report_path or _scene_path == _report_path:
		push_error("Manifest, scene, and report paths must be distinct.")
		quit(1)
		return
	if not FileAccess.file_exists(_manifest_path):
		_fail("Component manifest does not exist: " + _manifest_path)
		return
	var parser := JSON.new()
	var parse_result: Error = parser.parse(FileAccess.get_file_as_string(_manifest_path))
	if parse_result != OK or not parser.data is Array:
		_fail("Expected a JSON array of world-space components: " + parser.get_error_message())
		return
	var components: Array = parser.data
	_report["source_component_count"] = components.size()
	if components.is_empty():
		_fail("The manifest is empty; no replacement/fallback house will be generated.")
		return
	var geometry_root: String = ASSET_ROOT.path_join("Geometry")
	var mesh_root: String = geometry_root if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(geometry_root)) else ASSET_ROOT
	_report["geometry_asset_root"] = mesh_root
	if not _index_assets(mesh_root):
		_fail("Recovered GLB directory could not be read: " + mesh_root)
		return

	_house = Node3D.new()
	_house.name = "RecoveredHouse"
	root.add_child(_house)
	_house.set_meta("source_manifest", _manifest_path)
	_house.set_meta("recovered_geometry", true)
	for index in range(components.size()):
		_place_component(components[index], index)

	if _report["placed"].is_empty():
		_fail("No original components could be placed. Existing scene output was not overwritten.")
		return
	var directory_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_scene_path.get_base_dir()))
	if directory_result != OK:
		_fail("Could not create scene output directory: " + error_string(directory_result))
		return
	var packed := PackedScene.new()
	var expected_materials: Dictionary = _material_snapshot(_house)
	var pack_result: Error = packed.pack(_house)
	if pack_result != OK:
		_fail("Packing the recovered scene failed: " + error_string(pack_result))
		return
	# Preserve the previous generated scene before replacing this tool's own output.
	if FileAccess.file_exists(_scene_path):
		var backup_result: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(_scene_path), ProjectSettings.globalize_path(_scene_path + ".previous"))
		if backup_result != OK:
			_fail("Could not preserve previous scene; output not overwritten: " + error_string(backup_result))
			return
	var save_result: Error = ResourceSaver.save(packed, _scene_path)
	if save_result != OK:
		_fail("Saving the recovered scene failed: " + error_string(save_result))
		return
	_report["scene_saved"] = true
	# Verify the persisted scene, not only the live instances used during assembly.
	# Imported scene ownership can silently discard child material overrides.
	var saved: Resource = ResourceLoader.load(_scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not saved is PackedScene:
		_fail("Saved house could not be reloaded for material verification.")
		return
	var reloaded: Node = (saved as PackedScene).instantiate()
	var persisted_materials: Dictionary = _material_snapshot(reloaded)
	_report["material_serialization"] = {"verified": expected_materials == persisted_materials, "expected_surface_count": expected_materials.size(), "persisted_surface_count": persisted_materials.size(), "policy": "Flatten node ownership; preserve shared imported mesh resources; compare every material and texture path after save/reload."}
	reloaded.free()
	if expected_materials != persisted_materials:
		_fail("Saved house material overrides differ from the assembled scene. See material_serialization in the report.")
		return
	_report["geometry_complete"] = _report["placed"].size() == components.size() and _report["errors"].is_empty()
	var material_audit: Dictionary = _materials.get_report()
	_report["complete"] = _report["geometry_complete"] and material_audit["override_coverage_complete"]
	_finish(0 if _report["complete"] else 2)


func _argument(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return fallback


func _is_project_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	var relative: String = path.substr(6).replace("\\", "/")
	return not relative.is_empty() and not relative.contains(":") and not relative.split("/").has("..")


func _index_assets(directory: String) -> bool:
	var access := DirAccess.open(directory)
	if access == null:
		return false
	access.list_dir_begin()
	var filename: String = access.get_next()
	while not filename.is_empty():
		var path: String = directory.path_join(filename)
		if access.current_is_dir():
			if not filename.begins_with(".") and not _index_assets(path):
				_report["errors"].append("Could not index recovered subdirectory: " + path)
		elif filename.get_extension().to_lower() == "glb":
			var key: String = filename.get_basename().to_lower()
			if not _asset_index.has(key):
				_asset_index[key] = []
			_asset_index[key].append(path)
			_report["indexed_glb_count"] += 1
		filename = access.get_next()
	access.list_dir_end()
	return true


func _mesh_basename(object_path: String) -> String:
	var cleaned: String = object_path.strip_edges().replace("\\", "/")
	# Accept /Game/X/Mesh.Mesh, StaticMesh /Game/X/Mesh.Mesh, and StaticMesh'/Game/...'.
	if cleaned.contains("/Game/"):
		cleaned = cleaned.substr(cleaned.find("/Game/"))
	cleaned = cleaned.trim_suffix("'").trim_suffix("\"")
	return cleaned.get_file().get_slice(".", 0).to_lower()


func _valid_numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for entry in value:
		if typeof(entry) != TYPE_FLOAT and typeof(entry) != TYPE_INT:
			return false
		if not is_finite(float(entry)):
			return false
	return true


func _world_transform(component: Dictionary) -> Dictionary:
	var position: Variant = component.get("position")
	var scale_values: Variant = component.get("scale", [1.0, 1.0, 1.0])
	if not _valid_numbers(position, 3) or not _valid_numbers(scale_values, 3):
		return {"error": "Position and scale must contain three finite numbers."}
	var converted_scale := Vector3(float(scale_values[0]), float(scale_values[2]), float(scale_values[1]))
	if absf(converted_scale.x) < 0.000001 or absf(converted_scale.y) < 0.000001 or absf(converted_scale.z) < 0.000001:
		return {"error": "Zero/degenerate component scale cannot be reconstructed safely."}
	var quaternion: Variant = component.get("quaternion", component.get("rotation_quaternion"))
	var converted_rotation: Quaternion
	if quaternion != null:
		if not _valid_numbers(quaternion, 4):
			return {"error": "Quaternion must contain finite UE [x,y,z,w] values."}
		converted_rotation = Quaternion(float(quaternion[0]), float(quaternion[2]), float(quaternion[1]), -float(quaternion[3]))
	else:
		var rotation: Variant = component.get("rotation")
		if not _valid_numbers(rotation, 3):
			return {"error": "A UE quaternion or [Pitch,Yaw,Roll] rotation is required."}
		var pitch: float = deg_to_rad(float(rotation[0])) * 0.5
		var yaw: float = deg_to_rad(float(rotation[1])) * 0.5
		var roll: float = deg_to_rad(float(rotation[2])) * 0.5
		# Unreal FRotator::Quaternion convention, followed by the same axis reflection.
		var ue_x: float = cos(roll) * sin(pitch) * sin(yaw) - sin(roll) * cos(pitch) * cos(yaw)
		var ue_y: float = -cos(roll) * sin(pitch) * cos(yaw) - sin(roll) * cos(pitch) * sin(yaw)
		var ue_z: float = cos(roll) * cos(pitch) * sin(yaw) - sin(roll) * sin(pitch) * cos(yaw)
		var ue_w: float = cos(roll) * cos(pitch) * cos(yaw) + sin(roll) * sin(pitch) * sin(yaw)
		converted_rotation = Quaternion(ue_x, ue_z, ue_y, -ue_w)
	if converted_rotation.length_squared() < 0.000001:
		return {"error": "Quaternion has zero length."}
	converted_rotation = converted_rotation.normalized()
	var converted_position := Vector3(float(position[0]), float(position[2]), float(position[1])) * 0.01
	var basis := Basis(converted_rotation) * Basis.from_scale(converted_scale)
	return {"transform": Transform3D(basis, converted_position), "quaternion": converted_rotation, "scale": converted_scale}


func _place_component(raw_component: Variant, index: int) -> void:
	if not raw_component is Dictionary:
		_report["invalid"].append({"index": index, "reason": "Component is not an object."})
		return
	var component: Dictionary = raw_component
	var source_name: String = str(component.get("name", "component_%04d" % index))
	var mesh_path: String = str(component.get("mesh", ""))
	var descriptor: Dictionary = {"index": index, "name": source_name, "mesh": mesh_path}
	var key: String = _mesh_basename(mesh_path)
	if key.is_empty() or not _asset_index.has(key):
		descriptor["basename"] = key
		_report["missing"].append(descriptor)
		return
	var candidates: Array = _asset_index[key]
	if candidates.size() != 1:
		descriptor["candidates"] = candidates.duplicate()
		_report["ambiguous"].append(descriptor)
		return
	var conversion: Dictionary = _world_transform(component)
	if conversion.has("error"):
		descriptor["reason"] = conversion["error"]
		_report["invalid"].append(descriptor)
		return
	var asset_path: String = str(candidates[0])
	var resource: Resource = ResourceLoader.load(asset_path)
	if not resource is PackedScene:
		descriptor["asset"] = asset_path
		descriptor["reason"] = "GLB is not an imported PackedScene; run the Godot editor import first."
		_report["resource_failures"].append(descriptor)
		return
	var instance: Node = (resource as PackedScene).instantiate()
	if not instance is Node3D:
		instance.free()
		descriptor["asset"] = asset_path
		descriptor["reason"] = "Recovered GLB scene root is not Node3D."
		_report["resource_failures"].append(descriptor)
		return
	var holder := Node3D.new()
	holder.name = ("%04d_" % index + source_name).validate_node_name()
	_house.add_child(holder)
	holder.owner = _house
	holder.transform = conversion["transform"]
	holder.set_meta("ue_component_name", source_name)
	holder.set_meta("ue_mesh_path", mesh_path)
	if component.get("materials") is Array:
		holder.set_meta("ue_material_references", component["materials"])
		descriptor["ue_material_references"] = component["materials"]
	holder.add_child(instance)
	_own_recovered_nodes(instance)
	# Keep original GLB geometry, mesh units, and local transform. Overrides below
	# are cloned per component so imported/shared material resources stay unchanged.
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(instance, meshes)
	if meshes.is_empty():
		holder.free()
		descriptor["asset"] = asset_path
		descriptor["reason"] = "Recovered scene contains no visible mesh geometry."
		_report["resource_failures"].append(descriptor)
		return
	if component.get("materials") is Array:
		var material_result: Dictionary = _materials.apply_overrides(meshes, asset_path, component["materials"], source_name)
		descriptor["material_overrides"] = material_result
		descriptor["material_overrides_applied"] = not material_result["applied"].is_empty()
	var bounds: AABB = _component_bounds(meshes)
	_house_bounds = _house_bounds.merge(bounds) if _has_house_bounds else bounds
	_has_house_bounds = true
	var collision_reason: String = _collision_decision(component, mesh_path, source_name, bounds.size)
	if collision_reason.begins_with("include_"):
		var triangle_count: int = _add_collision(meshes, holder.name)
		if triangle_count == 0:
			_report["collision_skipped"].append({"index": index, "name": source_name, "reason": "No valid triangle faces available."})
			collision_reason = "skipped_no_triangles"
	else:
		_report["collision_skipped"].append({"index": index, "name": source_name, "reason": collision_reason})
	descriptor["asset"] = asset_path
	descriptor["node_path"] = str(_house.get_path_to(holder))
	descriptor["position_m"] = _vector_array(holder.position)
	descriptor["scale"] = _vector_array(conversion["scale"])
	var converted_quaternion: Quaternion = conversion["quaternion"]
	descriptor["quaternion"] = [converted_quaternion.x, converted_quaternion.y, converted_quaternion.z, converted_quaternion.w]
	descriptor["bounds_min_m"] = _vector_array(bounds.position)
	descriptor["bounds_size_m"] = _vector_array(bounds.size)
	descriptor["collision"] = collision_reason
	_report["placed"].append(descriptor)


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
			meshes.append(mesh_instance)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _own_recovered_nodes(node: Node) -> void:
	# Make the imported hierarchy local to the generated house so PackedScene
	# serializes child overrides. Shared ArrayMesh/texture resources stay external.
	node.scene_file_path = ""
	node.owner = _house
	for child in node.get_children():
		_own_recovered_nodes(child)


func _material_snapshot(scene_root: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D or node.mesh == null:
			continue
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			var signature := {"material": material.resource_name if material != null else "<null>", "override": node.get_surface_override_material(surface) != null}
			if material is StandardMaterial3D:
				for channel in ["albedo", "normal", "roughness", "metallic", "ao"]:
					var texture: Texture2D = material.get(channel + "_texture")
					signature[channel] = texture.resource_path if texture != null else ""
				signature["color"] = material.albedo_color
				signature["transparency"] = material.transparency
				signature["uv_scale"] = material.uv1_scale
			snapshot[str(scene_root.get_path_to(node)) + ":" + str(surface)] = signature
	return snapshot


func _component_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var bounds: AABB = meshes[0].global_transform * meshes[0].get_aabb()
	for index in range(1, meshes.size()):
		bounds = bounds.merge(meshes[index].global_transform * meshes[index].get_aabb())
	return bounds


func _contains_any(value: String, words: Array) -> bool:
	for word in words:
		if value.contains(str(word)):
			return true
	return false


func _collision_decision(component: Dictionary, mesh_path: String, source_name: String, size: Vector3) -> String:
	if component.get("collision", null) is bool:
		return "include_explicit" if component["collision"] else "skipped_explicit"
	var label: String = (mesh_path + " " + source_name).to_lower()
	var structure: bool = _contains_any(label, STRUCTURE_WORDS)
	var furniture: bool = _contains_any(label, FURNITURE_WORDS)
	var clutter: bool = _contains_any(label, CLUTTER_WORDS)
	# A floor/wall lamp remains clutter; shelf/table names are furniture despite prop names.
	if label.contains("lamp") or label.contains("curtain") or label.contains("picture"):
		return "skipped_clutter"
	if clutter and not structure and not furniture:
		return "skipped_clutter"
	var extents: Array[float] = [absf(size.x), absf(size.y), absf(size.z)]
	extents.sort()
	if structure and extents[2] >= 0.25:
		return "include_structure"
	if furniture and extents[2] >= 0.40 and extents[1] >= 0.10:
		return "include_furniture"
	if extents[2] >= 0.80 and extents[1] >= 0.35 and size.x * size.y * size.z >= 0.04:
		return "include_large_geometry"
	return "skipped_small_geometry"


func _add_collision(meshes: Array[MeshInstance3D], component_name: String) -> int:
	var world_faces := PackedVector3Array()
	for mesh_instance in meshes:
		var faces: PackedVector3Array = mesh_instance.mesh.get_faces()
		var transform: Transform3D = mesh_instance.global_transform
		for index in range(0, faces.size() - 2, 3):
			var a: Vector3 = transform * faces[index]
			var b: Vector3 = transform * faces[index + 1]
			var c: Vector3 = transform * faces[index + 2]
			if a.is_finite() and b.is_finite() and c.is_finite() and (b - a).cross(c - a).length_squared() > 0.000000000001:
				world_faces.append(a)
				world_faces.append(b)
				world_faces.append(c)
	if world_faces.is_empty():
		return 0
	# Bake world-space faces so reflected/non-uniform component scale never reaches
	# the physics node. This uses original mesh triangles, not invented box geometry.
	var body := StaticBody3D.new()
	body.name = component_name + "_Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	_house.add_child(body)
	body.owner = _house
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(world_faces)
	var collision := CollisionShape3D.new()
	collision.name = "OriginalGeometry"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = _house
	var triangle_count: int = world_faces.size() / 3
	_report["collision_body_count"] += 1
	_report["collision_shape_count"] += 1
	_report["collision_triangle_count"] += triangle_count
	return triangle_count


func _vector_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


func _fail(message: String) -> void:
	_report["errors"].append(message)
	push_error(message)
	_finish(1)


func _finish(exit_code: int) -> void:
	_report["materials"] = _materials.get_report()
	_report["material_overrides_applied"] = _report["materials"]["applied_surface_count"] > 0
	_report["material_fidelity_complete"] = false # Unreal shader graphs are not recreated by this adapter.
	_report["placed_count"] = _report["placed"].size()
	_report["missing_count"] = _report["missing"].size()
	_report["ambiguous_count"] = _report["ambiguous"].size()
	_report["invalid_count"] = _report["invalid"].size()
	_report["resource_failure_count"] = _report["resource_failures"].size()
	_report["exit_code"] = exit_code
	if _has_house_bounds:
		_report["house_bounds_min_m"] = _vector_array(_house_bounds.position)
		_report["house_bounds_size_m"] = _vector_array(_house_bounds.size)
	var directory_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_report_path.get_base_dir()))
	if directory_result == OK:
		var report_file := FileAccess.open(_report_path, FileAccess.WRITE)
		if report_file != null:
			report_file.store_string(JSON.stringify(_report, "\t"))
			report_file.close()
		else:
			push_error("Could not write import report: " + _report_path)
			exit_code = 1
	else:
		push_error("Could not create report directory.")
		exit_code = 1
	print("Recovered house: %d/%d placed; %d missing; %d ambiguous; %d invalid; %d resource failures; %d collision bodies; complete=%s" % [
		_report["placed_count"], _report["source_component_count"], _report["missing_count"],
		_report["ambiguous_count"], _report["invalid_count"], _report["resource_failure_count"],
		_report["collision_body_count"], str(_report["complete"])])
	if is_instance_valid(_house):
		_house.free()
	quit(exit_code)
