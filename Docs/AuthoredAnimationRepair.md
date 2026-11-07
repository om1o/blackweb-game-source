# Authored animation repair — 7 November 2026

The previous slash mixed a generated skeletal motion with a second procedural arm swing. The player now uses free authored Quaternius motion, retargeted to the replacement Microsoft Rocketbox character. PINOC's motion library and Meshy's existing-model inventory were checked; neither is being presented as the creator of these downloaded assets. No purchase or paid generation was used for this repair.

## Runtime changes

- A single 0.95-second knife action, with one four-damage hit at 0.28 seconds and a one-second cooldown. The prop remains fixed in the hand. Movement permits an upper-body attack; a stationary attack includes the legs and torso.
- Authored walk, jog, crouch, jump and hit-reaction poses. Layer blending reconstructs child positions from their parents, preventing the arm and spine stretching found during native testing.
- Ordinary idle/walk/jog use the already baked AnimationPlayer tracks. Runtime retargeting is reserved for transitions and additional poses, avoiding a duplicate full-skeleton solve during normal locomotion.
- Male_Adult_02 replaces the previous character. The Blender conversion bakes the centimetre-scale armature into metre coordinates before export. Original weights and finger axes are preserved. The source's broken overlay hair cards are omitted in favor of its textured scalp. Armor discovery supports the imported rig hierarchy.
- Six licensed splash frames, droplet particles and a four-variant blood atlas. Effects reuse four emitters, four splash cards, four audio players and eight floor marks. Maximum simultaneous droplets: 96. Spray lasts 0.64 seconds; floor marks fade and retire after 35 seconds. No effect shadows or lights are added.

## Sources and rebuilding

See [asset provenance](ASSET_PROVENANCE.md) for official source links, credits and licenses. Original acquisition hashes are recorded beside the assets and inside `authored_motion_samples.json`.

1. Import the free Quaternius Standard `Unreal-Godot/UAL1_Standard.glb` with Blender and run `Tools/Assets/sample_authored_motion.py` with the source GLB and output JSON arguments.
2. Download the pinned Rocketbox FBX and five texture inputs listed in the character provenance. Run `Tools/Assets/prepare_luke_replacement.py` through Blender with the input directory and output GLB arguments.
3. Run Godot's editor import, then `--headless --path Godot --script res://tools/build_luke.gd -- --replacement` to rebuild `Godot/scenes/luke.tscn`.

## Verification

Seven suites passed 162 checks: authored character (14), real mouse knife swing (16), anatomical hand contact (13), supply actions (24), combat effects and hurt volumes (25), house spider combat (18), tutorial journey (52). Native images were reviewed for the strike, crouch, jump, equipped armor, hair and fluid effects.

The measured click-to-damage time was 0.2833 seconds at 60 Hz. Knife grip drift was zero. Maximum arm/spine length change during the layered attack was less than 0.001 mm. The flashlight lens and candy bite checks also passed on the new rig.

After removing the duplicate locomotion solve, the 14 character, 16 mouse-swing and 13 anatomical contact checks were repeated successfully. The portable PCK also passed 58 dependency, source-hash, scene, rig and interaction checks outside the source checkout.

The final packaged RX 550 run completed all five rooms and nine route legs with armor and active spiders at 960×540 Performance settings. Whole-route mean frame time was 23.58 ms (about 42.4 FPS), median 20.71 ms, and 95th percentile 34.69 ms. Knife-animation frames averaged 19.16 ms (about 52.2 FPS). A 2.17-second camera-pan hitch remains. The earlier candidate's route mean was 21.17 ms; these runs do not demonstrate an overall frame-rate improvement. This release fixes the animation/character faults but does not resolve all performance issues. Local measurements are in `Evidence/AuthoredMotion/route.json` and `route-before-opt.json`.

Run `res://tests/authored_character_tests.gd` in a native Godot window; optional `-- --output=<directory>` selects the screenshots/report directory. This is a rendered regression fixture, not a claim of human playtesting or AAA production quality. The full original voice recordings and pre-rendered town intro were not regenerated in this repair.
