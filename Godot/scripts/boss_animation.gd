extends RefCounted
## Bind the real Blender-authored skin/actions to the shared combat clock.
## Missing clips are an import failure, never replaced with a static placeholder.
static func install(_visual: Node3D, player: AnimationPlayer, attacks: Array) -> int:
	if player == null: return 0
	var source: Dictionary = {}
	for key: String in player.get_animation_list():
		var clean := key.get_slice("/",key.get_slice_count("/")-1)
		clean = clean.get_slice("|",clean.get_slice_count("|")-1)
		source[clean] = player.get_animation(key).duplicate(true)
	var base := AnimationLibrary.new()
	for key in ["idle","walk","death"]:
		if not source.has(key): continue
		var clip: Animation = source[key]
		clip.loop_mode = Animation.LOOP_LINEAR if key != "death" else Animation.LOOP_NONE
		base.add_animation(key,clip)
	var combat := AnimationLibrary.new()
	var count := 0
	for data: Dictionary in attacks:
		if not source.has(str(data.id)):
			push_error("Missing authored Smiling Spider animation: " + str(data.id))
			continue
		var clip: Animation = source[str(data.id)]
		var duration := float(data.tell)+float(data.active)+float(data.recover)
		var ratio := duration/maxf(.001,clip.length)
		for track in clip.get_track_count():
			for index in clip.track_get_key_count(track):
				clip.track_set_key_time(track,index,clip.track_get_key_time(track,index)*ratio)
		clip.length = duration
		clip.loop_mode = Animation.LOOP_NONE
		combat.add_animation(str(data.id),clip)
		count += 1
	for key in player.get_animation_library_list(): player.remove_animation_library(key)
	player.add_animation_library("",base)
	player.add_animation_library("boss",combat)
	player.play("idle")
	player.advance(0.0)
	return count
