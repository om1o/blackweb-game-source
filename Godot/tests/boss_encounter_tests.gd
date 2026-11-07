extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var scene = load("res://scripts/boss_encounter.gd").new()
	scene.qa_mode = true
	root.add_child(scene)
	await process_frame
	await physics_frame
	await physics_frame
	check(scene.progression.auto_save == false and scene.progression.auto_load == false, "Preview never reads or writes tutorial checkpoints")
	check(not scene.boss_bar.visible, "Boss bar hidden before encounter")
	scene._retry()
	scene.set_process(false)
	var boss = scene.boss
	var player = scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	scene.dialogue.reset()
	check(boss.animation_count == 6, "Six skeletal clips installed")
	check(boss.visual.scene_file_path.ends_with("smiling_spider.glb"), "Encounter uses the actual custom boss mesh")
	check(boss.animation.has_animation("death"), "Authored collapse animation exists")
	for data: Dictionary in boss.attacks:
		check(boss.animation.has_animation("boss/" + str(data.id)), "Clip exists: " + str(data.id))
		var clip: Animation = boss.animation.get_animation("boss/" + str(data.id))
		check(clip.get_track_count() >= 16, "Clip articulates the skeleton: " + str(data.id))
		check(is_equal_approx(clip.length, float(data.tell) + float(data.active) + float(data.recover)), "Combat and animation share timing: " + str(data.id))
	var rig: Skeleton3D = boss.visual.find_child("*Skeleton3D*",true,false)
	var foreleg := rig.find_bone("LegSegmentA_R_001")
	var foot := rig.find_bone("LegSegmentC_R_001")
	boss.animation.play("walk",0)
	boss.animation.advance(0.0)
	var first_foot := rig.get_bone_global_pose(foot).origin
	boss.animation.seek(boss.animation.get_animation("walk").length-.001,true)
	var loop_gap := first_foot.distance_to(rig.get_bone_global_pose(foot).origin)
	check(loop_gap<.04, "Walk loop closes without a foot teleport (gap %.4f m)" % loop_gap)
	for data: Dictionary in boss.attacks:
		boss.animation.play("boss/"+str(data.id),0)
		boss.animation.advance(0.0)
		var worst_gap := 0.0
		for fraction in [.0,.5,.95,1.3,1.8]:
			boss.animation.seek(minf(float(data.tell)*fraction,boss.animation.get_animation("boss/"+str(data.id)).length),true)
			for side in ["L","R"]:
				for leg in range(1,5):
					for segment in ["B","C"]:
						var child := rig.find_bone("LegSegment%s_%s_%03d" % [segment,side,leg])
						var parent := rig.get_bone_parent(child)
						var joint := rig.get_bone_global_pose(parent)*rig.get_bone_rest(child).origin
						worst_gap = maxf(worst_gap,joint.distance_to(rig.get_bone_global_pose(child).origin))
		check(worst_gap<.04,"Leg joints stay connected in %s (gap %.4f m)" % [data.id,worst_gap])
	boss.animation.play("idle",0)
	boss.animation.advance(0.0)
	var base_pose := rig.get_bone_pose_rotation(foreleg)
	boss.animation.play("boss/ground_slam",0)
	boss.animation.advance(1.4)
	check(base_pose.angle_to(rig.get_bone_pose_rotation(foreleg)) > 0.25, "Slam actually raises a rigged front leg")
	check(scene.boss_bar.visible and scene.boss_bar.meter.value == 120, "Top bar begins at 120 HP")
	boss.take_damage(4.0)
	check(boss.health == 116 and scene.boss_bar.meter.value == 116, "Knife damage updates boss health and bar")
	boss.take_damage(NAN)
	check(boss.health == 116, "Nonfinite damage is rejected")
	boss.take_damage(57)
	check(boss.phase == 2 and scene.boss_bar.phase.text == "DESPERATION", "Half health enables second phase")
	scene.dialogue.reset()
	boss.global_position = Vector3.ZERO
	boss.rotation = Vector3.ZERO
	player.global_position = Vector3(0,0.04,-1.8)
	player.active = true
	player._hurt_time = 0.0
	player.health = 100.0
	boss.state = boss.State.STALK
	check(boss.start_attack("double_bite"), "Attack starts from stalking")
	check(not boss.start_attack("fang_rush"), "Cannot replace an attack mid-swing")
	await physics_frame
	await physics_frame
	check(boss._sweep_hit(Vector3(0,.8,-.9),Vector3(0,.8,-2.1),.43,9,"test_bite"), "Swept bite volume reaches player capsule")
	check(player.health == 91, "Bite deals configured damage")
	player._hurt_time = 0.0
	check(not boss._sweep_hit(Vector3(0,.8,-.9),Vector3(0,.8,-2.1),.43,9,"test_bite") and player.health == 91, "One hit per attack token across frames")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,3,.2)
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	wall.position = Vector3(0,1,-1.2)
	await physics_frame
	await physics_frame
	check(not boss._sweep_hit(Vector3(0,.8,-.9),Vector3(0,.8,-2.1),.43,9,"blocked_bite"), "Wall blocks damage")
	wall.free()
	await physics_frame
	player._set_crouch(true)
	player._hurt_time = 0.0
	boss.state = boss.State.STALK
	boss.start_attack("reaping_sweep")
	var before: float = player.health
	boss._active_attack(1.0/60.0,.5)
	check(player.health == before, "Crouch avoids raised leg sweep")
	player._set_crouch(false)
	player.global_position = Vector3(0,1.0,-2)
	check(not boss._radial_hit(3.8,16,"jumped_slam",true), "Jump clears ground slam")
	player.global_position.y = .04
	await physics_frame
	check(boss._radial_hit(3.8,16,"grounded_slam",true), "Grounded player inside pulse takes damage")
	player.apply_web_slow(1.6)
	check(is_equal_approx(player._web_slow_time,1.6), "Silk contact applies bounded slow")
	player.apply_web_slow(NAN)
	check(is_equal_approx(player._web_slow_time,1.6), "Invalid slow rejected")
	boss.state = boss.State.STALK
	boss.start_attack("marked_leap")
	var locked: Vector3 = boss._landing
	player.global_position.x += 4
	check(boss._landing == locked and boss._marker.visible, "Leap landing stays committed after target moves")
	boss.set_physics_process(true)
	var clock: float = boss.attack_time
	paused = true
	await process_frame
	await process_frame
	check(boss.attack_time == clock, "Pause freezes attack timeline")
	paused = false
	boss.set_physics_process(false)
	scene._retry()
	boss.set_physics_process(false)
	check(player.health == 100 and player._web_slow_time == 0 and boss.health == 120, "Retry resets health and movement debuffs")
	check(not boss._marker.visible and boss._bolt_life == 0 and boss.attack.is_empty(), "Retry removes active attack hazards")
	check(player.inventory.count(&"candy_bar") == 1 and player.equipped_items().size() == 3, "Retry restores isolated starter inventory")
	var entry: Dictionary = player.survival_snapshot()
	entry.health = 72.0
	entry.battery = 29.0
	scene._entry_loadout = entry
	player.battery_charge = 1.0
	scene._retry()
	boss.set_physics_process(false)
	check(player.health == 72 and player.battery_charge == 29, "Garden retry restores the original campaign-entry supplies")
	scene._entry_loadout.clear()
	for id in ["arrival","greeting","warning","phase_two","victory"]:
		check(scene.dialogue.data.has(id), "Dialogue record exists: " + id)
		if scene.dialogue.data.has(id):
			var stream = load(scene.dialogue.data[id].path)
			check(stream is AudioStream and stream.get_length() > 1, "Audible clip loaded: " + id)
	scene.dialogue.say("greeting")
	scene.dialogue.say("phase_two")
	check(scene.dialogue.channel.playing and scene.caption.text.begins_with("The Smiling Spider:"), "Spoken line and subtitle begin together")
	check(scene.dialogue.queue.size() == 1, "Dialogue queues instead of overlapping")
	check(scene.dialogue.envelopes.has("greeting") and scene.dialogue.envelopes.greeting.samples.max()>0.1, "Boss jaw has a measured audible speech envelope")
	scene.dialogue.reset()
	check(not scene.dialogue.channel.playing and scene.caption.text.is_empty(), "Dialogue reset stops voice and clears subtitle")
	boss.take_damage(1000)
	check(boss.state == boss.State.DEAD and scene.boss_bar.meter.value == 0, "Defeat resolves boss and empties health bar")
	check(boss._bolt_life == 0 and not boss._marker.visible, "Defeat cancels hazards")
	boss.take_damage(4)
	check(boss.health == 0, "Damage after defeat is ignored")
	scene.dialogue.reset()
	scene.queue_free()
	await process_frame
	print("BOSS_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
