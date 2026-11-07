extends Node
signal caption_changed(text: String)
var channel: AudioStreamPlayer
var data: Dictionary = {}
var queue: Array[String] = []
var played: Dictionary = {}
var envelopes: Dictionary = {}
var current_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if FileAccess.file_exists("res://data/boss_voice.json"):
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_voice.json"))
	if FileAccess.file_exists("res://data/boss_voice_envelopes.json"):
		envelopes = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_voice_envelopes.json"))
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
	current_id = ""
	caption_changed.emit("")
	while not queue.is_empty():
		var id: String = queue.pop_front()
		var entry: Dictionary = data[id]
		if not ResourceLoader.exists(str(entry.path)): continue
		channel.stream = load(str(entry.path))
		current_id = id
		played[id] = true
		caption_changed.emit(str(entry.speaker) + ": " + str(entry.text))
		channel.play()
		return

func reset() -> void:
	current_id = ""
	channel.stop()
	queue.clear()
	played.clear()
	caption_changed.emit("")

func mouth_amount() -> float:
	if not channel.playing or not envelopes.has(current_id): return 0.0
	var entry: Dictionary = envelopes[current_id]
	var index := int(channel.get_playback_position()*float(entry.fps))
	return float(entry.samples[mini(index,entry.samples.size()-1)]) if not entry.samples.is_empty() else 0.0
