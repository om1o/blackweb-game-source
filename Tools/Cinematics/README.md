# Greyhaven arrival cinematic

The release opening is a 42-second **full-motion animation rendered from Godot 3D**, not the earlier artwork sequence. Luke walks home after his maintenance shift, notices the web-covered town, recoils from a crossing spider, looks around, calls for Mica and approaches his opening front door. The editable set and animation choreography are in `Godot/scripts/town_cinematic.gd`. The game plays the rendered movie to avoid rendering a second live environment on the player's GPU.

## Sources and reproducibility

- Luke: existing Microsoft Rocketbox MIT-licensed character, idle/walk clips and facial skeleton; see `Docs/LukeAsset.md`. Authored head/spine/arm reactions and a jaw envelope derived from the actual speech supplement those clips. This is basic jaw articulation, not phoneme-perfect facial capture.
- Town: original modular geometry; existing recovered brick/concrete textures, existing original Blender web meshes, TextureCan CC0 web material and the game's existing spider model. Runtime dependencies retain their existing licenses/provenance. No new marketplace purchases or Higgsfield generations were submitted.
- Historical artwork: built-in imagegen outputs in `Art/` were rejected as the final intro direction. They are retained only as editable concept references, and do not appear in the released movie.
- Speech: `onnx-community/Kokoro-82M-v1.0-ONNX`, fp32 CPU, `am_michael` and `af_heart`. Scripts and timings are in `Audio/provenance.json`; independent Whisper transcription is in `Audio/transcription-review.json`. Whisper spells Mica as Micah; the complete spoken line is retained.
- Ambience: original deterministic wind/static noise, footsteps timed to the walking segments and latch synthesis in `GenerateTownAudio.mjs`.
- Encode: FFmpeg with libtheora / libvorbis; 1280×720, 30 fps. Windows build from [Gyan](https://www.gyan.dev/ffmpeg/builds/), a provider linked by [FFmpeg](https://www.ffmpeg.org/download.html). The build executable is external to the game.
- Playback follows [Godot VideoStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html). Dialogue volume applies, captions follow the video clock, Enter/Esc/Space skips, the paused house cannot ring or advance, and 3D rendering is suspended until completion.

Run `node Tools/Cinematics/GenerateTownAudio.mjs` with cached Kokoro dependencies under `BLACKWEB_VOICE_SCRATCH` (default `D:/BlackwebVoiceScratch`); use `--reuse-voices` when only remixing existing takes. Render with Godot `--path Godot --resolution 1280x720 --write-movie D:/CodexTemp/Blackweb-TownIntro/town-motion.avi --fixed-fps 30 --disable-vsync --script res://tools/render_town_movie.gd`. Set `FFMPEG_PATH` to a full FFmpeg executable and run `node Tools/Cinematics/EncodeTownMotion.mjs`. `BLACKWEB_CINEMATIC_SCRATCH` controls temporary audio/video (default `D:/CodexTemp/Blackweb-TownIntro`). Run `VerifyTownVoices.mjs` for transcription. Native playback QA must pass before publishing. The old `RenderTownIntro.mjs` renders only an external rejected-artwork preview and cannot overwrite the game movie.

For direct 3D authoring QA use `res://tests/town_scene_tests.gd` or `res://tests/town_film_tests.gd -- --live-3d`. The normal playback test exercises the encoded movie, audio output, natural finish and real input skip. The source scene uses [Godot skeletal posing](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html) and [AnimationPlayer seeking](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html) for deterministic 30 fps authoring.

## Artwork briefs (summaries, not verbatim prompt transcripts)

1. **01-shift.png** — cinematic realistic first-person old sedan at a maintenance depot after a night shift; work-worn hands, dashboard, maintenance badge, grounded clothing; quiet before the infestation reveal.
2. **02-town.png** — same driver's windshield perspective down Greyhaven's main street at night; shops, abandoned cars and streetlights visibly cocooned in dense spider silk across the whole town; wet asphalt, restrained cold light, empty sidewalks.
3. **03-blocked-road.png** — pedestrian perspective on a residential lane blocked by a fallen streetlight and dense webs, car behind the viewer, a plausible walkable route onward; coherent wet-night lighting.
4. **04-home.png** — compact single-story brick home, warm ajar front door, Mica's blue car parked outside, webbed neighboring homes, original survival-horror atmosphere.

All four original tool outputs were visually inspected as concepts. The final animated movie is built from the 3D scene, with no image pans from these PNGs. Its cut through black enters the existing playable house. The exterior set is a compact original cinematic environment, not an explorable extension of the tutorial map.
