extends SceneTree
const Models = preload("res://scripts/supply_models.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func _check(label: String, ok: bool) -> void: checks.append({"label":label,"passed":ok})
func _run() -> void:
 var totals := 0
 var report := {}
 for name in ["BatteryCell","BandagePack","FlareStick","BandageRoll"]:
  var variant := Models.make_variant(name)
  _check(name+" shared factory returns model",variant != null)
  if variant == null: continue
  _check(name+" centre transform reset",variant.transform.is_equal_approx(Transform3D.IDENTITY))
  root.add_child(variant)
  var bound := AABB()
  var started := false
  var triangles := 0
  var materials := []
  var good_arrays := true
  for instance in variant.find_children("*","MeshInstance3D",true,false):
   var mesh: Mesh = instance.mesh
   var part_bound: AABB = instance.transform * mesh.get_aabb()
   bound = bound.merge(part_bound) if started else part_bound
   started = true
   for s in range(mesh.get_surface_count()):
    var arrays := mesh.surface_get_arrays(s)
    for vertex in arrays[Mesh.ARRAY_VERTEX]: good_arrays = good_arrays and vertex.is_finite()
    for normal in arrays[Mesh.ARRAY_NORMAL]: good_arrays = good_arrays and normal.is_finite()
    var material: Material = instance.get_active_material(s)
    materials.append(material.resource_name)
    triangles += arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
    if material.resource_name in Models.LABEL_OFFSETS:
     _check(name+" label atlas crop on "+material.resource_name, material.albedo_texture != null and material.uv1_scale == Vector3(.5,.5,1) and material.uv1_offset == Models.LABEL_OFFSETS[material.resource_name])
     _check(name+" label UV survives export",arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size())
  _check(name+" finite geometry",good_arrays)
  _check(name+" no studio camera or lights",variant.find_children("*","Camera3D",true,false).is_empty() and variant.find_children("*","Light3D",true,false).is_empty())
  var target: Vector3 = {"BatteryCell":Vector3(.0145,.05055,.0145),"BandagePack":Vector3(.114,.026,.072),"FlareStick":Vector3(.0274,.1904,.0274),"BandageRoll":Vector3(.05574,.0454,.0454)}[name]
  _check(name+" authored dimensions in metres",bound.size.distance_to(target)<.002)
  report[name]={"bounds_min":str(bound.position),"size_metres":str(bound.size),"triangles":triangles,"materials":materials}
  totals += triangles
  variant.queue_free()
 _check("kit below12000 triangles",totals<12000)
 _check("invalid variant fails safely",Models.make_variant("Missing")==null)
 var success := true
 for c in checks: success = success and c.passed
 var output := {"passed":success,"checks":checks,"total_triangles":totals,"variants":report}
 var file:=FileAccess.open("res://../Tools/Assets/supply_validation.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(output,"  "))
 print(JSON.stringify(output))
 await process_frame
 quit(0 if success else 1)
