extends Node
signal caption_changed(text: String)
var channel: AudioStreamPlayer
var data: Dictionary = {}
var queue: Array[String] = []
var played: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if FileAccess.file_exists("res://data/boss_voice.json"):
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_voice.json"))
	channel = AudioStreamPlayer.new()
	channel.bus = &"Dialogue"
	channel.volume_db = -1.0
	add_child(channel)
	channel.finished.connect(_next)

func say(id: String) -> void:
	if not data.has(id) or played.has(id) or queue.has(id): return
	queue.append(id)
	if not channel.playing: _next()

func _next() -> void:
	caption_changed.emit("")
	while not queue.is_empty():
		var id: String = queue.pop_front()
		var entry: Dictionary = data[id]
		if not ResourceLoader.exists(str(entry.path)): continue
		channel.stream = load(str(entry.path))
		played[id] = true
		caption_changed.emit(str(entry.speaker) + ": " + str(entry.text))
		channel.play()
		return

func reset() -> void:
	channel.stop()
	queue.clear()
	played.clear()
	caption_changed.emit("")
