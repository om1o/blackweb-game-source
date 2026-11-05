extends SceneTree
## Meaningful pursuit regression: opaque walls, moving doors and gravity.
const MiniSpider = preload("res://scripts/mini_spider.gd")

class TargetProbe extends Node3D:
	var damage_received := 0.0
	func take_damage(amount: float) -> void: damage_received += amount

var checks := 0
var failures: Array[String] = []
var world: Node3D
var mini: BlackwebMiniSpider
var target: TargetProbe
var wall: StaticBody3D

func _initialize() -> void: call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	world.add_child(body)
	body.position = at
	return body

func _reset(at := Vector3(-1.0, 0.42, 0.0)) -> void:
	mini.position = at
	mini.velocity = Vector3.ZERO
	mini.activate(target)
	mini.set_physics_process(false)
	target.damage_received = 0.0

func _ticks(count: int) -> void:
	for index in count:
		await physics_frame
		mini._physics_process(1.0 / 60.0)

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(10.0, 0.4, 10.0), Vector3(0.0, 0.2, 0.0))
	wall = _box(Vector3(0.2, 2.8, 2.0), Vector3(0.0, 1.8, 0.0))
	target = TargetProbe.new()
	world.add_child(target)
	target.position = Vector3(1.2, 0.42, 0.0)
	mini = MiniSpider.new()
	mini.auto_bind_progression = false
	world.add_child(mini)
	_reset()
	await physics_frame
	await physics_frame
	_check(not mini._can_see_target(), "Closed door occludes a target within awareness range")
	await _ticks(60)
	_check(absf(mini.position.x + 1.0) < 0.025, "Hidden target does not make the juvenile push into its partition")
	_check(mini.active and mini.collision_layer == 4 and mini.collision_mask == 3, "Waiting juvenile retains active AI and collision")
	_check(mini.is_on_floor() and absf(mini.position.y - 0.4) < 0.025, "Occluded juvenile still settles onto the physical floor")
	_check(mini._visual_animation.current_animation == mini._visual_clips.get("idle"), "Occluded juvenile displays its authored idle animation")
	wall.position.z = 3.0
	await physics_frame
	_check(mini._can_see_target(), "Opening the door restores the target sightline")
	await _ticks(30)
	_check(mini.position.x > -0.65 and mini.velocity.x > 1.2, "The same active juvenile resumes full-speed pursuit through the opening")
	_check(mini._visual_animation.current_animation == mini._visual_clips.get("walk"), "Resumed pursuit displays its authored walking animation")
	wall.position.z = 0.0
	await physics_frame
	await _ticks(25)
	_check(absf(mini.velocity.x) < 0.01 and mini.position.x < -0.225, "A door closing during pursuit stops forward drive without crossing the solid door")
	_reset(Vector3(-1.0, 1.7, 0.0))
	await _ticks(40)
	_check(mini.is_on_floor() and absf(mini.position.y - 0.4) < 0.025, "A blocked airborne juvenile continues falling rather than freezing in midair")
	target.position = Vector3(-2.0, 0.42, 0.0)
	await _ticks(24)
	_check(mini.position.x < -1.25, "A target entering the same side of the wall immediately reacquires pursuit")
	_reset()
	wall.position.z = 3.0
	target.position = Vector3(20.0, 0.42, 0.0)
	await physics_frame
	await _ticks(20)
	_check(absf(mini.position.x + 1.0) < 0.025, "A visible target beyond awareness radius does not trigger pursuit")
	print(JSON.stringify({"suite": "juvenile visible pursuit", "checks": checks, "failures": failures}))
	world.process_mode = Node.PROCESS_MODE_DISABLED
	mini.deactivate()
	mini._bite_audio.stop()
	world.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)
