extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures.append(label); push_error(label)
func _initialize(): run.call_deferred()
func run():
	var actor=load("res://scenes/luke.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
	var motion=load("res://scripts/pinoc_motion.gd").new()
	motion.bind(rig)
	check(motion.clips.size()==5,"Five provider motions load")
	var hip=rig.find_bone("Bip01 Pelvis")
	var foot=rig.find_bone("Bip01 L Foot")
	var hand=rig.find_bone("Bip01 R Hand")
	var base_hip: Vector3=rig.to_global(rig.get_bone_global_pose(hip).origin)
	var base_foot: Vector3=rig.to_global(rig.get_bone_global_pose(foot).origin)
	for name in motion.clips:
		var valid=true
		for sample in motion.clips[name].samples:
			for q in sample.q:
				if q.any(func(v):return not is_finite(float(v))): valid=false
		check(valid,"Finite motion data: "+name)
	motion.apply_clip("Crouching_Idle",1,1,false,true)
	check(rig.to_global(rig.get_bone_global_pose(hip).origin).y<base_hip.y-.3,"Imported crouch lowers actual pelvis")
	motion.clear_overrides()
	motion.apply_clip("Jump",1.05,1,false,false)
	check(rig.to_global(rig.get_bone_global_pose(foot).origin).y>base_foot.y+.1,"Imported jump lifts actual foot")
	motion.clear_overrides()
	var sweep := AABB(rig.to_global(rig.get_bone_global_pose(hand).origin),Vector3.ZERO)
	for frame in 60:
		motion.clear_overrides()
		motion.apply_clip("Knife_Slash",float(frame)/30.0,1,true,false)
		sweep=sweep.expand(rig.to_global(rig.get_bone_global_pose(hand).origin))
	print("PINOC knife swept bounds: ",sweep.size)
	check(sweep.size.length()>.35,"Generated slash moves skeletal hand through a real arc")
	motion.reset()
	check(rig.to_global(rig.get_bone_global_pose(hip).origin).distance_to(base_hip)<.01,"Reset removes imported pose overrides")
	print("PINOC motion: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
