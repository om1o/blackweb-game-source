class_name BlackwebProgression
extends Node
## Asset-independent house-opening progression, checkpoint storage and presentation text.

signal stage_changed(new_stage: int)
signal power_changed(available: bool)
signal inventory_changed
signal subtitle_changed(text: String)
signal notice_changed(text: String)
signal checkpoint_restored

enum Stage { NORMAL, MESSAGE, PREPARATION, PRESENCE, POWER_LOSS, ENCOUNTER, READY_TO_LEAVE, COMPLETE }
const SAVE_VERSION := 1

@export var auto_load := true
@export var auto_save := true
@export var auto_advance_atmosphere := true
@export var use_timed_encounter_resolution := false
@export_range(1.0, 60.0) var presence_seconds := 8.0
@export_range(1.0, 60.0) var power_loss_seconds := 6.0
@export_range(3.0, 120.0) var encounter_seconds := 20.0
@export var save_path := "user://blackweb_house_v1.json"
@export var player: Node
@export var mara_lines: Array[String] = [
	"Mara: Luke? If you get this, stay home.",
	"Mara: Something's happening in Greyhaven. The streets are—",
	"Mara: Don't come looking for me. Please. I can hear—",
	"[Connection lost]",
	"Luke: Mara. Pick up. ...I'm coming.",
]
@export var mara_durations: Array[float] = [3.5, 4.0, 4.0, 2.0, 3.0]

var stage: int = Stage.NORMAL
var warning_heard := false
var has_flashlight := false
var has_keys := false
var encounter_survived := false
var departed := false
var power_available := true
var subtitle := ""
var notice := ""
var save_writes_blocked := false
var last_save_succeeded := true
var _elapsed := 0.0
var _notice_remaining := 0.0
var _checkpoint: Dictionary = {}


func _ready() -> void:
	add_to_group("progression")
	_checkpoint = snapshot()
	if not auto_load or not load_checkpoint():
		_publish_state(true)


func _process(delta: float) -> void:
	step(delta)


## Kept deterministic so logic can be exercised without graphics or scene assets.
func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _player_recovering():
		return
	_elapsed += delta
	if _notice_remaining > 0.0:
		_notice_remaining = maxf(0.0, _notice_remaining - delta)
		if _notice_remaining == 0.0:
			show_notice("", 0.0)
	match stage:
		Stage.MESSAGE:
			_update_message()
		Stage.PRESENCE:
			if auto_advance_atmosphere and _elapsed >= presence_seconds:
				_set_stage(Stage.POWER_LOSS)
		Stage.POWER_LOSS:
			if auto_advance_atmosphere and _elapsed >= power_loss_seconds:
				_set_stage(Stage.ENCOUNTER)
		Stage.ENCOUNTER:
			if use_timed_encounter_resolution and _elapsed >= encounter_seconds:
				resolve_encounter()


func _player_recovering() -> bool:
	return is_instance_valid(player) and player.has_method("is_recovering") and bool(player.call("is_recovering"))


func prepared() -> bool:
	return warning_heard and has_flashlight and has_keys


func can_interact(kind: StringName) -> bool:
	if _player_recovering():
		return false
	match kind:
		&"phone":
			return stage == Stage.NORMAL
		&"flashlight":
			return stage == Stage.PREPARATION and warning_heard and not has_flashlight
		&"keys":
			return stage == Stage.PREPARATION and warning_heard and not has_keys
		&"exit", &"exit_door":
			return stage == Stage.READY_TO_LEAVE and prepared() and encounter_survived and not departed
	return false


func interact(kind: StringName) -> bool:
	if not can_interact(kind):
		show_notice(interaction_hint(kind))
		return false
	match kind:
		&"phone":
			_set_stage(Stage.MESSAGE)
		&"flashlight", &"keys":
			if kind == &"flashlight":
				has_flashlight = true
				show_notice("Flashlight ready.  F · Switch light")
			else:
				has_keys = true
				show_notice("Car keys.")
			inventory_changed.emit()
			if prepared():
				_set_stage(Stage.PRESENCE)
			else:
				_record_checkpoint()
		&"exit", &"exit_door":
			departed = true
			_set_stage(Stage.COMPLETE)
	return true


func resolve_encounter() -> bool:
	if stage != Stage.ENCOUNTER or _player_recovering():
		return false
	encounter_survived = true
	_set_stage(Stage.READY_TO_LEAVE)
	return true


func _update_message() -> void:
	var end := 0.0
	for index in mara_lines.size():
		end += maxf(0.5, mara_durations[index] if index < mara_durations.size() else 3.5)
		if _elapsed < end:
			_set_subtitle(mara_lines[index])
			return
	warning_heard = true
	_set_stage(Stage.PREPARATION)


func _set_stage(new_stage: int) -> void:
	stage = new_stage
	_elapsed = 0.0
	_set_subtitle(mara_lines[0] if stage == Stage.MESSAGE and not mara_lines.is_empty() else "")
	_publish_state(false)
	_record_checkpoint()


func _publish_state(force_power: bool) -> void:
	var old_power := power_available
	power_available = stage < Stage.POWER_LOSS
	stage_changed.emit(stage)
	if force_power or old_power != power_available:
		power_changed.emit(power_available)
	inventory_changed.emit()


func _set_subtitle(text: String) -> void:
	if subtitle != text:
		subtitle = text
		subtitle_changed.emit(text)


func show_notice(text: String, duration: float = 3.0) -> void:
	notice = text
	_notice_remaining = maxf(0.0, duration) if not text.is_empty() else 0.0
	notice_changed.emit(text)


func objective() -> String:
	match stage:
		Stage.NORMAL: return "A message from Mara"
		Stage.MESSAGE: return ""
		Stage.PREPARATION:
			if not has_flashlight and not has_keys: return "Find the car keys and flashlight"
			return "Find the flashlight" if has_keys else "Find the car keys"
		Stage.PRESENCE: return "Get ready to leave"
		Stage.POWER_LOSS: return "Keep your light close"
		Stage.ENCOUNTER: return "Keep your distance. Find room to move."
		Stage.READY_TO_LEAVE: return "Leave the house. Find Mara."
		Stage.COMPLETE: return "GREYHAVEN\nEnd of the house opening"
	return ""


func interaction_hint(kind: StringName) -> String:
	if kind == &"phone" and warning_heard: return "Mara isn't answering."
	if kind == &"phone" and stage == Stage.MESSAGE: return ""
	if not warning_heard: return "A message from Mara. I should listen."
	if kind == &"exit" or kind == &"exit_door":
		if not has_keys: return "I need my car keys."
		if not has_flashlight: return "The flashlight. I'll need it."
		if not encounter_survived: return "Something's between me and the way out."
	return ""


func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "stage": stage, "warning_heard": warning_heard,
		"has_flashlight": has_flashlight, "has_keys": has_keys,
		"encounter_survived": encounter_survived, "departed": departed}


## Invalid flag types are rejected. Inconsistent milestones are repaired toward a playable state.
func _normalized(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("version")
	if not (version is int or version is float) or float(version) != float(SAVE_VERSION):
		return {}
	for key in ["warning_heard", "has_flashlight", "has_keys", "encounter_survived", "departed"]:
		if not data.get(key) is bool:
			return {}
	var state: Dictionary = data.duplicate(true)
	var saved_stage: Variant = data.get("stage")
	var current: int = Stage.NORMAL
	if (saved_stage is int or saved_stage is float) and is_finite(float(saved_stage)):
		current = int(saved_stage)
	if not bool(state.warning_heard):
		state.has_flashlight = false
		state.has_keys = false
		state.encounter_survived = false
		state.departed = false
		current = Stage.MESSAGE if current == Stage.MESSAGE else Stage.NORMAL
	elif not bool(state.has_flashlight) or not bool(state.has_keys):
		state.encounter_survived = false
		state.departed = false
		current = Stage.PREPARATION
	elif bool(state.encounter_survived):
		current = Stage.COMPLETE if bool(state.departed) else Stage.READY_TO_LEAVE
	else:
		state.departed = false
		if current not in [Stage.PRESENCE, Stage.POWER_LOSS, Stage.ENCOUNTER]:
			current = Stage.PRESENCE
	state.stage = current
	return state


func restore_snapshot(data: Dictionary, notify: bool = true) -> bool:
	var state := _normalized(data)
	if state.is_empty(): return false
	stage = int(state.stage)
	warning_heard = bool(state.warning_heard)
	has_flashlight = bool(state.has_flashlight)
	has_keys = bool(state.has_keys)
	encounter_survived = bool(state.encounter_survived)
	departed = bool(state.departed)
	_elapsed = 0.0
	_checkpoint = snapshot()
	_set_subtitle(mara_lines[0] if stage == Stage.MESSAGE and not mara_lines.is_empty() else "")
	show_notice("", 0.0)
	if notify:
		# Reset the player before a spider receives the repeated Encounter event.
		checkpoint_restored.emit()
		_publish_state(true)
	else:
		power_available = stage < Stage.POWER_LOSS
	return true


func _record_checkpoint() -> void:
	_checkpoint = snapshot()
	if auto_save: save_checkpoint()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func save_checkpoint() -> bool:
	if save_writes_blocked:
		last_save_succeeded = false
		return false
	var previous := _read_json(save_path)
	if not _normalized(previous).is_empty():
		var backup := FileAccess.open(save_path + ".backup", FileAccess.WRITE)
		if backup != null:
			backup.store_string(JSON.stringify(previous))
			backup.close()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	last_save_succeeded = file != null
	if file != null:
		file.store_string(JSON.stringify(snapshot()))
		file.flush()
		last_save_succeeded = file.get_error() == OK
		file.close()
	if not last_save_succeeded:
		show_notice("Checkpoint could not be saved. You can keep playing.", 5.0)
	return last_save_succeeded


func load_checkpoint() -> bool:
	var data := _read_json(save_path)
	var version: Variant = data.get("version")
	if (version is int or version is float) and float(version) != float(SAVE_VERSION):
		save_writes_blocked = true
		show_notice("This checkpoint belongs to another version. It will not be overwritten.", 7.0)
		return false
	if _normalized(data).is_empty():
		data = _read_json(save_path + ".backup")
	if _normalized(data).is_empty(): return false
	return restore_snapshot(data)


func retry_checkpoint() -> void:
	if auto_load and load_checkpoint():
		show_notice("Checkpoint restored.")
		return
	if not restore_snapshot(_checkpoint):
		restart_opening()
	show_notice("Returned to the last milestone.")


func restart_opening() -> void:
	# An explicit new game is the only operation that replaces an incompatible save.
	save_writes_blocked = false
	restore_snapshot({"version": SAVE_VERSION, "stage": Stage.NORMAL,
		"warning_heard": false, "has_flashlight": false, "has_keys": false,
		"encounter_survived": false, "departed": false})
	_record_checkpoint()
