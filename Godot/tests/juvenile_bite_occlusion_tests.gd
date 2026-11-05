extends SceneTree
## Regressions for a juvenile biting through a closed door or partition.

const MiniSpider = preload("res://scripts/mini_spider.gd")

class TargetProbe extends Node3D:
	var damage_received := 0.0
	func take_damage(amount: float) -> void:
		damage_received += amount

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _reset_bite(mini, target) -> void:
	mini.position = Vector3(-0.20, 0.44, 0.0)
	mini.velocity = Vector3.ZERO
	mini._bite_windup_remaining = 0.0
	mini._attack_cooldown = 0.0
	target.position = Vector3(0.20, 0.44, 0.0)
	target.damage_received = 0.0

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := TargetProbe.new()
	world.add_child(target)
	var mini = MiniSpider.new()
	mini.auto_bind_progression = false
	mini.walk_speed = 0.0
	mini.hit_damage = 4.0
	world.add_child(mini)
	mini.activate(target)
	mini.set_physics_process(false)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.20, 2.0, 1.20)
	shape.shape = box
	shape.position.y = 1.0
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	_reset_bite(mini, target)
	var obstruction := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mini.position + Vector3.UP * 0.14, target.position + Vector3.UP * 0.14, 1))
	_check(not obstruction.is_empty(), "Fixture puts a solid closed door between the spider and player")
	mini._physics_process(0.01)
	_check(mini._bite_windup_remaining == 0.0, "Closed door prevents the juvenile starting a bite")
	mini._bite_windup_remaining = 0.01
	mini._physics_process(0.02)
	_check(target.damage_received == 0.0, "A closed door blocks damage even at the bite impact frame")

	wall.position.z = 2.0
	await physics_frame
	_reset_bite(mini, target)
	mini._physics_process(0.01)
	_check(mini._bite_windup_remaining > 0.0, "An open doorway still permits a nearby bite")
	_check(mini._visual_animation != null and mini._visual_animation.current_animation == mini._visual_clips.get("attack"), "Unobstructed bite still plays the imported attack animation")
	mini._physics_process(0.30)
	_check(is_equal_approx(target.damage_received, 4.0), "Unobstructed bite applies exactly the authored four damage")
	mini._physics_process(0.02)
	_check(is_equal_approx(target.damage_received, 4.0), "Bite cooldown prevents repeated damage from the same attack")

	_reset_bite(mini, target)
	mini._physics_process(0.01)
	wall.position.z = 0.0
	await physics_frame
	mini._physics_process(0.30)
	_check(target.damage_received == 0.0, "Closing a door during windup cancels damage at impact")

	wall.position.z = 2.0
	await physics_frame
	_reset_bite(mini, target)
	target.position.y += 1.0
	mini._physics_process(0.01)
	_check(mini._bite_windup_remaining == 0.0, "The juvenile cannot bite feet above its reach during a jump")
	print(JSON.stringify({"suite": "juvenile bite occlusion", "checks": checks, "failures": failures}))
	mini.deactivate()
	mini._bite_audio.stream = null
	# Let the headless audio mixer release its last test-bite playback.
	await create_timer(0.25).timeout
	world.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)
