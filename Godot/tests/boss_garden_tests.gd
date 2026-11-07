extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var garden = load("res://scripts/boss_garden.gd").new()
	root.add_child(garden)
	await physics_frame
	await physics_frame
	var state = garden.get_world_3d().direct_space_state
	var sky = state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,0),Vector3(0,100,0),1))
	var floor_hit = state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,0),Vector3(0,-1,0),1))
	var house = state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,0),Vector3(0,1,20),1))
	var boundary = state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,0),Vector3(20,1,0),1))
	var gate = state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,0),Vector3(0,1,-20),1))
	var ok: bool = sky.is_empty() and not floor_hit.is_empty() and not house.is_empty() and not boundary.is_empty() and not gate.is_empty()
	print("GARDEN_CHECKS open_sky=",sky.is_empty()," floor=",not floor_hit.is_empty()," house=",not house.is_empty()," wall=",not boundary.is_empty()," gate=",not gate.is_empty())
	garden.free()
	quit(0 if ok else 1)
