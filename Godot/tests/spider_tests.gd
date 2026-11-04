extends SceneTree
## Test-only geometry. No recovered scenes or visual assets are needed.
## Run: godot --headless --path <Godot project> --script res://tests/spider_tests.gd

const Progression = preload("res://scripts/progression.gd")
const Spider = preload("res://scripts/spider.gd")
var failures := 0
var checks := 0

class TestPlayer:
	extends CharacterBody3D
	var health := 100.0
	var hits := 0
	var recovering := false
	var spawn_position := Vector3(0.8, 0.025, 0.0)
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 1
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.75
		capsule.radius = 0.27
		shape.shape = capsule
		shape.position.y = 0.875
		add_child(shape)
		global_position = spawn_position
	func take_damage(amount: float) -> void:
		if recovering: return
		hits += 1
		health = maxf(0.0, health - amount)
		recovering = health <= 0.0
	func is_recovering() -> bool:
		return recovering
	func reset_checkpoint() -> void:
		global_position = spawn_position
		velocity = Vector3.ZERO
		health = 100.0
		recovering = false


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func box(parent: Node3D, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 7
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	parent.add_child(body)
	return body


func wait_seconds(seconds: float) -> void:
	await create_timer(seconds, false, true).timeout


func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	box(fixture, Vector3(30.0, 0.4, 30.0), Vector3(0.0, -0.2, 0.0))
	var wall := box(fixture, Vector3(0.12, 2.0, 20.0), Vector3(0.0, 1.0, 0.0))
	var player := TestPlayer.new()
	fixture.add_child(player)
	var story := Progression.new()
	story.auto_load = false
	story.auto_save = false
	story.auto_advance_atmosphere = false
	story.player = player
	fixture.add_child(story)
	story.set_process(false)
	story.checkpoint_restored.connect(player.reset_checkpoint)
	var spider := Spider.new()
	spider.position = Vector3(-0.8, 0.025, 0.0)
	spider.target = player
	spider.progression = story
	fixture.add_child(spider)
	var observed_states: Array[int] = []
	spider.state_changed.connect(func(value: int) -> void: observed_states.append(value))
	await process_frame
	check(story.restore_snapshot({"version": 1, "stage": Progression.Stage.ENCOUNTER,
		"warning_heard": true, "has_keys": true, "has_flashlight": true,
		"encounter_survived": false, "departed": false}), "Encounter fixture restores")
	await wait_seconds(4.0)
	check(player.hits == 0, "A wall blocks damage despite player being inside attack range")
	check(spider.global_position.x < -0.30, "Collision prevents the spider crossing the wall")
	check(Spider.State.WINDUP not in observed_states, "Blocked line of sight cannot begin a windup")

	wall.queue_free()
	await process_frame
	await physics_frame
	observed_states.clear()
	story.retry_checkpoint()
	await wait_seconds(3.2)
	check(Spider.State.ANTICIPATION in observed_states and Spider.State.WINDUP in observed_states,
		"Open encounter visibly anticipates and winds up before its lunge")
	check(Spider.State.LUNGING in observed_states, "An unobstructed route permits a lunge")
	check(player.hits == 1 and is_equal_approx(player.health, 65.0), "Open-lane lunge deals exactly one configured hit")
	await wait_seconds(1.0)
	check(player.hits == 1, "Retreat/cooldown cannot repeat damage from the same lunge")

	story.retry_checkpoint()
	player.health = 20.0
	await wait_seconds(3.2)
	check(player.recovering, "A fatal lunge enters player recovery")
	story.use_timed_encounter_resolution = true
	story.step(100.0)
	check(story.stage == Progression.Stage.ENCOUNTER, "Recovery blocks timed survival")
	check(not spider.resolve_at_exit(), "Recovery blocks safe-exit resolution")
	var hits_during_recovery := player.hits
	await wait_seconds(1.0)
	check(player.hits == hits_during_recovery, "Recovering player cannot be damaged repeatedly")
	story.retry_checkpoint()
	check(not player.recovering and is_equal_approx(player.health, 100.0), "Checkpoint restores player health and control")
	check(spider.state == Spider.State.ANTICIPATION, "Checkpoint restarts the encounter telegraph")
	check(spider.global_position.distance_to(Vector3(-0.8, 0.025, 0.0)) < 0.01,
		"Only checkpoint reset restores the spider's placed position")

	var safe := Node3D.new()
	safe.position = player.spawn_position
	fixture.add_child(safe)
	spider.safe_exit_anchor = safe
	spider.safe_exit_radius = 0.4
	spider.safe_exit_hold = 0.2
	spider.exit_resolution_delay = 0.1
	await wait_seconds(0.6)
	check(story.stage == Progression.Stage.READY_TO_LEAVE, "Holding the safe route resolves the encounter")
	check(spider.state == Spider.State.RESOLVED and not spider.is_physics_processing(), "Resolved spider sleeps")
	check(story.interact(&"exit"), "Exit remains completable after the physical encounter")
	fixture.queue_free()
	await process_frame
	print("Spider integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
