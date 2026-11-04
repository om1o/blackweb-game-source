class_name BlackwebItemAudio
extends Node
## Small original synthesized Foley cues for starter item actions.

const RATE := 22050
const CUE_DURATION := {
	&"switch": 0.065,
	&"flicker": 0.048,
	&"knife_swing": 0.23,
	&"knife_hit": 0.11,
	&"unwrap": 0.27,
	&"eat": 0.23,
}

var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _voice_index := 0

func _ready() -> void:
	for index in range(3):
		var voice := AudioStreamPlayer.new()
		voice.name = "ItemCue%d" % index
		voice.volume_db = -15.0
		add_child(voice)
		_voices.append(voice)
	for id in CUE_DURATION:
		_streams[id] = _synthesize(id, float(CUE_DURATION[id]))
	set_meta("audio_provenance", "Original code-synthesized mono item cues; no external recordings or voice samples.")

func play_cue(id: StringName) -> void:
	if not _streams.has(id) or get_tree().paused: return
	var voice := _voices[_voice_index % _voices.size()]
	_voice_index += 1
	voice.stream = _streams[id]
	voice.volume_db = -22.0 if id == &"flicker" else (-18.0 if id == &"switch" else -15.0)
	voice.play()

func silence() -> void:
	for voice in _voices:
		if is_instance_valid(voice): voice.stop()

func _synthesize(id: StringName, duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2319 + str(id).hash()
	var count := maxi(1, roundi(duration * RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var low := 0.0
	for index in range(count):
		var t := float(index) / RATE
		var phase := t / duration
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.12)
		var high := noise - low
		var envelope := pow(sin(PI * phase), 1.5)
		var sample := 0.0
		match id:
			&"switch", &"flicker":
				var click := exp(-95.0 * t) + 0.45 * exp(-120.0 * maxf(0.0, t - 0.025))
				sample = (high * 0.7 + sin(TAU * 720.0 * t) * 0.18) * click
			&"knife_swing":
				sample = high * envelope * (0.24 + 0.45 * phase)
			&"knife_hit":
				sample = (low * 0.62 + high * 0.27) * exp(-42.0 * t)
			&"unwrap":
				var crinkle := 0.35 + 0.65 * absf(sin(TAU * 26.0 * t))
				sample = high * envelope * crinkle * 0.44
			&"eat":
				sample = (low * 0.46 + high * 0.14) * envelope * (0.6 + 0.4 * sin(TAU * 11.0 * t))
		data.encode_s16(index * 2, roundi(clampf(sample, -0.8, 0.8) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream
