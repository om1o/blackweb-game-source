# Worn knife slash pass

Slot 2 keeps the worn knife in Luke's right hand. A captured left mouse press starts a raised windup, a curved diagonal cut, a short follow-through, and recovery to the same hold. The steel and handle move with the wrist; the model is centred on the handle and stays fixed inside the curled fingers. A modest upper-chest turn supports the cut without replacing the crouch/jump pose.

The windup lasts 0.14 seconds, the damage sample is at 0.24 seconds, and the animation finishes at 0.68 seconds. The 0.75-second cooldown, **4 base damage**, nearest-target selection, forward arc, and wall obstruction remain explicit. Reach is capped at 1.55 metres. Mouse holding does not auto-repeat; clicks during an action cannot stack or restart its damage. The swing sound begins after windup; impact sound plays only after a valid hit.

`Godot/tests/knife_swing_tests.gd` runs in a native window because Godot's headless display cannot capture the mouse. It dispatches real mouse events and checks delayed/single-hit damage, fresh versus held clicks, obstruction, range, rear targets, fixed grip, the skeleton's diagonal hand travel, and removal of knife overrides when changing equipment. Run with `Godot/runtime/Godot_v4.7.2-stable_win64_console.exe --path Godot --script res://tests/knife_swing_tests.gd`.

`Godot/tools/capture_knife_swing.gd` records seven native images under `Evidence/knife-slash-*.png`, including ready, windup, contact, follow-through, recovery, return, and a close grip view. It slows simulation only inside the QA tool so the short action phases can be captured. The normal game remains at full speed.

Final verification on 2026-11-04: native mouse/skeleton/melee tests **16/16**, exit 0; seven native captures saved successfully, exit 0. Measured hand travel was 0.629 m vertically and 0.288 m laterally. First damage arrived at 0.25 seconds on the 60 Hz physics step, with zero translation or rotation drift between knife and hand. The final inner-right follow-through stays visible below the right elbow in the normal chase view. Reports are `Godot/data/knife_swing_test_report.json` and `Godot/data/knife_swing_capture.json`.

This is an additive procedural animation using the recovered character skeleton and existing CC0 knife model. It is not a captured full-body combat animation. The gameplay hit uses a bounded forward target/obstruction check rather than exact blade-triangle collision; precise contact with floor-height spiders remains a separate animation task.
