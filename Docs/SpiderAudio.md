# Spider contact audio

`Godot/scripts/spider_audio.gd` synthesizes original dry taps and a short friction scratch in code. These are not recovered recordings from Arachnophobia and contain no external samples, vocals, growls, or music. Fixed local random seeds make the five mono 22,050 Hz / 16-bit PCM clips repeatable. They are generated once per encounter actor, use no disk assets and never loop.

Four 72 ms contact variants use filtered noise with two rapidly decaying impacts. Their playback position alternates around the spider's feet; volume is -23 dB, audible range is capped at 11 m, and only one contact stream plays at a time. The controller supplies horizontal distance actually achieved after `move_and_slide`, so pushing against an obstacle cannot create footsteps. Cadence uses 0.42–0.60 m of travel per audible contact group and a 105 ms minimum interval. This represents sparse audible leg contacts; it is not skeletal foot IK or a contact detector on each toe.

One 240 ms dry scratch plays at -22 dB from the spider's front when its state actually enters `WINDUP`. The state's existing change guard prevents repeated cues during the same windup. It accompanies the visible pause before a committed lunge; no persistent ambience is added.

Deactivation, hidden state, player recovery and completion silence both streams. Contact sounds also stop when airborne or stationary. The helper and its players are pausable, and motion updates explicitly reject paused playback. Existing room, presence, door and player footstep audio are unchanged.

Validation: run `Godot/runtime/Godot_v4.7.2-stable_win64_console.exe --headless --path Godot --script res://tests/spider_tests.gd`. The controller's existing wall, attack, recovery and avoidance checks remain the integration check; final mix audibility is assessed in the rendered game.
