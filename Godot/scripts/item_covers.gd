extends RefCounted
## Offline renders of the same meshes used by Luke. No per-cell 3D viewports.
const ROOT := "res://assets/generated/item_covers/"
const IDS := [&"flashlight", &"knife", &"candy_bar", &"battery", &"bandage", &"flare", &"leather_shirt", &"leather_pants", &"leather_hood", &"leather_shoes"]
static var _cache: Dictionary = {}

static func texture(item_id: StringName) -> Texture2D:
	var id := &"battery" if str(item_id).begins_with("battery_") else item_id
	if id not in IDS: return null
	if not _cache.has(id):
		var path := ROOT + str(id) + ".png"
		if ResourceLoader.exists(path):
			_cache[id] = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			_cache[id] = ImageTexture.create_from_image(image) if image != null else null
		else: return null
	return _cache[id]
