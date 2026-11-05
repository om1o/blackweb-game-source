# Environment v3: full-route native performance

This is the **pre-compression baseline**, preserved before the subsequent VRAM normal-texture import investigation. The [later RGTC full-route measurement](WholeRouteRgtcPerformance.md) records the follow-up result; the statistics below remain unchanged.

Measured 2026-11-05 UTC against source base `fc7a2bc06747978261610d88f8a066707159b989` plus the integrated environment v3, hand-contact, juvenile-pursuit and table-placement changes. This is a source-runtime measurement, not a measurement of a newly exported package. Exact runtime hashes and before/after manifests accompany the raw data.

The native controller completed **all nine legs through all five rooms with no route failures**. Across **1,642 rendered frame intervals over 50.213 seconds**, median frame duration was **30.461 ms**, p95 **41.097 ms**, and mean **30.579 ms**, equivalent to approximately **32.7 FPS**. This device did not sustain 60 FPS in this workload.

| Room | Samples | Median frame | p95 frame |
|---|---:|---:|---:|
| Entry / lore | 444 | 30.562 ms | 42.322 ms |
| Record / lore | 281 | 31.907 ms | 40.672 ms |
| Vault / spider | 211 | 32.264 ms | 41.220 ms |
| Supply / spider | 377 | 29.682 ms | 39.101 ms |
| Infested / spider | 329 | 27.501 ms | 39.758 ms |

**31.49%** of frames exceeded 33.333 ms; **0.55%** exceeded 50 ms. Overall p99 was 47.994 ms. The largest hitch, **312.772 ms**, occurred at 33.959 seconds while walking into the infested room. It remains in the statistics and its cause has not been isolated. The next largest frame was 55.353 ms.

The workload issued **11 knife actions and six jump inputs** to clear live enemies. There were 267 frames with the knife animation active (p95 36.601 ms), and 270 frames with an adult windup/lunge or juvenile bite windup (p95 41.097 ms). Real attacks reduced the benchmark health budget from 1,000 to 917. The normal weak flashlight drained and flickered, finishing at about 11.96 battery points. The encounter resolved at the exit-return portion of the route.

## Interpretation

The [historical run](WholeRoutePerformance.md) averaged about 43 FPS. This integrated build's observed average is lower. The new environment, hand poses, pursuit behavior, table layout, route timing and live enemy interactions differ, so these two runs are **not a controlled attribution experiment**. The newer art cannot be assigned the entire difference from this evidence alone. The separate [vault A/B/A investigation](VaultPursuitPerformance.md) established the targeted juvenile-pursuit benefit with artwork and source held constant.

No graphics settings, geometry, collision or enemies were removed for this run. The environment manifest identifies 95,030,515 bytes of eleven distinct runtime-referenced source textures with 2K runtime import limits, and the scene includes the six new opaque web instances. Source payload size is not a visual-quality metric or a frame-time budget.

## Conditions and limits

- Godot 4.7.2 Compatibility using ANGLE Direct3D11 on **Intel HD Graphics 530**, driver 30.0.101.1339; same recorded machine as the historical audit (Windows 11 Pro, Core i5-6600).
- Window requested/reported at **960×540**, VSync enabled, no FPS cap, 2× MSAA, 3D scale 1.0. Actual framebuffer readbacks at both ends were **960×539**, also verified in the saved PNGs. The ViewportTexture getter continued to report 674×378; those diagnostic getter fields are not authoritative image dimensions.
- Before and after manifests found **zero other Godot processes** and **no changes to 43 recorded source, data, scene and art files**. Native runtime PID 17456 exited normally. The launcher helper was untouched. Ordinary desktop processes and OS scheduling still shared the machine.
- Four interior doors were opened and the real encounter activated during untimed setup. Luke received a benchmark-only 1,000 HP budget to prevent checkpoint reloads; normal damage, enemy HP, collision, AI, animations, flashlight behavior and item actions stayed active.
- Static paths were computed before timing. Ordinary controller input then walked the route, turned the camera, jumped when live enemies blocked a waypoint and used the knife. No timed screenshots, teleports, healing, pathfinding, disk writes or performance changes occurred. The two screenshots were outside the measured interval and visually checked.
- Consecutive monotonic `process_frame` intervals retain stalls and include rendering, presentation, automation, sampling and OS scheduling. They are not isolated GPU execution timings. `TIME_PHYSICS_PROCESS` is a cached one-second maximum; it must not be treated as each row's individual physics-tick duration. [Godot main-loop implementation](https://github.com/godotengine/godot/blob/master/main/main.cpp).
- One roughly 50-second run is not a sustained thermal benchmark, minimum-spec certification, human playtest or balance test. It exercises all five rooms and is distinct from the narrative phone/key/blackout/retry/exit test.

## Traversal and evidence

The enhanced source traversal test passed **23/23**, including all rooms and both sides of the four interior doorways, with 1,202 spawn-connected cells. The added checks confirm that the retained record table stays between the partitions and that its rotated physical bounds match its visible bounds. The table is now at (1.65, 0.40, 2.94), yaw 90 degrees, with the world-baked collider transformed by the corresponding old-to-new map.

The native run exited 0 with no script/test errors or leaked-object diagnostics. The log contains the expected driver warning that selects ANGLE because of the Intel OpenGL implementation; it is not a crash.

Evidence files:

- `Evidence/tutorial-route-v3-native-960.json`: raw frame rows, nine-leg route/events, source hashes, conditions and full summary.
- `Evidence/tutorial-route-v3-native-960.log`: engine, adapter, completion and diagnostics.
- `Evidence/tutorial-route-v3-native-960-start.png` and `-end.png`: untimed framebuffer readbacks.
- `Evidence/tutorial-route-v3-manifest-before.json` and `-after.json`: process inventory and 43 unchanged runtime inputs.
- `Evidence/tutorial-route-v3-summary.json`: overall metrics, input/action counts, dimensions and largest frame intervals.
- `Evidence/five-room-traversal-environment-v3-final.log`: source traversal 23/23.

The reusable `Tools/Performance/profile_tutorial_route.gd` accepts `--source-commit=<revision>` and records actual runtime file hashes. New package or later code/art changes need their own evidence; do not relabel this source run as a package benchmark.
