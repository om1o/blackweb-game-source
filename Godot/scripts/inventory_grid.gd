class_name BlackwebInventoryGrid
extends RefCounted
## The 50 cells are the source of truth. Quick slots are references to item kinds,
## not extra copies: changing equipment never duplicates or consumes an item.

const CAPACITY := 50
const QUICK_CAPACITY := 3
const STARTER_EQUIPMENT: Array[StringName] = [&"flashlight", &"knife", &"candy_bar"]

var slots: Array[Dictionary] = []
var equipped: Array[StringName] = []


func _init() -> void:
	reset()


func reset() -> void:
	slots.clear()
	for index in range(CAPACITY):
		slots.append({})
	equipped = STARTER_EQUIPMENT.duplicate()
	add(&"flashlight", 1)
	add(&"knife", 1)
	add(&"candy_bar", 1)


func add(id: StringName, amount: int = 1) -> int:
	if id == &"" or amount <= 0:
		return count(id)
	if not can_add(id, amount):
		return count(id)
	var remaining := amount
	var limit := stack_limit(id)
	for index in range(CAPACITY):
		if remaining <= 0:
			break
		if slots[index].get("id", &"") != id:
			continue
		var room: int = limit - int(slots[index].get("count", 0))
		if room <= 0:
			continue
		var placed := mini(room, remaining)
		slots[index]["count"] = int(slots[index]["count"]) + placed
		remaining -= placed
	for index in range(CAPACITY):
		if remaining <= 0:
			break
		if not slots[index].is_empty():
			continue
		var placed := mini(limit, remaining)
		slots[index] = {"id": id, "count": placed}
		remaining -= placed
	return count(id)


func can_add(id: StringName, amount: int = 1) -> bool:
	if id == &"" or amount <= 0:
		return false
	var room := 0
	var limit := stack_limit(id)
	for cell in slots:
		if cell.is_empty():
			room += limit
		elif cell.get("id", &"") == id:
			room += limit - int(cell.get("count", 0))
		if room >= amount:
			return true
	return false


func remove(id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	var remaining := amount
	for index in range(CAPACITY - 1, -1, -1):
		if slots[index].get("id", &"") != id:
			continue
		var taken := mini(remaining, int(slots[index].get("count", 0)))
		var left: int = int(slots[index]["count"]) - taken
		if left == 0:
			slots[index] = {}
		else:
			slots[index]["count"] = left
		remaining -= taken
		if remaining == 0:
			break
	return true


func count(id: StringName) -> int:
	var total := 0
	for cell in slots:
		if cell.get("id", &"") == id:
			total += int(cell.get("count", 0))
	return total


func occupied_count() -> int:
	var total := 0
	for cell in slots:
		if not cell.is_empty():
			total += 1
	return total


func item_at(index: int) -> StringName:
	if index < 0 or index >= CAPACITY:
		return &""
	return StringName(str(slots[index].get("id", "")))


func equip_cell(cell_index: int, quick_index: int) -> bool:
	if quick_index < 0 or quick_index >= QUICK_CAPACITY:
		return false
	var id := item_at(cell_index)
	if id == &"" or count(id) <= 0 or is_armor(id):
		return false
	var prior := equipped.find(id)
	if prior == quick_index:
		return true
	if prior >= 0:
		equipped[prior] = equipped[quick_index]
	equipped[quick_index] = id
	return true


func quick_item(quick_index: int) -> StringName:
	if quick_index < 0 or quick_index >= QUICK_CAPACITY:
		return &""
	return equipped[quick_index]


func is_equipped(id: StringName) -> bool:
	return equipped.has(id)


func snapshot() -> Array[Dictionary]:
	return slots.duplicate(true)


static func stack_limit(id: StringName) -> int:
	if id in [&"flashlight", &"knife"] or is_armor(id):
		return 1
	if str(id).begins_with("battery_"):
		return 5
	return 10


static func is_armor(id: StringName) -> bool:
	return id in [&"leather_shirt", &"leather_pants", &"leather_hood", &"leather_shoes"]


## Validate into temporary cells so a malformed save cannot partially replace a bag.
func restore_state(cells: Array, quick: Array) -> bool:
	if cells.size() != CAPACITY or quick.size() != QUICK_CAPACITY: return false
	var restored: Array[Dictionary] = []
	for cell in cells:
		if not cell is Dictionary: return false
		if cell.is_empty():
			restored.append({})
			continue
		var id := StringName(str(cell.get("id", "")))
		var amount: Variant = cell.get("count")
		if not _known_item(id) or not (amount is int or amount is float): return false
		if not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or amount < 1 or amount > stack_limit(id): return false
		restored.append({"id": id, "count": int(amount)})
	var restored_quick: Array[StringName] = []
	for value in quick:
		var id := StringName(str(value))
		if not _known_item(id) or is_armor(id) or restored_quick.has(id): return false
		# An exhausted consumable may remain assigned to a quick slot.
		restored_quick.append(id)
	slots = restored
	equipped = restored_quick
	return true


static func _known_item(id: StringName) -> bool:
	if id in [&"flashlight", &"knife", &"candy_bar", &"bandage", &"flare"] or is_armor(id): return true
	var charge := str(id).trim_prefix("battery_")
	return str(id).begins_with("battery_") and charge.is_valid_int() and int(charge) >= 1 and int(charge) <= 100


static func display_name(id: StringName) -> String:
	match id:
		&"flashlight": return "FLASHLIGHT"
		&"knife": return "WORN KNIFE"
		&"candy_bar": return "CANDY BAR"
		&"bandage": return "BANDAGE"
		&"flare": return "FLARE"
	if str(id).begins_with("battery_"):
		return "BATTERY +%s%%" % str(id).trim_prefix("battery_")
	return str(id).replace("_", " ").to_upper()
