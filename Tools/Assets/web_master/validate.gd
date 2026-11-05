extends SceneTree

var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func check(label: String, passed: bool) -> void: checks.append({"label":label,"passed":passed})
func vec(v: Vector3) -> Array: return [v.x,v.y,v.z]
func _run() -> void:
 var packed: PackedScene = load("res://assets/generated/web_master/web_masters.glb")
 check("GLB imports as PackedScene",packed != null)
 if packed == null:
  quit(1)
  return
 var scene: Node3D = packed.instantiate()
 root.add_child(scene)
 check("exactly three semantic roots",scene.get_child_count()==3)
 check("runtime has no studio cameras/lights/collisions",scene.find_children("*","Camera3D",true,false).is_empty() and scene.find_children("*","Light3D",true,false).is_empty() and scene.find_children("*","CollisionObject3D",true,false).is_empty())
 var report: Dictionary = {}
 var total := 0
 var expected: Dictionary = {"WebRadialTorn":4438,"WebSaggingCanopy":10258,"WebFurnitureCocoon":9932}
 for name in expected:
  var variant: Node3D = scene.get_node_or_null(NodePath(name))
  check(name+" exists",variant!=null)
  if variant==null:continue
  check(name+" root transform identity",variant.transform.is_equal_approx(Transform3D.IDENTITY))
  var instances: Array[Node] = variant.find_children("*","MeshInstance3D",true,false)
  check(name+" two mesh draws",instances.size()==2)
  var bound := AABB()
  var started := false
  var triangles := 0
  var finite := true
  var opaque := true
  var rough := true
  for instance: MeshInstance3D in instances:
   var mesh: Mesh=instance.mesh
   var part: AABB=instance.transform*mesh.get_aabb()
   bound=bound.merge(part) if started else part
   started=true
   for s in range(mesh.get_surface_count()):
    var arrays:=mesh.surface_get_arrays(s)
    for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and vertex.is_finite()
    for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:finite=finite and normal.is_finite() and normal.length()>.5
    triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
    var material: StandardMaterial3D=instance.get_active_material(s)
    opaque=opaque and material!=null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a>.99
    rough=rough and material!=null and material.roughness>.8 and material.metallic==0
  check(name+" finite vertices and normals",finite)
  check(name+" opaque silk material",opaque)
  check(name+" rough nonmetal material",rough)
  check(name+" exact authored triangle count",triangles==expected[name])
  var dimensions_ok:=bound.size.x>1 and bound.size.x<3.1
  if name=="WebRadialTorn":dimensions_ok=dimensions_ok and bound.size.y>1.8 and bound.size.z<.3
  if name=="WebSaggingCanopy":dimensions_ok=dimensions_ok and bound.size.z>1.8 and bound.size.y>.4 and bound.size.y<1
  if name=="WebFurnitureCocoon":dimensions_ok=dimensions_ok and bound.size.y>.8 and bound.size.y<1.2 and bound.size.z>.8
  check(name+" metre bounds and forward axes",dimensions_ok)
  report[name]={"bounds_min":vec(bound.position),"size_metres":vec(bound.size),"triangles":triangles,"meshes":instances.size()}
  total+=triangles
 check("set stays below25000 triangles",total<25000)
 var passed:=true
 for c in checks:passed=passed and c.passed
 var output: Dictionary={"passed":passed,"check_count":checks.size(),"checks":checks,"total_triangles":total,"variants":report}
 var file:=FileAccess.open("res://../Tools/Assets/web_master/validation.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(output,"  "));file.close()
 print(JSON.stringify(output))
 scene.free();packed=null
 await process_frame
 quit(0 if passed else 1)
