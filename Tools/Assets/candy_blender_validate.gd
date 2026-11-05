extends SceneTree
var checks: Array[Dictionary] = []
func _initialize() -> void:
 call_deferred("_run")
func _check(label: String, passed: bool) -> void:
 checks.append({"label":label,"passed":passed})
func _run() -> void:
 var doc := GLTFDocument.new()
 var state := GLTFState.new()
 var err := doc.append_from_file(ProjectSettings.globalize_path("res://assets/generated/candy_blender/candy_variants.glb"), state)
 _check("GLB loads through Godot GLTFDocument", err == OK)
 if err != OK:
  quit(1)
  return
 var scene := doc.generate_scene(state)
 root.add_child(scene)
 var variants := {}
 for variant_name in ["CandyReady", "CandyBitten"]:
  var variant := scene.find_child(variant_name,true,false) as Node3D
  _check(variant_name+" root exists", variant != null)
  if variant == null: continue
  var combined := AABB()
  var have_bound := false
  var triangles := 0
  var parts := []
  var positions_finite := true
  var normals_finite := true
  var uv_present := true
  for mesh_instance in variant.find_children("*","MeshInstance3D",true,false):
   var mesh: Mesh = mesh_instance.mesh
   var bound: AABB = mesh_instance.transform * mesh.get_aabb()
   combined = combined.merge(bound) if have_bound else bound
   have_bound = true
   for surface in range(mesh.get_surface_count()):
    var arrays := mesh.surface_get_arrays(surface)
    for vertex in arrays[Mesh.ARRAY_VERTEX]:
     positions_finite = positions_finite and vertex.is_finite()
    for normal in arrays[Mesh.ARRAY_NORMAL]:
     normals_finite = normals_finite and normal.is_finite() and normal.length_squared() > 0.5
    uv_present = uv_present and arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size()
    triangles += arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size() / 3
    var mat := mesh.surface_get_material(surface)
    parts.append({"mesh":mesh_instance.name,"material":mat.resource_name,"vertices":arrays[Mesh.ARRAY_VERTEX].size()})
  _check(variant_name+" finite geometry and normals", positions_finite and normals_finite)
  _check(variant_name+" UV coordinates survive export",uv_present)
  _check(variant_name+" real hand-held dimensions",combined.size.x > 0.14 and combined.size.x < 0.17 and combined.size.y > 0.015 and combined.size.y < 0.04 and combined.size.z > 0.05 and combined.size.z < 0.08)
  _check(variant_name+" three material meshes",parts.size()==3)
  _check(variant_name+" under 5000 triangles",triangles < 5000)
  variants[variant_name]={"root_position":variant.position,"aabb_position":combined.position,"size_metres":combined.size,"triangles":triangles,"parts":parts}
 var success := true
 for check in checks: success = success and check.passed
 var report := {"checks":checks,"passed":success,"variants":variants,"notes":"Visual bite silhouette and wrapper geometry reviewed in native Godot render; gameplay attachment belongs to player integration."}
 var out := FileAccess.open(ProjectSettings.globalize_path("res://../Tools/Assets/candy_blender_validation.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 scene.queue_free()
 await process_frame
 quit(0 if success else 1)

