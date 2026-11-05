extends SceneTree
## Asset-independent campaign envelope and inventory transaction regressions.
## Writes only a unique QA save path; never opens the user's campaign file.

const Campaign = preload("res://scripts/tutorial_campaign.gd")
const Inventory = preload("res://scripts/inventory_grid.gd")
var results: Array[Dictionary] = []
var failures := 0
var test_path := ""

func _initialize() -> void:
	call_deferred("_run")

func check(passed: bool, description: String) -> void:
	results.append({"passed": passed, "description": description})
	if not passed:
		failures += 1
		push_error(description)

func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

func _run() -> void:
	test_path = "user://qa_campaign_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var campaign := Campaign.new()
	campaign.save_path = test_path
	check(not campaign.load_state(), "A missing campaign save does not invent progress")
	check(campaign.collect_cash("wallet_entry", 45) and campaign.wallet == 45, "An unclaimed wallet awards its cash once")
	check(not campaign.collect_cash("wallet_entry", 45) and campaign.wallet == 45, "Reopening the same wallet cannot award cash again")
	check(not campaign.collect_cash("", 10) and not campaign.collect_cash("bad", 0) and not campaign.collect_cash("bad", -1), "Empty claims and nonpositive cash rewards are rejected")
	check(not campaign.try_unlock("0000", true) and not campaign.vault_unlocked, "An incorrect code cannot unlock the vault")
	check(not campaign.try_unlock(Campaign.VAULT_CODE, false) and not campaign.vault_unlocked, "Knowing the code without the house key cannot unlock the vault")
	check(campaign.try_unlock(Campaign.VAULT_CODE, true) and campaign.vault_unlocked, "The correct code and key unlock the vault")
	check(campaign.try_unlock(Campaign.VAULT_CODE, true) and campaign.wallet == 45, "Repeating a successful unlock does not duplicate cash")
	campaign.code_found = true
	campaign.intro_seen = true

	var bag := Inventory.new()
	var before_quick := bag.equipped.duplicate()
	for id in Campaign.ARMOR:
		check(Inventory.stack_limit(id) == 1 and bag.add(id) == 1, "%s occupies its own inventory cell" % id)
	check(bag.occupied_count() == 7 and bag.slots.size() == 50, "The four armor pieces use four of fifty cells beside the three starters")
	for index in range(3, 7):
		check(not bag.equip_cell(index, 0), "Armor cell %d cannot replace a quick-slot tool" % index)
	check(bag.equipped == before_quick and bag.equipped.size() == 3, "Armor ownership preserves exactly three quick slots")
	var cells := bag.snapshot()
	var quick := bag.equipped.duplicate()
	var restored := Inventory.new()
	check(restored.restore_state(cells, quick) and restored.snapshot() == cells, "Inventory restore conserves every item and stack")
	check(restored.restore_state(cells, quick) and restored.occupied_count() == 7, "Restoring the same inventory twice replaces rather than duplicates it")
	var invalid_cells := cells.duplicate(true)
	invalid_cells[3].count = 2
	check(not restored.restore_state(invalid_cells, quick) and restored.snapshot() == cells, "An armor stack larger than one rejects the whole inventory transaction")
	invalid_cells = cells.duplicate(true)
	invalid_cells[0].count = 0
	check(not restored.restore_state(invalid_cells, quick), "A nonempty item cell cannot contain zero items")
	invalid_cells = cells.duplicate(true)
	invalid_cells[0].count = 1.5
	check(not restored.restore_state(invalid_cells, quick), "Fractional item quantities are rejected")
	invalid_cells = cells.duplicate(true)
	invalid_cells[0].id = "unknown_item"
	check(not restored.restore_state(invalid_cells, quick), "Unknown saved item kinds are rejected")
	var invalid_quick: Array = ["leather_shirt", "knife", "candy_bar"]
	check(not restored.restore_state(cells, invalid_quick), "Saved armor cannot enter quick slots")
	invalid_quick = ["knife", "knife", "candy_bar"]
	check(not restored.restore_state(cells, invalid_quick), "Duplicate saved quick-slot assignments are rejected")
	invalid_quick = ["flashlight", "knife", "candy_bar", "bandage"]
	check(not restored.restore_state(cells, invalid_quick), "A saved fourth quick slot is rejected")
	bag.remove(&"candy_bar")
	check(restored.restore_state(bag.snapshot(), quick) and restored.count(&"candy_bar") == 0, "An exhausted consumable assignment restores without recreating the consumed item")
	bag.restore_state(cells, quick)

	var armor := {"shirt": "leather_shirt", "pants": "leather_pants", "hood": "leather_hood", "shoes": "leather_shoes"}
	var survival := {"version": 1, "inventory": cells, "quick_slots": quick,
		"armor": armor, "health": 47.0, "battery": 13.0, "selected_quick_index": 1}
	var story := {"version": 1, "stage": 2, "warning_heard": true,
		"has_flashlight": true, "has_keys": true, "encounter_survived": false,
		"departed": false, "vault_unlocked": true}
	var world := {"seed": 123, "pickups": {"SupplyBattery": true}, "storage": {}}
	for id in Campaign.ARMOR: campaign.claimed[str(id)] = true
	check(campaign.save_state(story, survival, world), "Campaign atomically saves story, items, armor, wallet and world in one record")
	check(FileAccess.file_exists(test_path) and not FileAccess.file_exists(test_path + ".tmp"), "Successful commit leaves a primary record and no pending temporary file")
	var loaded := Campaign.new()
	loaded.save_path = test_path
	check(loaded.load_state() and loaded.wallet == 45 and loaded.vault_unlocked and loaded.code_found and loaded.intro_seen, "Campaign reload preserves wallet, unlock, clue and intro state")
	var expected_story: Dictionary = JSON.parse_string(JSON.stringify(story))
	var expected_world: Dictionary = JSON.parse_string(JSON.stringify(world))
	check(loaded.loaded.story == expected_story and loaded.loaded.world == expected_world and loaded.loaded.survival.armor == armor, "The same campaign record round-trips story, world claims and armor slots")
	check(restored.restore_state(loaded.loaded.survival.inventory, loaded.loaded.survival.quick_slots) and restored.occupied_count() == 7, "Reloaded inventory contains exactly the saved owned supplies and armor")
	check(not loaded.collect_cash("wallet_entry", 45) and loaded.wallet == 45, "A wallet remains claimed after restarting from disk")
	check(loaded.claimed.has("leather_shirt") and loaded.claimed.has("leather_shoes"), "Vault armor claim flags persist with the owned inventory")
	var base := loaded.loaded.duplicate(true)
	for bad_cash in [-1, 0.5, "45", 1000000000]:
		var invalid := base.duplicate(true)
		invalid.wallet = bad_cash
		check(not loaded._valid(invalid), "Invalid wallet value %s is rejected" % str(bad_cash))
	var cap := Campaign.new()
	cap.wallet = 999999998
	check(cap.collect_cash("limit", 10) and cap.wallet == 999999999, "Cash awards clamp to the maximum wallet amount")

	# Second commit differs across all coupled state, so a backup must be a
	# complete previous record rather than a mixture of new and old fields.
	campaign.collect_cash("wallet_vault", 17)
	var next_survival := survival.duplicate(true)
	bag.remove(&"candy_bar")
	bag.add(&"bandage", 2)
	next_survival.inventory = bag.snapshot()
	next_survival.health = 55.0
	var next_world := world.duplicate(true)
	next_world.seed = 456
	check(campaign.save_state(story, next_survival, next_world) and FileAccess.file_exists(test_path + ".backup"), "A second commit retains the preceding complete record as backup")
	loaded = Campaign.new()
	loaded.save_path = test_path
	check(loaded.load_state() and loaded.wallet == 62 and float(loaded.loaded.survival.health) == 55.0 and int(loaded.loaded.world.seed) == 456, "Primary reload selects the entire latest commit")
	write_text(test_path, "{interrupted write")
	var recovered := Campaign.new()
	recovered.save_path = test_path
	check(recovered.load_state() and recovered.wallet == 45 and float(recovered.loaded.survival.health) == 47.0 and int(recovered.loaded.world.seed) == 123, "Corrupt-primary recovery selects one complete previous backup")
	check(recovered.save_state(story, survival, world), "Recovered state can be saved as a new valid primary")
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path + ".backup"))
	check(recovered._valid(backup), "Saving recovered state preserves a valid backup instead of copying a corrupt primary over it")
	var invalid_inner := base.duplicate(true)
	invalid_inner.story.has_keys = "yes"
	write_text(test_path, JSON.stringify(invalid_inner))
	check(recovered.load_state() and recovered.wallet == 45 and recovered.loaded.story.has_keys == true, "An invalid inner story recovers the complete valid backup")
	invalid_inner = base.duplicate(true)
	invalid_inner.survival.inventory[3].count = 2
	write_text(test_path, JSON.stringify(invalid_inner))
	check(recovered.load_state() and int(recovered.loaded.survival.inventory[3].count) == 1, "An invalid inner inventory recovers the complete valid backup")
	invalid_inner = base.duplicate(true)
	invalid_inner.survival.flashlight_on = "yes"
	write_text(test_path, JSON.stringify(invalid_inner))
	check(recovered.load_state() and not recovered.loaded.survival.has("flashlight_on"), "A malformed optional flashlight flag cannot bypass backup recovery")
	invalid_inner = base.duplicate(true)
	invalid_inner.survival.armor.extra = "leather_shirt"
	write_text(test_path, JSON.stringify(invalid_inner))
	check(recovered.load_state() and not recovered.loaded.survival.armor.has("extra"), "Unknown armor slots cannot bypass backup recovery")
	DirAccess.remove_absolute(test_path)
	check(recovered.load_state() and recovered.wallet == 45 and recovered.vault_unlocked, "A missing primary still recovers its complete backup")

	var future := base.duplicate(true)
	future.version = 999
	var future_text := JSON.stringify(future)
	write_text(test_path, future_text)
	var protected := Campaign.new()
	protected.save_path = test_path
	check(not protected.load_state() and protected.writes_blocked, "An unknown campaign version is protected instead of silently downgraded from backup")
	check(not protected.save_state(story, survival, world) and FileAccess.get_file_as_string(test_path) == future_text, "Protected future-version data cannot be overwritten by autosave")
	protected.reset()
	check(protected.wallet == 0 and not protected.vault_unlocked and not protected.code_found and not protected.intro_seen and protected.claimed.is_empty() and protected.loaded.is_empty() and not protected.writes_blocked, "An explicit new game clears wallet, unlock, intro, claims and write protection")
	check(protected.save_state(story, survival, world), "Explicit new-game reset permits a fresh campaign commit")
	for suffix in ["", ".backup", ".tmp"]:
		var path: String = test_path + str(suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/tutorial-campaign-tests.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"checks": results.size(), "failures": failures, "results": results}, "  "))
		file.close()
	print("Tutorial campaign: %d checks, %d failures" % [results.size(), failures])
	quit(0 if failures == 0 else 1)
