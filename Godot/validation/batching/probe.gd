extends SceneTree
func _initialize() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	var expected := Transform3D(Basis.IDENTITY, Vector3(2, 3, 4))
	mm.set_instance_transform(0, expected)
	print("BACKEND=", DisplayServer.get_name(), " EXPECTED=", expected, " ACTUAL=", mm.get_instance_transform(0))
	quit()
