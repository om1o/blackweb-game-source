extends AudioStreamPlayer
## Two original restrained interface ticks. No background score.
var _hover: AudioStreamWAV
var _select: AudioStreamWAV
var _last_tick := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = &"Master"
	volume_db = -25.0
	_hover = _tick(.035, 380.0)
	_select = _tick(.075, 235.0)

func tick(confirm: bool = false) -> void:
	if not confirm and Time.get_ticks_msec() - _last_tick < 95: return
	_last_tick = Time.get_ticks_msec()
	stream = _select if confirm else _hover
	play()

func _tick(seconds: float, frequency: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var envelope := minf(t * 700.0, 1.0) * pow(1.0 - float(i) / count, 3)
		var value := (sin(TAU * frequency * t) * .7 + sin(TAU * frequency * 2.05 * t) * .18) * envelope * .16
		data.encode_s16(i * 2, int(value * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = data
	return sound
