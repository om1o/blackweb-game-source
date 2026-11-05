class_name BlackwebTutorialCampaign
extends RefCounted
## One durable record joins story, owned items, cash and one-time loot claims.
const VAULT_CODE := "0417"
const ARMOR := [&"leather_shirt", &"leather_pants", &"leather_hood", &"leather_shoes"]
const Inventory = preload("res://scripts/inventory_grid.gd")
var save_path := "user://blackweb_campaign_v2.json"
var wallet := 0
var code_found := false
var vault_unlocked := false
var intro_seen := false
var claimed: Dictionary = {}
var loaded: Dictionary = {}
var writes_blocked := false

func reset() -> void:
	wallet = 0
	code_found = false
	vault_unlocked = false
	intro_seen = false
	claimed.clear()
	loaded.clear()
	writes_blocked = false

func collect_cash(id: String, amount: int) -> bool:
	if id.is_empty() or amount <= 0 or claimed.has(id): return false
	wallet = mini(999999999, wallet + amount)
	claimed[id] = true
	return true

func try_unlock(code: String, has_key: bool) -> bool:
	if not has_key or code != VAULT_CODE: return false
	vault_unlocked = true
	return true

func load_state() -> bool:
	var parsed: Variant = _read_record(save_path)
	if not _valid(parsed):
		if parsed is Dictionary and parsed.get("version", 2) != 2:
			writes_blocked = true
			return false
		if FileAccess.file_exists(save_path + ".backup"):
			parsed = _read_record(save_path + ".backup")
		if not _valid(parsed): return false
	loaded = parsed
	wallet = int(parsed.wallet)
	code_found = parsed.code_found
	vault_unlocked = parsed.vault_unlocked
	intro_seen = parsed.intro_seen
	claimed = parsed.claimed.duplicate(true)
	return true

func save_state(story: Dictionary, survival: Dictionary, world: Dictionary) -> bool:
	if writes_blocked: return false
	var data := {"version": 2, "wallet": wallet, "code_found": code_found,
		"vault_unlocked": vault_unlocked, "intro_seen": intro_seen,
		"claimed": claimed.duplicate(true), "story": story, "survival": survival, "world": world}
	if not _valid(data): return false
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var valid := file.get_error() == OK
	file.close()
	if not valid: return false
	# Keep the previous complete record until the new temporary file is flushed.
	if FileAccess.file_exists(save_path):
		var previous: Variant = _read_record(save_path)
		if _valid(previous) and DirAccess.copy_absolute(save_path, save_path + ".backup") != OK: return false
	if DirAccess.rename_absolute(temp, save_path) != OK: return false
	loaded = data
	return true

func _read_record(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return json.data

func _valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 2: return false
	var cash: Variant = data.get("wallet")
	if not (cash is int or cash is float) or not is_finite(float(cash)) or float(cash) != floorf(float(cash)) or cash < 0 or cash > 999999999: return false
	for key in ["code_found", "vault_unlocked", "intro_seen"]:
		if not data.get(key) is bool: return false
	for key in ["claimed", "story", "survival", "world"]:
		if not data.get(key) is Dictionary: return false
	for value in data.claimed.values():
		if not value is bool or not value: return false
	var story: Dictionary = data.story
	if story.get("version") != 1: return false
	if story.has("vault_unlocked") and not story.vault_unlocked is bool: return false
	for key in ["warning_heard", "has_flashlight", "has_keys", "encounter_survived", "departed"]:
		if not story.get(key) is bool: return false
	var stage: Variant = story.get("stage")
	if not (stage is int or stage is float) or not is_finite(float(stage)) or float(stage) != floorf(float(stage)) or stage < 0 or stage > 7: return false
	var survival: Dictionary = data.survival
	if survival.get("version") != 1: return false
	if survival.has("flashlight_on") and not survival.flashlight_on is bool: return false
	if not survival.get("inventory") is Array or not survival.get("quick_slots") is Array or not survival.get("armor") is Dictionary: return false
	var inventory := Inventory.new()
	if not inventory.restore_state(survival.inventory, survival.quick_slots): return false
	for key in ["health", "battery", "selected_quick_index"]:
		var number: Variant = survival.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or number < 0 or number > (2 if key == "selected_quick_index" else 100): return false
	if float(survival.selected_quick_index) != floorf(float(survival.selected_quick_index)): return false
	if survival.armor.size() != 4: return false
	for slot in ["shirt", "pants", "hood", "shoes"]:
		if not survival.armor.has(slot): return false
		var id := StringName(str(survival.armor[slot]))
		if id != &"" and (id != StringName("leather_" + slot) or inventory.count(id) <= 0): return false
	var world: Dictionary = data.world
	if world.has("seed"):
		var seed_value: Variant = world.seed
		if not (seed_value is int or seed_value is float) or not is_finite(float(seed_value)) or float(seed_value) != floorf(float(seed_value)) or absf(float(seed_value)) > 9007199254740991.0: return false
	if not world.get("pickups", {}) is Dictionary or not world.get("storage", {}) is Dictionary: return false
	for taken in world.get("pickups", {}).values():
		if not taken is bool: return false
	for fixture in world.get("storage", {}).values():
		if not fixture is Dictionary: return false
		for flag in ["rolled", "searched", "clue_shown"]:
			if not fixture.get(flag, false) is bool: return false
		if not fixture.get("pending", []) is Array: return false
		for loot in fixture.get("pending", []):
			if not loot is Dictionary or str(loot.get("item", "")) not in ["battery", "bandage", "flare"]: return false
			var amount: Variant = loot.get("amount", 1)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or amount < 1 or amount > 1000: return false
	return true
