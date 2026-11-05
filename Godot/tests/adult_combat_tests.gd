extends SceneTree
## Asset-independent adult combat regression. Uses real physics frames and
## production progression; no direct calls to the spider's contact evaluator.

const Spider = preload("res://scripts/spider.gd")
const Progression = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []
var fixture: Node3D
var player: TestPlayer
var story: Progression
var spider: Spider
var observed_states: Array[int] = []
var death_events := 0
var health_events: Array[float] = []

class TestPlayer:
	extends CharacterBody3D
	var health := 100.0
	var hits := 0
	var damage_attempts := 0
	var recovering := false
	var active := true
	var spawn_position := Vector3(0.0, 0.025, -2.0)
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 1
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.75
		capsule.radius = 0.27
		collision.shape = capsule
		collision.position.y = 0.875
		add_child(collision)
		reset_checkpoint()
	func take_damage(amount: float) -> void:
		damage_attempts += 1
		if recovering or health <= 0.0: return
		hits += 1
		health = maxf(0.0, health - amount)
		recovering = health <= 0.0
	func is_recovering() -> bool:
		return recovering
	func is_alive() -> bool:
		return health > 0.0 and not recovering
	func reset_checkpoint() -> void:
		global_position = spawn_position
		velocity = Vector3.ZERO
		health = 100.0
		hits = 0
		damage_attempts = 0
		recovering = false
		active = true

func _initialize() -> void:
	call_deferred("_run")

func check(passed: bool, description: String) -> void:
	checks += 1
	results.append({"passed": passed, "description": description})
	if not passed:
		failures += 1
		push_error(description)

func box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 7
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	fixture.add_child(body)
	return body

func wait_seconds(seconds: float, while_paused := false) -> void:
	await create_timer(seconds, while_paused, true).timeout

func wait_state(expected: int, timeout := 2.5) -> bool:
	var remaining := ceili(timeout * Engine.physics_ticks_per_second)
	while spider.state != expected and remaining > 0:
		await physics_frame
		remaining -= 1
	return spider.state == expected

func reset_encounter(distance := 2.0) -> void:
	player.spawn_position = Vector3(0.0, 0.025, -distance)
	observed_states.clear()
	spider.safe_exit_anchor = null
	story.restore_snapshot({"version": Progression.SAVE_VERSION,
		"stage": Progression.Stage.ENCOUNTER, "warning_heard": true,
		"has_flashlight": true, "has_keys": true,
		"encounter_survived": false, "departed": false})
	spider.rotation = Vector3.ZERO
	await physics_frame
	await physics_frame

func test_perception() -> void:
	# Freeze locomotion only. Sensing still queries the real physics world;
	# explicit time steps isolate memory from the combat controller's cadence.
	var wall := box(Vector3(8.0, 2.4, 0.12), Vector3(0.0, 1.2, -0.75))
	await reset_encounter(3.0)
	spider.set_physics_process(false)
	spider.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await physics_frame
	spider._sense_target(0.1)
	check(not spider._target_visible and not spider._has_target_memory, "A stationary target behind a wall is not acquired")

	wall.collision_layer = 0
	await physics_frame
	await physics_frame
	spider._sense_target(0.1)
	check(spider._target_visible and spider._has_target_memory, "An unobstructed stationary target is acquired by sight")
	var last_seen := player.global_position
	check(spider._last_known_position.is_equal_approx(last_seen) and is_equal_approx(spider._memory_remaining, 4.5), "Seeing the player records its position and starts 4.5 seconds of memory")

	wall.collision_layer = 1
	player.global_position = Vector3(1.2, 0.025, -3.0)
	await physics_frame
	await physics_frame
	spider._sense_target(0.1)
	check(not spider._target_visible and spider._last_known_position.is_equal_approx(last_seen), "A silent hidden player can change position without updating last-known position")
	spider._sense_target(4.3)
	check(spider._has_target_memory and spider._memory_remaining > 0.0, "The last-seen position remains remembered just before 4.5 seconds")
	spider._sense_target(0.11)
	check(not spider._has_target_memory and is_zero_approx(spider._memory_remaining), "Target memory expires after 4.5 seconds without a sensory update")
	spider._set_state(Spider.State.STALKING)
	spider._think(0.1)
	check(spider.state == Spider.State.SEARCHING and spider._desired_velocity.is_zero_approx(), "Expired memory leaves pursuit for a stationary search")

	player.velocity = Vector3(2.49, 0.0, 0.0)
	spider._sense_target(0.1)
	check(not spider._has_target_memory, "Movement below the hearing threshold does not reveal a hidden player")
	player.velocity = Vector3(2.5, 0.0, 0.0)
	spider._sense_target(0.1)
	var last_heard := player.global_position
	check(not spider._target_visible and spider._has_target_memory and spider._last_known_position.is_equal_approx(last_heard), "Fast movement within 4.5 metres can be heard behind a wall")
	player.global_position = Vector3(0.0, 0.025, -4.6)
	spider._sense_target(4.6)
	check(not spider._has_target_memory and spider._last_known_position.is_equal_approx(last_heard), "Movement beyond hearing range does not track a new hidden position")

	wall.collision_layer = 0
	player.global_position = Vector3(0.0, 0.025, -3.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	spider._sense_target(0.1)
	check(spider._target_visible and spider._has_target_memory and spider._last_known_position.is_equal_approx(player.global_position), "Returning to sight reacquires the player at its current position")
	player.global_position = Vector3(0.0, 0.025, 3.0)
	spider._sense_target(4.6)
	check(not spider._target_visible and not spider._has_target_memory, "A stationary distant rear target is outside the 240-degree sight cone")
	player.global_position = Vector3(0.0, 0.025, 2.0)
	spider._sense_target(0.1)
	check(spider._target_visible and spider._has_target_memory, "A rear target within the 2.4-metre proximity radius can be seen")
	player.global_position = Vector3(0.0, 0.025, -12.5)
	spider._sense_target(4.6)
	check(not spider._target_visible and not spider._has_target_memory, "A stationary target beyond the awareness radius is not acquired")
	wall.queue_free()
	await process_frame
	await physics_frame
	spider.set_physics_process(true)

func _run() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	box(Vector3(40.0, 0.4, 40.0), Vector3(0.0, -0.2, 0.0))
	player = TestPlayer.new()
	fixture.add_child(player)
	story = Progression.new()
	story.auto_load = false
	story.auto_save = false
	story.auto_advance_atmosphere = false
	story.player = player
	fixture.add_child(story)
	story.set_process(false)
	story.checkpoint_restored.connect(player.reset_checkpoint)
	spider = Spider.new()
	spider.position = Vector3(0.0, 0.025, 0.0)
	spider.target = player
	spider.progression = story
	spider.anticipation_seconds = 0.08
	spider.process_mode = Node.PROCESS_MODE_PAUSABLE
	fixture.add_child(spider)
	spider.state_changed.connect(func(value: int) -> void: observed_states.append(value))
	spider.died.connect(func() -> void: death_events += 1)
	spider.health_changed.connect(func(current: float, _maximum: float) -> void: health_events.append(current))
	await process_frame
	await test_perception()

	# Initial occlusion: sensing and contact must both respect closed geometry.
	var door := box(Vector3(8.0, 2.4, 0.12), Vector3(0.0, 1.2, -0.50))
	await reset_encounter(1.0)
	await wait_seconds(1.2)
	check(player.hits == 0, "A closed door blocks adult damage at close range")
	check(Spider.State.WINDUP not in observed_states, "A closed door blocks an attack windup")
	check(spider.global_position.z > -0.23, "The adult capsule cannot cross the closed door")
	door.queue_free()
	await process_frame
	await physics_frame

	# Default close bite: no startup damage and one active-window contact.
	await reset_encounter(0.80)
	check(await wait_state(Spider.State.WINDUP), "A nearby visible target triggers the bite telegraph")
	await wait_seconds(0.25)
	check(player.hits == 0, "The bite cannot damage during its windup")
	await wait_seconds(0.85)
	check(player.hits == 1 and is_equal_approx(player.health, 82.0), "The close bite deals one 18-damage contact")
	await wait_seconds(0.35)
	check(player.hits == 1, "Bite recovery cannot repeat the same attack hit")

	# Longer attack retains the original lunge damage and a readable windup.
	await reset_encounter(2.0)
	check(await wait_state(Spider.State.WINDUP), "A mid-range visible target triggers a lunge telegraph")
	await wait_seconds(0.40)
	check(player.hits == 0, "The lunge cannot damage during its windup")
	await wait_seconds(1.15)
	check(player.hits == 1 and is_equal_approx(player.health, 65.0), "An unobstructed lunge deals exactly one 35-damage hit")
	await wait_seconds(0.30)
	check(player.hits == 1, "Lunge retreat cannot deal another hit")

	# A dodge after the telegraph must defeat the committed attack direction.
	await reset_encounter(2.0)
	check(await wait_state(Spider.State.WINDUP), "Sidestep fixture reaches the committed windup")
	player.global_position.x = 1.5
	await wait_seconds(1.65)
	check(player.hits == 0, "Moving sideways after windup avoids the committed lunge")
	check(absf(spider.global_position.x) < 0.45, "The lunge does not steer sideways toward the dodging target")
	await reset_encounter(0.80)
	check(await wait_state(Spider.State.WINDUP), "Close sidestep fixture enters windup")
	player.global_position = Vector3(0.80, 0.025, 0.0)
	await wait_seconds(0.85)
	check(player.damage_attempts == 0, "A nearby target beside the committed bite direction is outside its hit cone")

	# A door closing after commitment must prevent hit registration, even if
	# the spider has cached the target's last seen position.
	await reset_encounter(0.80)
	check(await wait_state(Spider.State.WINDUP), "Closing-door fixture begins with a visible target")
	door = box(Vector3(8.0, 2.4, 0.12), Vector3(0.0, 1.2, -0.42))
	await physics_frame
	await wait_seconds(1.25)
	check(player.hits == 0, "A door closing during the telegraph prevents attack contact")
	door.queue_free()
	await process_frame
	await physics_frame

	# Pause must freeze attack time as well as physical travel and damage.
	await reset_encounter(0.80)
	check(await wait_state(Spider.State.WINDUP), "Pause fixture enters windup")
	var frozen_position := spider.global_position
	var frozen_elapsed := spider._state_elapsed
	paused = true
	await wait_seconds(0.70, true)
	check(spider.state == Spider.State.WINDUP and is_equal_approx(spider._state_elapsed, frozen_elapsed), "Tree pause freezes the attack clock")
	check(player.hits == 0 and spider.global_position.is_equal_approx(frozen_position), "A paused adult neither moves nor damages")
	paused = false
	await wait_seconds(1.15)
	check(player.hits == 1, "Unpausing resumes the pending attack once")

	# Recovery cancels live attacks and cannot unlock the escape checkpoint.
	await reset_encounter(0.80)
	check(await wait_state(Spider.State.WINDUP), "Recovery fixture enters windup")
	player.recovering = true
	player.health = 0.0
	await wait_seconds(0.12)
	check(spider.state not in [Spider.State.WINDUP, Spider.State.LUNGING], "Recovery cancels an adult attack")
	check(not spider._attack_tell_light.visible, "Recovery clears the canceled attack tell")
	check(not spider.resolve_at_exit() and not story.resolve_encounter(), "A recovering player cannot resolve the encounter")
	await wait_seconds(0.75)
	check(player.hits == 0, "A recovering player receives no adult contact")

	# A zero-health target must also be protected if a caller has not yet
	# switched its recovery flag (the two properties are not the same signal).
	await reset_encounter(0.80)
	check(await wait_state(Spider.State.WINDUP), "Dead-target fixture enters windup")
	player.health = 0.0
	player.recovering = false
	await wait_seconds(0.12)
	check(spider.state not in [Spider.State.WINDUP, Spider.State.LUNGING], "A zero-health target immediately cancels an attack")
	await wait_seconds(1.03)
	check(player.damage_attempts == 0, "A zero-health target receives no attempted damage")

	# Damage remains useful during stagger, but rapid taps cannot stunlock.
	await reset_encounter(2.0)
	spider.take_damage(4.0)
	check(spider.state == Spider.State.STAGGERED and is_equal_approx(spider.health, 96.0), "A worn-knife hit removes four health and briefly staggers")
	await wait_seconds(0.20)
	spider.take_damage(4.0)
	await wait_seconds(0.18)
	check(is_equal_approx(spider.health, 92.0) and spider.state != Spider.State.STAGGERED, "A rapid second hit damages without extending the stagger")
	await wait_seconds(1.25)
	spider.take_damage(4.0)
	check(spider.state == Spider.State.STAGGERED, "Stagger becomes available after its refractory period")
	await reset_encounter(0.80)
	for index in range(4):
		spider.take_damage(4.0)
		await wait_seconds(0.75)
	check(is_equal_approx(spider.health, 84.0), "Repeated weak knife hits retain their four-damage value")
	check(player.hits > 0, "Holding knife attacks at the 0.75-second cooldown cannot permanently suppress adult retaliation")

	# Twenty-five weak hits can kill the common 100-HP adult; health never
	# clamps at one, death has one signal, and the corpse ceases collision.
	await reset_encounter(2.0)
	health_events.clear()
	death_events = 0
	for index in range(24): spider.take_damage(4.0)
	check(is_equal_approx(spider.health, 4.0) and spider.is_alive(), "Twenty-four worn-knife hits leave four adult health")
	spider.take_damage(4.0)
	check(is_zero_approx(spider.health) and not spider.is_alive(), "The twenty-fifth worn-knife hit reaches zero health")
	check(spider.state == Spider.State.DYING and spider.collision_layer == 0 and spider.collision_mask == 0, "A dying adult immediately disables combat collision")
	check(story.stage == Progression.Stage.ENCOUNTER, "Death waits for its presentation before resolving progression")
	spider.take_damage(100.0)
	var hits_at_death := player.hits
	await wait_seconds(1.35)
	check(spider.state == Spider.State.DEAD and spider.visible, "The finished adult corpse remains visible")
	check(death_events == 1 and health_events.size() == 25 and is_zero_approx(health_events.back()), "Health and death signals report the lethal sequence once")
	check(player.hits == hits_at_death, "A dying or dead adult cannot hit the player")
	check(story.stage == Progression.Stage.READY_TO_LEAVE and story.encounter_survived, "Adult death completes the encounter milestone")
	check(story.interact(&"exit"), "The exit remains usable after killing the adult")

	await reset_encounter(2.0)
	check(spider.is_alive() and is_equal_approx(spider.health, 100.0), "Checkpoint restore revives the adult at full health")
	check(spider.collision_layer == 4 and spider.collision_mask == 3 and spider.visible, "Checkpoint restore reinstates adult collision and visibility")
	check(spider.global_position.distance_to(Vector3(0.0, 0.025, 0.0)) < 0.08, "Checkpoint restore returns the adult to its authored spawn")
	for index in range(25): spider.take_damage(4.0)
	await wait_seconds(0.20)
	await reset_encounter(15.0)
	await wait_seconds(1.30)
	check(spider.is_alive() and story.stage == Progression.Stage.ENCOUNTER, "Reset during death cancels the old death completion")

	player.queue_free()
	await process_frame
	await physics_frame
	await physics_frame
	check(not spider.is_physics_processing(), "Removing the target safely deactivates adult processing")
	await _finish()

func _finish() -> void:
	paused = false
	spider.deactivate()
	for audio in fixture.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	await wait_seconds(0.12)
	fixture.queue_free()
	await process_frame
	await process_frame
	await wait_seconds(0.12)
	var path := ProjectSettings.globalize_path("res://../Evidence/adult-combat-tests.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"kind": "asset-independent adult combat and perception, real physics frames and queries", "checks": checks, "failures": failures, "results": results}, "  "))
		file.close()
	print("Adult combat: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
