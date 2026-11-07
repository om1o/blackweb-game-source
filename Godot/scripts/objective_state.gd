extends RefCounted
## Presentation only: story flags, not timers, determine completion.
static func describe(p: Node, code_found: bool = false) -> Dictionary:
	var result := {"title":"Answer Mica's call", "hint":"The phone is ringing in the entry.", "step":0, "target_room":0, "kind":"phone", "urgent":false}
	match p.stage:
		1: result.merge({"title":"Listen to Mica", "hint":"Stay on the line.", "target_room":-1}, true)
		2:
			result.step = 1
			if not p.has_keys: result.merge({"title":"Find the vault key", "hint":"Search the record-room shelf.", "target_room":2, "kind":"search"}, true)
			elif not p.has_flashlight: result.merge({"title":"Find spare flashlight cells", "hint":"Check the table in the entry.", "target_room":0, "kind":"search"}, true)
			elif p.requires_vault and not p.vault_unlocked:
				result.merge({"title":"Open the vault" if code_found else "Find Mica's hidden note", "hint":"Use the key and the code you found." if code_found else "She mentioned a plant in the record room.", "target_room":4 if code_found else 2, "kind":"vault" if code_found else "search"}, true)
			elif p.requires_vault and not p.has_exit_keys: result.merge({"title":"Recover your exit keys", "hint":"Search inside the vault.", "target_room":4, "kind":"search"}, true)
			else: result.merge({"title":"Check the house", "hint":"Gather supplies before you leave.", "target_room":-1}, true)
		3,4,5:
			result.merge({"step":2, "target_room":-1, "kind":"threat", "urgent":true}, true)
			if p.stage == 3: result.merge({"title":"Listen for movement", "hint":"Something moved in the supply room."}, true)
			elif p.stage == 4: result.merge({"title":"Keep your light ready", "hint":"The power is out. Watch the doorways."}, true)
			else: result.merge({"title":"Survive the encounter", "hint":"Dodge the lunge. Strike during its recovery."}, true)
		6:
			result.step = 3
			if p.requires_vault and not p.has_exit_keys: result.merge({"title":"Recover your exit keys", "hint":"The keys are inside the vault.", "target_room":4, "kind":"search"}, true)
			elif p.requires_vault and not p.exit_web_cleared: result.merge({"title":"Cut the silk off the lock", "hint":"Equip your knife. Strike the webbed front lock.", "target_room":0, "kind":"exit"}, true)
			else: result.merge({"title":"Leave the house", "hint":"Unlock the front door. Find Mica.", "target_room":0, "kind":"exit"}, true)
		7: result.merge({"title":"House opening complete", "hint":"Greyhaven lies ahead.", "step":4, "target_room":-1}, true)
	return result
