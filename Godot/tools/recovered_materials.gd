extends RefCounted
## Bounded adapter for recovered CUE material JSON and raw UE parameter exports.
## Applies only named primary channels. This does not reconstruct Unreal graphs.

const BASE_TEXTURES := ["Basecolor", "BaseColorTexture", "Basecolor_Opacity(Alpha)", "Albedo", "AlbedoTexture", "Diffuse", "DiffuseTexture", "01.Texture", "Texture", "PM_Diffuse"]
const NORMAL_TEXTURES := ["Normal", "Normals", "NormalTexture", "NormalMap", "12.Normal", "PM_Normals"]
const BASE_COLORS := ["BaseColor", "AlbedoColor", "DiffuseColor", "TintColor", "Tint", "Color", "Lace_Color"]
const UV_SCALES := ["UVScale", "UVTiling", "Tiling", "TilingAmount", "05.Scale"]

var _root: String
var _models: Dictionary = {}
var _textures: Dictionary = {}
var _layouts: Dictionary = {}
var _slot_layouts: Dictionary = {}
var _prepared: Dictionary = {}
var _catalog: Dictionary = {}
var _applied_surfaces := 0
var _missing: Array = []
var _mapping_failures: Array = []


func _init(asset_root: String = "res://assets/recovered") -> void:
	_root = asset_root.trim_suffix("/")


func apply_overrides(meshes: Array[MeshInstance3D], glb_path: String, references: Array, component_name: String) -> Dictionary:
	var result := {"applied": [], "missing": [], "surface_mapping": "GLB primitive -> verified UE LOD0 source section slot -> runtime override"}
	if references.is_empty():
		return result
	var layout: Dictionary = _glb_layout(glb_path)
	if layout.has("error"):
		_mapping_failure(result, component_name, glb_path, str(layout["error"]))
		return result
	var source_meshes: Array = layout["meshes"]
	for mesh_instance in meshes:
		var candidates: Array = []
		for source_mesh in source_meshes:
			if source_meshes.size() == 1 or str(source_mesh.get("name", "")) == mesh_instance.mesh.resource_name:
				candidates.append(source_mesh)
		if candidates.size() != 1:
			_mapping_failure(result, component_name, glb_path, "Could not uniquely match the imported mesh to the GLB mesh list.")
			continue
		var primitives: Array = candidates[0].get("primitives", [])
		var surfaces: int = mesh_instance.mesh.get_surface_count()
		if surfaces != primitives.size():
			_mapping_failure(result, component_name, glb_path, "Slot counts disagree: UE=%d, GLB=%d, Godot=%d. Defaults retained." % [references.size(), primitives.size(), surfaces])
			continue
		var slots: Dictionary = _source_slots(glb_path, candidates[0], layout, references.size())
		if slots.has("error"):
			_mapping_failure(result, component_name, glb_path, str(slots["error"]))
			continue
		if mesh_instance.material_override != null:
			_mapping_failure(result, component_name, glb_path, "Mesh has a whole-mesh override; per-surface overrides would be hidden.")
			continue
		for surface in range(surfaces):
			var ue_slot: int = int(slots["indices"][surface])
			var source: String = _object_path(references[ue_slot])
			if source.is_empty():
				continue # A null UE override keeps the mesh's original material.
			var existing: Material = mesh_instance.get_active_material(surface)
			var built: Dictionary = _prepare(source, existing)
			if not built.has("material"):
				var missing := {"component": component_name, "surface": surface, "source": source, "reason": built.get("error", "No supported properties were recovered.")}
				result["missing"].append(missing)
				_missing.append(missing)
				continue
			# Each component receives its own material; source GLBs and cached resources
			# are never mutated. Textures remain shared, immutable imported resources.
			var override_material: Material = (built["material"] as Material).duplicate(false)
			override_material.resource_local_to_scene = true
			mesh_instance.set_surface_override_material(surface, override_material)
			_applied_surfaces += 1
			result["applied"].append({"surface": surface, "ue_slot": ue_slot, "source": source, "fields": built["fields"], "glb_default_material_index": primitives[surface].get("material", -1), "mapping_evidence": slots["evidence"]})
	return result


func get_report() -> Dictionary:
	var missing_texture_count := 0
	var missing_channel_count := 0
	for material in _catalog.values():
		missing_texture_count += material.get("missing_textures", []).size()
		missing_channel_count += material.get("missing_channels", []).size()
	return {"policy": "Exact original LOD0 section MaterialIndex verified against GLB names and triangle counts, cloned StandardMaterial3D overrides, named primary channels and documented glass/fabric/foliage visual approximations; original shader graph fidelity is partial.", "applied_surface_count": _applied_surfaces, "missing_surface_count": _missing.size(), "missing_surfaces": _missing, "surface_mapping_failures": _mapping_failures, "missing_texture_count": missing_texture_count, "missing_primary_channel_count": missing_channel_count, "override_coverage_complete": _missing.is_empty() and _mapping_failures.is_empty() and missing_texture_count == 0 and missing_channel_count == 0, "material_catalog": _catalog.values(), "normal_convention": "Standalone CUE PNGs are DirectX Y-. Require exactly one green inversion in PNG import (legacy invert=true with green=1, or invert=false with green=5). Embedded GLB normals were already converted by CUE and are not changed.", "visual_validation_required": true}


func _mapping_failure(result: Dictionary, component: String, asset: String, reason: String) -> void:
	var entry := {"component": component, "asset": asset, "reason": reason}
	_mapping_failures.append(entry)
	result["missing"].append(entry)


func _object_path(value: Variant) -> String:
	var text: String = str(value.get("ObjectPath", value.get("AssetPathName", ""))) if value is Dictionary else str(value)
	text = text.strip_edges().replace("\\", "/")
	var start: int = text.find("/Game/")
	if start < 0:
		start = text.find("/Engine/")
	if start < 0:
		return ""
	text = text.substr(start).trim_suffix("'").trim_suffix("\"")
	var separator: int = text.find(".")
	if separator >= 0:
		text = text.substr(0, separator)
	if text.contains("..") or text.contains(":"):
		return ""
	return text


func _relative_asset(source: String) -> String:
	if source.begins_with("/Game/"):
		return "Arachnophobia/Content/" + source.substr(6)
	if source.begins_with("/Engine/"):
		return "Engine/Content/" + source.substr(8)
	return ""


func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return null
	return parser.data


func _load_model(source: String, ancestors: Array = []) -> Dictionary:
	if _models.has(source):
		return _models[source]
	if ancestors.has(source) or ancestors.size() >= 16:
		return {"error": "Cyclic or excessively deep material inheritance."}
	var relative: String = _relative_asset(source)
	var resolved_path: String = _root.path_join(relative + ".json")
	var raw_path: String = _root.path_join("Metadata/" + relative + ".uasset.json")
	var resolved: Variant = _read_json(resolved_path)
	var exports: Variant = _read_json(raw_path)
	var raw: Dictionary = {}
	var cached: Dictionary = {}
	if exports is Array:
		for entry in exports:
			if entry is Dictionary and str(entry.get("Name", "")) == source.get_file() and str(entry.get("Type", "")).begins_with("Material"):
				raw = entry.get("Properties", {})
				cached = entry.get("CachedExpressionData", {})
	if not resolved is Dictionary and raw.is_empty() and cached.is_empty():
		var failure := {"error": "Recovered material JSON is missing or unreadable.", "expected": [resolved_path, raw_path]}
		_models[source] = failure
		return failure
	var model := {"Textures": {}, "Colors": {}, "Scalars": {}, "Switches": {}, "Properties": {}, "ReferencedTextures": [], "sources": [], "warnings": []}
	var parent: String = _object_path(raw.get("Parent", ""))
	if not parent.is_empty() and not resolved is Dictionary:
		var chain: Array = ancestors.duplicate()
		chain.append(source)
		var inherited: Dictionary = _load_model(parent, chain)
		if not inherited.has("error"):
			model = inherited.duplicate(true)
		else:
			model["warnings"].append("Parent parameters unavailable: " + parent + "; unspecified channels preserve the GLB default.")
	# In the recovered UE 5.3 master materials, default parameter names and values
	# are parallel arrays in CachedExpressionData, outside Properties.
	for mapping in [["RuntimeEntries", "ScalarValues", "Scalars"], ["RuntimeEntries[1]", "VectorValues", "Colors"], ["RuntimeEntries[3]", "TextureValues", "Textures"], ["RuntimeEntries[7]", "StaticSwitchValues", "Switches"]]:
		var info: Array = cached.get(mapping[0], {}).get("ParameterInfoSet", [])
		var values: Array = cached.get(mapping[1], [])
		if info.size() != values.size():
			model["warnings"].append("Master default parameter count mismatch for " + str(mapping[1]) + "; those defaults were omitted.")
			continue
		for index in range(info.size()):
			if info[index] is Dictionary and str(info[index].get("Association", "GlobalParameter")).ends_with("GlobalParameter"):
				model[mapping[2]][str(info[index].get("Name", ""))] = values[index]
	if resolved is Dictionary:
		for kind in ["Textures", "Colors", "Scalars", "Switches", "Properties"]:
			if resolved.get(kind) is Dictionary:
				model[kind].merge(resolved[kind], true)
		model["sources"].append(resolved_path)
	if not raw.is_empty() or not cached.is_empty():
		model["sources"].append(raw_path)
		model["Properties"].merge(raw, true)
		for pair in [["TextureParameterValues", "Textures"], ["ScalarParameterValues", "Scalars"], ["VectorParameterValues", "Colors"]]:
			for parameter in raw.get(pair[0], []):
				if not parameter is Dictionary or not parameter.get("ParameterInfo") is Dictionary:
					continue
				var info: Dictionary = parameter["ParameterInfo"]
				var name: String = str(info.get("Name", ""))
				if not str(info.get("Association", "GlobalParameter")).ends_with("GlobalParameter"):
					model["warnings"].append("Layer-associated parameter omitted: " + name)
					continue
				if not name.is_empty():
					model[pair[1]][name] = parameter.get("ParameterValue")
		for texture in cached.get("ReferencedTextures", []):
			if not model["ReferencedTextures"].has(texture):
				model["ReferencedTextures"].append(texture)
	_apply_recovered_aliases(source, model)
	_models[source] = model
	return model


func _apply_recovered_aliases(source: String, model: Dictionary) -> void:
	# These exact cooked masters have no parameter names. The referenced texture
	# asset names document their channels; their unavailable graph is not recreated.
	var aliases: Dictionary = {}
	match source:
		"/Game/OldBrickHouse/Materials/Masters/M_Glass_01":
			aliases = {"T_Glass_01_BCO": "Basecolor_Opacity(Alpha)"}
		"/Game/OldBrickHouse/Materials/Masters/M_GlassJars":
			aliases = {"T_GlassJars_BCO": "Basecolor_Opacity(Alpha)", "T_GlassJars_N": "Normal"}
		"/Game/OldBrickHouse/Materials/Masters/M_Plants":
			aliases = {"T_Plants_BCO": "Basecolor_Opacity(Alpha)", "T_Plants_N": "Normal", "T_Plants_R": "Roughness"}
	for texture in model["ReferencedTextures"]:
		var texture_path: String = _object_path(texture)
		if aliases.has(texture_path.get_file()):
			var alias: String = str(aliases[texture_path.get_file()])
			model["Textures"][alias] = texture
			model["warnings"].append("Unparameterized source reference " + texture_path.get_file() + " mapped to " + alias + "; BCO alpha/shading behavior is a documented visual approximation.")
	# Fabric's named Mask is an exported lace BCO/BC texture. Preserve its tint and
	# alpha with a documented approximation of the unavailable fabric graph.
	if model["Colors"].has("Lace_Color") and model["Textures"].has("Mask"):
		model["Textures"]["Basecolor_Opacity(Alpha)"] = model["Textures"]["Mask"]
		model["warnings"].append("Fabric Mask mapped to albedo/alpha with Lace_Color tint; original translucency, cloth, refraction and mask arithmetic are approximated.")


func _key(values: Dictionary, names: Array) -> String:
	for wanted in names:
		for candidate in values:
			if str(candidate).to_lower() == str(wanted).to_lower():
				return str(candidate)
	return ""


func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _texture(value: Variant, audit: Dictionary, parameter: String) -> Texture2D:
	var source: String = _object_path(value)
	if source.is_empty():
		audit["missing_textures"].append({"parameter": parameter, "reason": "Null or invalid texture reference."})
		return null
	if _textures.has(source):
		return _textures[source]
	var base: String = _root.path_join(_relative_asset(source))
	for extension in ["png", "tga", "webp", "jpg", "jpeg"]:
		var file_path: String = base + "." + extension
		if FileAccess.file_exists(file_path) and ResourceLoader.exists(file_path):
			var loaded: Resource = ResourceLoader.load(file_path)
			if loaded is Texture2D:
				_textures[source] = loaded
				return loaded
	# Do not cache failures: an asset export may finish before the next component.
	var entry := {"parameter": parameter, "source": source, "reason": "Texture export is missing or has not been imported by Godot."}
	if not audit["missing_textures"].has(entry):
		audit["missing_textures"].append(entry)
	return null


func _prepare(source: String, existing: Material) -> Dictionary:
	var cache_key: String = source + ":" + str(existing.get_instance_id() if existing != null else 0)
	if _prepared.has(cache_key):
		return _prepared[cache_key]
	var model: Dictionary = _load_model(source)
	var audit := {"source": source, "sources": model.get("sources", []), "applied_parameters": [], "unmapped_parameters": [], "missing_textures": [], "missing_channels": [], "approximations": model.get("warnings", []).duplicate(), "fields": []}
	_catalog[source] = audit
	if model.has("error"):
		audit["error"] = model["error"]
		return {"error": model["error"]}
	var material: StandardMaterial3D
	if existing is StandardMaterial3D:
		material = existing.duplicate(false) as StandardMaterial3D
	elif existing == null:
		material = StandardMaterial3D.new()
	else:
		audit["error"] = "Existing material is not StandardMaterial3D; default preserved."
		return {"error": audit["error"]}
	material.resource_name = source.get_file() + "_RecoveredOverride"
	var textures: Dictionary = model["Textures"]
	var scalars: Dictionary = model["Scalars"]
	var colors: Dictionary = model["Colors"]
	var used: Dictionary = {}
	for channel in ["albedo", "normal"]:
		var parameter: String = _key(textures, BASE_TEXTURES if channel == "albedo" else NORMAL_TEXTURES)
		if parameter.is_empty():
			continue
		var texture: Texture2D = _texture(textures[parameter], audit, parameter)
		if texture == null:
			continue
		if channel == "albedo":
			material.albedo_texture = texture
			# A tint from a different default material must not recolor this texture.
			material.albedo_color = Color.WHITE
		else:
			var settings := ConfigFile.new()
			var normal_import: String = texture.resource_path + ".import"
			var settings_result: Error = settings.load(normal_import)
			var legacy_flip: bool = bool(settings.get_value("params", "process/normal_map_invert_y", false))
			var green_remap: int = int(settings.get_value("params", "process/channel_remap/green", 1))
			var converted_once: bool = (legacy_flip and green_remap == 1) or (not legacy_flip and green_remap == 5)
			if settings_result != OK or not converted_once:
				audit["missing_textures"].append({"parameter": parameter, "source": _object_path(textures[parameter]), "reason": "DirectX normal PNG import has not been configured with a single green-channel inversion. Run prepare_normal_imports.mjs and reimport."})
				continue
			material.normal_enabled = true
			material.normal_texture = texture
			material.normal_scale = 1.0
			audit["normal_convention"] = {"source": "DirectX Y- PNG", "target": "Godot OpenGL Y+", "conversion": "One green-channel inversion during Godot import", "process/normal_map_invert_y": legacy_flip, "process/channel_remap/green": green_remap, "settings": normal_import}
			audit["approximations"].append("Primary normal map assigned with corrected green channel; original normal-strength and detail blending require visual validation.")
		_mark(audit, used, "Textures", parameter, channel + "_texture")
	var packed: String = _key(textures, ["AO/Rough/Met", "ARM", "ORM", "OcclusionRoughnessMetallic"])
	if not packed.is_empty():
		var packed_texture: Texture2D = _texture(textures[packed], audit, packed)
		if packed_texture != null:
			material.ao_enabled = true
			material.ao_texture = packed_texture
			material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.roughness_texture = packed_texture
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			material.roughness = 1.0
			material.metallic_texture = packed_texture
			material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			material.metallic = 1.0
			_mark(audit, used, "Textures", packed, "AO(R), roughness(G), metallic(B)")
	for channel in ["roughness", "metallic"]:
		var texture_names: Array = ["Roughness(G)", "Roughness", "RoughnessTexture"] if channel == "roughness" else ["Metallic", "MetallicTexture", "Metalness"]
		var parameter: String = _key(textures, texture_names)
		if not parameter.is_empty():
			var texture: Texture2D = _texture(textures[parameter], audit, parameter)
			if texture != null:
				material.set(channel + "_texture", texture)
				material.set(channel + "_texture_channel", BaseMaterial3D.TEXTURE_CHANNEL_GREEN if parameter.to_lower() == "roughness(g)" else BaseMaterial3D.TEXTURE_CHANNEL_RED)
				material.set(channel, 1.0)
				_mark(audit, used, "Textures", parameter, channel + "_texture")
		var scalar: String = _key(scalars, ["Roughness"] if channel == "roughness" else ["Metallic", "Metalness"])
		if not scalar.is_empty() and _number(scalars[scalar]) and float(scalars[scalar]) >= 0.0 and float(scalars[scalar]) <= 1.0:
			material.set(channel, float(scalars[scalar]))
			_mark(audit, used, "Scalars", scalar, channel)
	var color_key: String = _key(colors, BASE_COLORS)
	if not color_key.is_empty() and colors[color_key] is Dictionary:
		var value: Dictionary = colors[color_key]
		if _number(value.get("R")) and _number(value.get("G")) and _number(value.get("B")):
			# Exported R/G/B are FLinearColor, while Godot's material color is sRGB.
			material.albedo_color = Color(float(value["R"]), float(value["G"]), float(value["B"]), 1.0).linear_to_srgb()
			_mark(audit, used, "Colors", color_key, "albedo_color")
			audit["approximations"].append("Named base tint applied as a uniform multiplier; original material graph may modulate it.")
	var scale_key: String = _key(scalars, UV_SCALES)
	if not scale_key.is_empty() and _number(scalars[scale_key]) and float(scalars[scale_key]) > 0.0:
		var uv_scale: float = float(scalars[scale_key])
		material.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
		_mark(audit, used, "Scalars", scale_key, "uv1_scale")
		audit["approximations"].append("Primary UV scale shared by mapped channels; per-layer UV rotation, secondary scales, and world-aligned projection are not reconstructed.")
	var properties: Dictionary = model["Properties"]
	var overrides: Dictionary = properties.get("BasePropertyOverrides", {})
	var blend_mode: String = str(overrides.get("BlendMode", properties.get("BlendMode", "")))
	if overrides.get("bOverride_TwoSided", false) or properties.has("TwoSided"):
		var two_sided: bool = bool(overrides.get("TwoSided", properties.get("TwoSided", false)))
		material.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
		audit["fields"].append("cull_mode")
	var opacity_texture: String = _key(textures, ["Basecolor_Opacity(Alpha)"])
	if not opacity_texture.is_empty() and used.has("Textures:" + opacity_texture):
		if blend_mode.ends_with("BLEND_Translucent"):
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			audit["fields"].append("albedo_alpha_translucency")
			audit["approximations"].append("Source BLEND_Translucent uses the BCO alpha channel with Godot alpha blending; Unreal refraction, transmission and cloth lighting are not reconstructed.")
		else:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			var threshold: Variant = overrides.get("OpacityMaskClipValue", properties.get("OpacityMaskClipValue", 0.3333))
			if _number(threshold):
				material.alpha_scissor_threshold = clampf(float(threshold), 0.0, 1.0)
			audit["fields"].append("albedo_alpha_cutout")
			audit["approximations"].append("Explicit Basecolor_Opacity(Alpha) texture uses alpha cutout; foliage subsurface and wind are not reconstructed.")
	if source in ["/Game/OldBrickHouse/Materials/Masters/M_Glass_01", "/Game/OldBrickHouse/Materials/Masters/M_GlassJars"]:
		# The cooked glass metadata contains its blend mode and textures, but no
		# graph constants/channel connections. These values are visual estimates.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.14
		material.metallic = 0.0
		material.albedo_color.a = 0.35
		audit["fields"].append("glass_visual_approximation")
		audit["approximations"].append("Glass visual estimate: dielectric metallic=0, roughness=0.14, BCO alpha multiplied by 0.35. Only source translucency and referenced BCO are recovered; these constants are chosen for readable glass and are not source shader values. MTRAO channels remain unassigned because cooked metadata has no graph connections.")
	if colors.has("Lace_Color") and scalars.has("Transparency_Multiplier") and _number(scalars["Transparency_Multiplier"]):
		material.albedo_color.a = clampf(float(scalars["Transparency_Multiplier"]), 0.0, 1.0)
		_mark(audit, used, "Scalars", "Transparency_Multiplier", "fabric_alpha_multiplier")
		audit["approximations"].append("Source Transparency_Multiplier applied directly to BCO alpha and clamped to 0..1; unavailable fabric graph may combine this parameter differently.")
	_apply_house_art_adaptation(source, material, model, audit, used)
	for kind in ["Textures", "Scalars", "Colors", "Switches"]:
		for parameter in model[kind]:
			if used.has(kind + ":" + str(parameter)):
				continue
			# Resolved material files include texture-asset-name aliases; exclude aliases
			# from unsupported-parameter diagnostics if the same texture was applied.
			if kind == "Textures" and _texture_is_used(model[kind][parameter], textures, used):
				continue
			audit["unmapped_parameters"].append(kind + ":" + str(parameter))
	if not audit["unmapped_parameters"].is_empty():
		audit["approximations"].append("Unmapped shader parameters retain the GLB default behavior; layered dirt, masks, unknown packed channels (including MTRAO), wind, parallax, and emissive switches are not guessed.")
	if material.albedo_texture == null and not audit["fields"].has("albedo_color"):
		audit["missing_channels"].append("No primary base-color texture or named uniform color was recovered; source geometry default remains.")
	if audit["fields"].is_empty():
		return {"error": "Material was found but no supported primary channel could be applied."}
	var result := {"material": material, "fields": audit["fields"]}
	_prepared[cache_key] = result
	return result


func _apply_house_art_adaptation(source: String, material: StandardMaterial3D, model: Dictionary, audit: Dictionary, used: Dictionary) -> void:
	# Explicit art direction after source-channel recovery, not recovered shader
	# constants. Original wall UVs measure approximately one unit per metre.
	if source == "/Game/VHExterior/Materials/Instance/Tiling/Inst_Brick_01":
		var previous_uv := material.uv1_scale
		material.uv1_scale = Vector3(1.0, 1.5, 1.0)
		material.normal_scale = 0.35
		material.roughness = 0.92
		material.metallic = 0.0
		material.metallic_specular = 0.25
		audit["art_adaptation"] = {"kind": "physically plausible brick scale", "source_uv_scale": [previous_uv.x, previous_uv.y], "final_uv_scale": [1.0, 1.5], "nominal_brick_course_metres": [0.20, 0.067], "normal_strength": 0.35, "roughness": 0.92, "dielectric_specular": 0.25}
		audit["fields"].append("brick_art_adaptation")
		audit["approximations"].append("Art adaptation: the source brick atlas has about five bricks across and ten courses high; original wall UVs are about one unit/metre. UV=(1,1.5) yields approximately 0.20m by 0.067m courses. Normal=0.35, roughness=0.92 and specular=0.25 soften exaggerated relief/highlights. These values replace the source scalar approximation and are not recovered shader arithmetic.")
	elif source == "/Game/VHExterior/Materials/Instance/Tiling/Inst_Concrete_01":
		var previous_uv := material.uv1_scale
		material.uv1_scale = Vector3.ONE
		material.normal_scale = 0.12
		material.roughness = 0.95
		material.metallic = 0.0
		material.metallic_specular = 0.20
		var tint_key := "02.Color Base (alpha channel)"
		var source_tint: Variant = model["Colors"].get(tint_key)
		if source_tint is Dictionary and _number(source_tint.get("R")) and _number(source_tint.get("G")) and _number(source_tint.get("B")):
			var linear_tint := Color(float(source_tint["R"]), float(source_tint["G"]), float(source_tint["B"]), 1.0)
			material.albedo_color = linear_tint.lerp(Color.WHITE, 0.30).linear_to_srgb()
			_mark(audit, used, "Colors", tint_key, "albedo_color")
		audit["art_adaptation"] = {"kind": "aged plaster", "source_uv_scale": [previous_uv.x, previous_uv.y], "final_uv_scale": [1.0, 1.0], "normal_strength": 0.12, "roughness": 0.95, "dielectric_specular": 0.20, "tint_policy": "Source linear warm base tint blended 30 percent toward white, then applied uniformly in sRGB."}
		audit["fields"].append("plaster_art_adaptation")
		audit["approximations"].append("Art adaptation: UV=(1,1) produces fine plaster grain; normal=0.12, roughness=0.95 and specular=0.20 avoid the broad noisy relief seen in the preview. Source warm base tint is blended 30 percent toward white and applied uniformly. The original alpha-controlled tint function is unavailable; this is an authored plaster approximation, not an exact graph reconstruction.")


func _mark(audit: Dictionary, used: Dictionary, kind: String, parameter: String, field: String) -> void:
	used[kind + ":" + parameter] = true
	audit["applied_parameters"].append(kind + ":" + parameter)
	audit["fields"].append(field)


func _texture_is_used(value: Variant, textures: Dictionary, used: Dictionary) -> bool:
	var source: String = _object_path(value)
	for parameter in textures:
		if used.has("Textures:" + str(parameter)) and _object_path(textures[parameter]) == source:
			return true
	return false


func _glb_layout(file_path: String) -> Dictionary:
	if _layouts.has(file_path):
		return _layouts[file_path]
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() < 20:
		return {"error": "GLB header could not be read."}
	if file.get_32() != 0x46546c67 or file.get_32() != 2:
		return {"error": "Expected GLB version 2."}
	var length: int = file.get_32()
	var json_length: int = file.get_32()
	if length != file.get_length() or json_length <= 0 or json_length > length - 20 or file.get_32() != 0x4e4f534a:
		return {"error": "Invalid GLB JSON chunk."}
	var parser := JSON.new()
	if parser.parse(file.get_buffer(json_length).get_string_from_utf8()) != OK or not parser.data is Dictionary or not parser.data.get("meshes") is Array:
		return {"error": "GLB mesh metadata could not be parsed."}
	var layout := {"meshes": parser.data["meshes"], "materials": parser.data.get("materials", []), "accessors": parser.data.get("accessors", [])}
	_layouts[file_path] = layout
	return layout


func _source_slots(file_path: String, mesh: Dictionary, layout: Dictionary, runtime_count: int) -> Dictionary:
	var cache_key: String = file_path + ":" + str(mesh.get("name", "")) + ":" + str(runtime_count)
	if _slot_layouts.has(cache_key):
		return _slot_layouts[cache_key]
	var primitives: Array = mesh.get("primitives", [])
	var relative: String = file_path.trim_prefix(_root + "/").trim_prefix("Geometry/").get_basename()
	var metadata: Variant = null
	var metadata_path := ""
	for prefix in ["Geometry/Metadata/", "Metadata/"]:
		metadata_path = _root.path_join(prefix + relative + ".uasset.json")
		metadata = _read_json(metadata_path)
		if metadata is Array:
			break
	if not metadata is Array:
		return {"error": "Surface mapping requires original StaticMesh LOD0 metadata; it is unavailable."}
	var source: Dictionary = {}
	for entry in metadata:
		if entry is Dictionary and str(entry.get("Type", "")) == "StaticMesh" and str(entry.get("Name", "")) == file_path.get_file().get_basename():
			source = entry
	var source_materials: Array = source.get("Properties", {}).get("StaticMaterials", [])
	var lods: Array = source.get("RenderData", {}).get("LODs", [])
	if lods.is_empty() or source_materials.size() != runtime_count:
		return {"error": "Original source material count/LOD0 metadata could not validate runtime slots."}
	var sections: Array = lods[0].get("Sections", [])
	# Pinned CUE Gltf.ExportMeshSections emits source sections in order. In the
	# geometry-only export, GltfMaterialExporter.Build creates a new material per
	# section (no material cache), so repeated source materials remain distinct.
	# Check names AND index counts before using that ordered section identity.
	# UE StaticMaterials order is independent, even when slot counts are equal.
	var ordered: Array = []
	var ordered_valid: bool = file_path.begins_with(_root + "/Geometry/") and sections.size() == primitives.size()
	if ordered_valid:
		for index in range(primitives.size()):
			var primitive: Dictionary = primitives[index]
			var section: Dictionary = sections[index]
			var slot: int = int(section.get("MaterialIndex", -1))
			var material_index: int = int(primitive.get("material", -1))
			var accessor_index: int = int(primitive.get("indices", -1))
			if slot < 0 or slot >= runtime_count or material_index < 0 or material_index >= layout["materials"].size() or accessor_index < 0 or accessor_index >= layout["accessors"].size() or int(primitive.get("mode", 4)) != 4:
				ordered_valid = false
				break
			var source_name: String = _object_path(source_materials[slot].get("MaterialInterface", "")).get_file()
			if source_name != str(layout["materials"][material_index].get("name", "")) or int(section.get("NumTriangles", -1)) * 3 != int(layout["accessors"][accessor_index].get("count", 0)):
				ordered_valid = false
				break
			ordered.append(slot)
	if ordered_valid:
		var ordered_result := {"indices": ordered, "evidence": "Geometry-only CUE emits LOD0 sections in order with a distinct material per section; every default material name and triangle count verified. Uses original section MaterialIndex, never surface index. Source: " + metadata_path}
		_slot_layouts[cache_key] = ordered_result
		return ordered_result
	var mapped: Array = []
	for primitive in primitives:
		var material_index: int = int(primitive.get("material", -1))
		var accessor_index: int = int(primitive.get("indices", -1))
		if material_index < 0 or material_index >= layout["materials"].size() or accessor_index < 0 or accessor_index >= layout["accessors"].size() or int(primitive.get("mode", 4)) != 4:
			return {"error": "GLB primitive material/index metadata is invalid for source-slot verification."}
		var material_name: String = str(layout["materials"][material_index].get("name", ""))
		var index_count: int = int(layout["accessors"][accessor_index].get("count", 0))
		var matches: Array = []
		for section in sections:
			var slot: int = int(section.get("MaterialIndex", -1))
			if slot < 0 or slot >= runtime_count:
				continue
			var source_name: String = _object_path(source_materials[slot].get("MaterialInterface", "")).get_file()
			if source_name == material_name and int(section.get("NumTriangles", -1)) * 3 == index_count and not matches.has(slot):
				matches.append(slot)
		if matches.size() != 1:
			return {"error": "No unique LOD0 section matches GLB material '%s' and index count %d; runtime override omitted." % [material_name, index_count]}
		mapped.append(matches[0])
	var result := {"indices": mapped, "evidence": "Exact original LOD0 MaterialIndex matched by default material name AND triangle count; unused lower-LOD slots excluded. Source: " + metadata_path}
	_slot_layouts[cache_key] = result
	return result
