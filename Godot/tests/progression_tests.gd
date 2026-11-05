extends SceneTree
## Run: godot --headless --path <Godot project> --script res://tests/progression_tests.gd

const Progression = preload("res://scripts/progression.gd")
var failures := 0
var checks := 0

class FakePlayer:
	extends Node
	var recovering := false
	func is_recovering() -> bool:
		return recovering


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fresh() -> Progression:
	var story := Progression.new()
	story.auto_load = false
	story.auto_save = false
	# Milestone/transaction coverage; pacing_tests keeps the authored timings.
	story.exploration_seconds = 0.0
	root.add_child(story)
	story.set_process(false)
	return story


func _run() -> void:
	for order in [[&"keys", &"flashlight"], [&"flashlight", &"keys"]]:
		var story := fresh()
		check(not story.interact(&"exit"), "Cannot leave before warning/preparation/encounter")
		check(not story.interact(&"keys"), "Cannot skip message by collecting keys")
		check(not story.resolve_encounter(), "Cannot resolve an encounter that has not started")
		check(story.interact(&"phone"), "Phone starts Mara message")
		check(not story.interact(&"phone"), "Repeated phone input cannot restart message")
		story.step(16.6)
		check(story.stage == Progression.Stage.PREPARATION and story.warning_heard, "Complete message unlocks preparation")
		check(story.interact(order[0]), "First pickup works in either order")
		check(story.stage == Progression.Stage.PREPARATION, "One pickup does not start presence")
		check(story.interact(order[1]), "Second pickup works in either order")
		check(story.stage == Progression.Stage.PRESENCE, "Both pickups start presence")
		check(not story.interact(order[0]), "Duplicate pickup is rejected")
		story.step(story.presence_seconds)
		check(story.stage == Progression.Stage.POWER_LOSS and not story.power_available, "Presence ends in power loss")
		story.step(story.power_loss_seconds)
		check(story.stage == Progression.Stage.ENCOUNTER, "Power loss starts encounter")
		story.step(120.0)
		check(story.stage == Progression.Stage.ENCOUNTER, "Encounter requires escape by default")
		var fake := FakePlayer.new()
		story.player = fake
		fake.recovering = true
		story.use_timed_encounter_resolution = true
		story.step(120.0)
		check(story.stage == Progression.Stage.ENCOUNTER, "Recovery pauses timed survival")
		check(not story.resolve_encounter(), "Fatal recovery cannot count as escaping")
		fake.recovering = false
		check(story.resolve_encounter(), "Escaping resolves encounter")
		check(story.interact(&"exit"), "Prepared survivor can leave")
		check(story.stage == Progression.Stage.COMPLETE, "Departure completes opening")
		check(not story.interact(&"exit"), "Departure cannot repeat")
		var saved := story.snapshot()
		var clone := fresh()
		check(clone.restore_snapshot(saved), "Known checkpoint round-trips")
		check(clone.stage == Progression.Stage.COMPLETE and clone.departed, "Completed checkpoint retains departure")
		var future: Dictionary = saved.duplicate(true)
		future.version = 999
		check(not clone.restore_snapshot(future), "Unknown save schemas are rejected")
		check(clone.stage == Progression.Stage.COMPLETE, "Rejected restore cannot alter current progress")
		clone.restart_opening()
		check(clone.stage == Progression.Stage.NORMAL and not clone.has_keys, "New game restores initial flags")
		clone.free()
		fake.free()
		story.free()

	var repair := fresh()
	var inconsistent := {"version": 1, "stage": Progression.Stage.COMPLETE, "warning_heard": false,
		"has_keys": true, "has_flashlight": true, "encounter_survived": true, "departed": true}
	check(repair.restore_snapshot(inconsistent), "Inconsistent checkpoint can be repaired")
	check(repair.stage == Progression.Stage.NORMAL and not repair.has_keys and not repair.departed, "Missing warning repairs to beginning")
	inconsistent.warning_heard = true
	inconsistent.has_flashlight = false
	check(repair.restore_snapshot(inconsistent), "Partial preparation checkpoint can be repaired")
	check(repair.stage == Progression.Stage.PREPARATION and not repair.encounter_survived, "Partial preparation cannot retain survival")
	inconsistent.has_flashlight = "false"
	check(not repair.restore_snapshot(inconsistent), "String flags cannot masquerade as booleans")
	var event_order: Array[String] = []
	repair.checkpoint_restored.connect(func() -> void: event_order.append("reset"))
	repair.stage_changed.connect(func(_stage: int) -> void: event_order.append("stage"))
	repair.retry_checkpoint()
	check(event_order == ["reset", "stage"], "Player checkpoint reset precedes encounter-stage listeners")
	repair.free()
	print("Progression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
