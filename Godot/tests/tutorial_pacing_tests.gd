extends SceneTree
## Actual story and soundscape, without importing/rendering the full house.
## Deterministic active-time steps also exercise pause, retry and new-game paths.

const Progression = preload("res://scripts/progression.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
var results: Array[Dictionary] = []
var failures := 0

class QuietPlayer:
	extends "res://scripts/player.gd"
	func _ready() -> void:
		active = true
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)

func _initialize() -> void:
	call_deferred("_run")

func check(passed: bool, description: String) -> void:
	results.append({"passed": passed, "description": description})
	if not passed:
		failures += 1
		push_error(description)

func fresh() -> Progression:
	var story := Progression.new()
	story.auto_load = false
	story.auto_save = false
	story.requires_vault = true
	root.add_child(story)
	story.set_process(false)
	return story

func _run() -> void:
	var actor := QuietPlayer.new()
	root.add_child(actor)
	actor.position = Vector3(30.0, 0.0, 30.0)
	var story := fresh()
	story.player = actor
	var sounds := Soundscape.new()
	sounds.player = actor
	sounds.progression = story
	root.add_child(sounds)
	sounds.set_process(false)
	# The cue's scheduling is tested with a tiny original tone. Actual dialogue
	# still uses the packaged recordings; this avoids house/model dependencies.
	sounds._presence.stream = sounds._tone(0.3, 80.0, 0.05)
	check(story.exploration_seconds == 18.0 and story.presence_seconds == 14.0 and story.power_loss_seconds == 8.0, "Authored exploration / warning / blackout beats are 18 / 14 / 8 active seconds")
	check(not story.flashlight_flicker_allowed(), "Arrival keeps the weak starter's beam steady")
	sounds._process(0.1)
	check(sounds._room.playing and not sounds._presence.playing and not sounds._web_voice.playing, "Arrival contains room ambience without presence cue or web speech")
	story.step(100.0)
	check(story.stage == story.Stage.NORMAL and story.power_available, "Waiting at the entrance cannot start threats or cut power")
	check(story.interact(&"phone") and not story.flashlight_flicker_allowed(), "Answering starts the clue while preserving steady light")
	story.step(100.0)
	check(story.stage == story.Stage.PREPARATION and story.warning_heard and story._elapsed == 0.0, "Even a late dialogue frame begins a fresh exploration beat without carrying time across stages")
	check(not sounds.play_web_reveal_voice(), "Luke's web reaction cannot immediately overlap the completed call")
	story.step(3.99)
	check(not sounds.play_web_reveal_voice(), "The web reaction waits its four-second breathing room")
	story.step(0.02)
	check(sounds.play_web_reveal_voice() and sounds._web_voice_played, "The real web recording becomes available after breathing room")
	check(not sounds.play_web_reveal_voice(), "A second request cannot overlap or repeat the web recording")
	sounds._web_voice.stop()
	check(story.interact(&"keys") and story.interact(&"flashlight"), "Key and spare-cell milestones remain available during exploration")
	check(is_equal_approx(actor.battery_charge, 57.0), "The chosen weak 22% starter and 35% spare-cell pickup remain unchanged")
	story.unlock_vault()
	check(story.prepared() and story.stage == story.Stage.PREPARATION and not story.flashlight_flicker_allowed(), "Precompleted key, battery and vault cannot skip early exploration or start flicker")
	var preparation_save := story.snapshot()
	var elapsed := story._elapsed
	paused = true
	story.step(120.0)
	sounds._process(120.0)
	check(story._elapsed == elapsed and story.stage == story.Stage.PREPARATION and not sounds._presence_started, "Paper, inventory and menu pause cannot consume the exploration beat")
	paused = false
	actor._recovering = true
	story.step(120.0)
	check(story._elapsed == elapsed, "Recovery time cannot consume the exploration beat")
	actor._recovering = false
	story.step(NAN)
	story.step(-1.0)
	check(story._elapsed == elapsed, "Invalid or negative deltas cannot advance story time")
	story.step(story.exploration_seconds - story._elapsed - 0.01)
	check(story.stage == story.Stage.PREPARATION, "A prepared player still receives the entire exploration minimum")
	story.step(0.02)
	check(story.stage == story.Stage.PRESENCE and story.power_available and story.flashlight_flicker_allowed(), "Only the completed exploration beat unlocks the first warning and battery-based flicker")
	sounds._process(0.01)
	check(not sounds._presence_started and not sounds._presence.playing, "The spatial warning leaves a quiet beat after the visual reveal")
	story.step(1.99)
	sounds._process(0.01)
	check(not sounds._presence_started, "Presence audio cannot start before two active seconds")
	story.step(0.02)
	sounds._process(0.01)
	check(sounds._presence_started and sounds._presence.playing, "A quiet spatial cue begins before the encounter")
	var cue_remaining: float = sounds._presence_remaining
	sounds._stage_changed(story.Stage.PRESENCE)
	check(sounds._presence_started and sounds._presence_remaining == cue_remaining, "Duplicate stage notifications cannot restart the cue or extend its budget")
	paused = true
	sounds._process(120.0)
	story.step(120.0)
	check(sounds._presence_remaining == cue_remaining and story._elapsed < 2.02, "Pause freezes both cue budget and warning stage time")
	paused = false
	sounds._process(6.0)
	check(sounds._presence_remaining == 0.0 and not sounds._presence.playing, "Spatial warning stops within six active seconds without looping")
	story.step(story.presence_seconds - story._elapsed - 0.01)
	check(story.stage == story.Stage.PRESENCE and story.power_available, "No blackout before the full fourteen-second warning")
	story.step(0.02)
	check(story.stage == story.Stage.POWER_LOSS and not story.power_available and sounds._event.playing, "Power loss follows the warning with one physical power-cut click")
	check(not sounds._room.playing and not sounds._presence.playing and not sounds._web_voice.playing, "Power loss leaves silence instead of stacked cues or a horror score")
	var blackout_save := story.snapshot()
	check(story.restore_snapshot(blackout_save) and story.stage == story.Stage.POWER_LOSS and story._elapsed == 0.0, "Restoring a valid blackout checkpoint preserves the milestone and restarts its safety beat")
	check(not sounds._event.playing, "Checkpoint restoration does not replay the power-cut transient")
	story.step(7.99)
	check(story.stage == story.Stage.POWER_LOSS, "The first attack stage cannot start before eight blackout seconds")
	story.step(0.02)
	check(story.stage == story.Stage.ENCOUNTER, "The encounter starts after the full warning sequence")
	story.step(120.0)
	check(story.stage == story.Stage.ENCOUNTER and not story.encounter_survived, "Waiting does not falsely resolve an active encounter")
	story.retry_checkpoint()
	check(story.stage == story.Stage.ENCOUNTER and story._elapsed == 0.0 and not sounds._event.playing, "Retry preserves the active encounter milestone without stale sound playback")
	var clone := fresh()
	check(clone.restore_snapshot(preparation_save) and clone.stage == clone.Stage.PREPARATION and clone.prepared(), "A fully prepared saved exploration beat is not normalized into an early warning")
	clone.step(17.99)
	check(clone.stage == clone.Stage.PREPARATION, "Restored preparation grants a fresh full exploration beat")
	clone.step(0.02)
	check(clone.stage == clone.Stage.PRESENCE, "Restored completed milestones advance normally after their exploration beat")
	clone.free()
	story.restart_opening()
	check(story.stage == story.Stage.NORMAL and not story.warning_heard and not story.has_keys and not story.vault_unlocked and story._elapsed == 0.0, "New Game clears story milestones and every stage timer")
	check(not story.flashlight_flicker_allowed() and not sounds._web_voice_played and not sounds._presence_started and not sounds._presence.playing and not sounds._event.playing, "New Game restores quiet arrival, stable light policy and replayable clues")
	sounds._process(0.01)
	check(sounds._room.playing and not sounds._mara_warning.playing, "New Game restarts ordinary room ambience without replaying an unanswered call")
	story.interact(&"phone")
	story.step(100.0)
	story.step(100.0)
	check(story.stage == story.Stage.PREPARATION and not story.prepared(), "Elapsed exploration alone cannot bypass the vault key, spare cells or code")
	for child in sounds.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D: child.stop()
	await create_timer(0.2).timeout
	sounds.free()
	story.free()
	actor.free()
	# Allow the audio server to release stopped playback objects before exit.
	await create_timer(0.1).timeout
	var file := FileAccess.open("res://../Evidence/tutorial-pacing-tests.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"checks": results.size(), "failures": failures, "results": results}, "  "))
		file.close()
	print("Tutorial pacing: %d checks, %d failures" % [results.size(), failures])
	quit(0 if failures == 0 else 1)
