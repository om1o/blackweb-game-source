extends Node3D
## Original synthesized contact transients. No recovered or external sound assets.
## The encounter controller supplies achieved motion, never requested velocity.

const RATE := 22050
const CONTACT_POSITIONS := [
	Vector3(-0.34, 0.045, -0.24), Vector3(0.34, 0.045, 0.24),
	Vector3(-0.34, 0.045, 0.24), Vector3(0.34, 0.045, -0.24),
]
const PITCH := [0.97, 1.025, 0.99, 1.015]
var _contacts: AudioStreamPlayer3D
var _windup: AudioStreamPlayer3D
var _lunge: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _contact_streams: Array[AudioStreamWAV] = []
var _travel := 0.0
var _contact_index := 0
var _cooldown := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_contacts = AudioStreamPlayer3D.new()
	_contacts.name = "OriginalDryFootContacts"
	_contacts.volume_db = -23.0
	_contacts.unit_size = 1.8
	_contacts.max_distance = 11.0
	_contacts.max_polyphony = 1
	add_child(_contacts)
	for seed_value in [719, 431, 1123, 233]:
		_contact_streams.append(_synthesize(0.072, seed_value, false))
	_windup = AudioStreamPlayer3D.new()
	_windup.name = "OriginalWindupScratch"
	_windup.position = Vector3(0.0, 0.12, -0.22)
	_windup.volume_db = -22.0
	_windup.unit_size = 2.7
	_windup.max_distance = 12.0
	_windup.stream = _synthesize(0.24, 1601, true)
	add_child(_windup)
	_lunge = AudioStreamPlayer3D.new()
	_lunge.name = "OriginalLungeRush"
	_lunge.volume_db = -18.0
	_lunge.max_distance = 12.0
	_lunge.stream = _synthesize_attack(0.24, 1937, false)
	add_child(_lunge)
	_impact = AudioStreamPlayer3D.new()
	_impact.name = "OriginalFleshImpact"
	_impact.volume_db = -17.0
	_impact.max_distance = 10.0
	_impact.stream = _synthesize_attack(0.13, 2341, true)
	add_child(_impact)
	set_meta("audio_provenance", "Original code-synthesized mono contacts, windup scratch, lunge rush, and flesh impact; no external recordings, music, or vocal samples.")

func advance_motion(distance: float, delta: float, grounded: bool, enabled: bool) -> void:
	if not enabled or get_tree().paused or not is_visible_in_tree():
		silence()
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var speed := distance / maxf(delta, 0.0001)
	if not grounded or speed < 0.12:
		_travel = 0.0
		_contacts.stop()
		return
	# Sparse audible contact groups imply eight legs without eight competing sounds.
	var spacing := lerpf(0.42, 0.60, clampf((speed - 1.65) / 3.95, 0.0, 1.0))
	_travel += minf(distance, 0.30)
	if _travel < spacing or _cooldown > 0.0:
		return
	_travel = fmod(_travel, spacing)
	_cooldown = 0.105
	var index := _contact_index % _contact_streams.size()
	_contacts.position = CONTACT_POSITIONS[index]
	_contacts.pitch_scale = PITCH[index]
	_contacts.stream = _contact_streams[index]
	_contacts.play()
	_contact_index += 1

func play_windup() -> void:
	if get_tree().paused or not is_visible_in_tree(): return
	_contacts.stop()
	_travel = 0.0
	_windup.play()

func play_lunge() -> void:
	if get_tree().paused or not is_visible_in_tree(): return
	_lunge.play()

func play_impact() -> void:
	if get_tree().paused or not is_visible_in_tree(): return
	_impact.play()

func silence() -> void:
	_travel = 0.0
	_cooldown = 0.0
	if is_instance_valid(_contacts): _contacts.stop()
	if is_instance_valid(_windup): _windup.stop()
	if is_instance_valid(_lunge): _lunge.stop()
	if is_instance_valid(_impact): _impact.stop()

func _synthesize(duration: float, seed_value: int, scratching: bool) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var count := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var filtered := 0.0
	for index in count:
		var time := float(index) / RATE
		var noise := random.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.24)
		var dry_noise := noise - filtered
		var envelope: float
		if scratching:
			# Three short grain clusters: a brief surface drag, with no low growl.
			var body := pow(sin(PI * time / duration), 2.0)
			var grains := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * 17.0 * time), 2.0)
			envelope = body * grains * 0.45
		else:
			var primary := minf(time * 1800.0, 1.0) * exp(-105.0 * time)
			var second_time := maxf(0.0, time - 0.019)
			var secondary := minf(second_time * 1800.0, 1.0) * exp(-135.0 * second_time) * 0.38
			envelope = (primary + secondary) * 0.60
		var sample := clampf(dry_noise * envelope, -0.8, 0.8)
		bytes.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream

func _synthesize_attack(duration: float, seed_value: int, impact: bool) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var count := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var low := 0.0
	for index in range(count):
		var time := float(index) / RATE
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.15)
		var envelope := exp(-48.0 * time) if impact else pow(sin(PI * time / duration), 1.4)
		var sample := (low * 0.55 + (noise - low) * (0.22 if impact else 0.48)) * envelope
		bytes.encode_s16(index * 2, int(clampf(sample, -0.8, 0.8) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream
