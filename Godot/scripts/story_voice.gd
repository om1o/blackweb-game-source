extends Node
## Optional discoveries speak after the reader closes, never over Mica's call.
var progression: Node
var soundscape: Node
var _voice: AudioStreamPlayer
var _queue: Array[String] = []
var _played: Dictionary = {}
var _data: Dictionary = {}
var _caption := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var path := "res://data/story_voice.json"
	if FileAccess.file_exists(path): _data = JSON.parse_string(FileAccess.get_file_as_string(path))
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Dialogue"
	_voice.volume_db = -1.0
	add_child(_voice)
	_voice.finished.connect(func():
		if progression.subtitle == _caption: progression._set_subtitle(""))
	progression.checkpoint_restored.connect(reset)

func reset() -> void:
	_voice.stop()
	_queue.clear()
	_played.clear()

func enqueue(id: String) -> void:
	if not _data.has(id) or _played.has(id) or _queue.has(id): return
	_queue.append(id)

func _process(_delta: float) -> void:
	if _queue.is_empty() or _voice.playing or not progression.warning_heard or progression.stage == progression.Stage.MESSAGE: return
	if progression.player.is_recovering() or not progression.player.active: return
	for channel in [soundscape._mara_warning,soundscape._phone_reply,soundscape._web_voice]:
		if channel.playing: return
	var id: String = _queue.pop_front()
	var entry: Dictionary = _data[id]
	if not ResourceLoader.exists(entry.path): return
	_played[id] = true
	_voice.stream = load(entry.path)
	_caption = "Luke: " + str(entry.text)
	progression._set_subtitle(_caption)
	_voice.play()
