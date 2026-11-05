# Five-room traversal and native performance

This is the historical pre-environment-v3 measurement. The later [pre-compression run](WholeRouteEnvironmentV3Performance.md) and [latest RGTC full-route measurement](WholeRouteRgtcPerformance.md) record this pass's performance and limits; the original frame statistics below are preserved.

Measured 2026-11-05 UTC on the current source checkout, based on commit `c423a22b5b73dac5cf68d1cf845cfd10453593ea` plus the action, supply, voice, and furniture fixes. This is **not a measurement of the old portable PCK**. Runtime script hashes are inside `tutorial-route-native-960.json`; the fuller file list is `tutorial-route-source-manifest.json`.

## Result

The native controller workload completed all nine legs through all five rooms, with no route failures. It collected **2,080 rendered frame intervals over 48.425 seconds**. The overall median was **21.965 ms**, p95 **33.068 ms**, and mean **23.272 ms** (about **43 FPS**). This is one short run, not a minimum-spec or sustained-frame-rate guarantee.

| Room | Rendered samples | Median frame | p95 frame |
|---|---:|---:|---:|
| Entry / lore | 599 | 22.125 ms | 32.027 ms |
| Record / lore | 383 | 23.390 ms | 31.206 ms |
| Vault / spider | 253 | 24.493 ms | 40.392 ms |
| Supply / spider | 467 | 20.536 ms | 31.683 ms |
| Infested / spider | 378 | 20.487 ms | 30.453 ms |

**4.81%** of frames exceeded 33.333 ms and **0.87%** exceeded 50 ms. Overall p99 was 48.633 ms. The **590.039 ms maximum hitch** occurred 0.665 seconds into the measured entry-room pan; another 257.037 ms stall occurred during the first vault approach. Both remain in the statistics. Their causes have not been isolated.

The run issued **11 knife actions** and **four real jump inputs** to clear live enemies blocking the scripted walk. There were 346 frames with the knife animation active (p95 29.481 ms), and 311 frames with an adult windup/lunge or juvenile bite windup (p95 30.352 ms). Actual attack damage reduced the benchmark health budget from 1,000 to 925. The weak flashlight remained subject to normal drain/flicker, ending near 12.45 battery points. One juvenile was killed during the workload; the normal retreat-to-exit resolution deactivated the remaining encounter at the end.

## Conditions and limitations

- Windows 11 Pro build 26100; Intel Core i5-6600, four cores; **Intel HD Graphics 530** selected by Godot through **ANGLE / Direct3D11**, driver 30.0.101.1339. A Radeon RX550/550 is also enumerated by Windows but was not used in this measurement.
- Godot 4.7.2 Compatibility; **960 × 540 window**, logical canvas 1366 × 768, VSync enabled, no FPS cap, 2× MSAA, 3D scale 1.0. The saved start/end rendered images are 960 × 539 pixels because of the aspect-fit output. The early viewport-texture query in the raw metadata returned 674 × 378 before frame synchronization; do not use that field as a settled render-resolution measurement. The reusable harness now also records the settled size after drawing/warm-up and at the end.
- A fresh process snapshot showed **zero existing Godot processes before launch**. Root closed its own previous test fixture first. The only native renderer during the measurement was harness PID 24812, launched by console wrapper 23500; both exited normally. The launcher helper PID 24444 remained untouched. Ordinary desktop applications and Windows scheduling were still present, and one read-only process-list snapshot was taken during the run.
- Four interior doors were opened during untimed setup; the actual encounter was activated directly. A benchmark-only **1,000 HP budget** prevented a checkpoint reload from truncating late-room samples. Damage, collision, spider AI, flashlight effects, and animations stayed active. This is a **controller-driven five-room performance workload**, distinct from the existing narrative route through phone, keys, blackout, retry, exit and restart. It is not a human playtest or a balance test.
- All static paths were computed before timing. The player then used ordinary forward/jump input, camera turns, and real item actions. No timed screenshots, teleports, healing, path searches, disk writes, or performance-setting changes occurred. Room camera pans deliberately expose different walls/webs. Screenshots were taken outside the timed interval.
- Samples are consecutive monotonic `process_frame` intervals, retaining stalls. They include rendering/presentation, controller automation and collection overhead; they are not isolated GPU times. Draw calls and physics times are supplemental engine monitors whose updates may be delayed. Do not derive frame percentiles from Godot's periodically updated FPS counter. [Godot Performance documentation](https://docs.godotengine.org/en/stable/classes/class_performance.html).

## The route blocker found before profiling

The old package's extra coffee table at `(-1.6, 0.4, -2)` occupied x `[-2.157, -1.043]`, z `[-2.830, -1.170]`, blocking the supply doorway's west approach. The sofa front at z `-2.179`, combined with the opened door leaf, also left insufficient space on the east side for Luke's 0.54 m diameter. A center ray could pass, so the earlier door-ray checks missed the obstruction.

`Godot/scripts/main.gd` now keeps the table beside the entry's west wall at `(-4.2, 0.4, -2)` and places the sofa at `(1.2, 0.4, -3.10)` with 90% uniform scale. Both props, their materials and physical collision remain; no plot interaction was removed.

`Godot/tests/five_room_traversal_tests.gd` tests the actual standing capsule with overlaps and swept movement on a 20 cm grid, verifies the five destination floors, and requires spawn connectivity to every room and both sides of all four interior doors. The same test **fails 4 of 20 checks on the old PCK** and **passes 20/20 on the fixed source**. The source controller workload then physically completed the route with active enemies, first headless and then rendered. Headless frame numbers are not rendering performance evidence.

Follow-up source checks passed: compact layout **39/39**, juvenile bite occlusion **9/9**, and locomotion poses **10/10**. See the corresponding `*-after-clearance.log` files and `five-room-traversal-before.log` / `five-room-traversal-after.log`.

## Next optimization to measure

First compare the same workload using the installed Radeon adapter through Windows' per-app graphics preference, retaining the present artwork. Windows supports choosing a high-performance GPU per application and requires restarting it for the setting to take effect; verify Godot's adapter string before comparing. No adapter preference was changed by this audit. [Microsoft graphics preference instructions](https://support.microsoft.com/en-au/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).

The vault's recorded physics-monitor median of about 17 ms (versus roughly 6–8 ms elsewhere) was a median of repeated **cached one-second maxima**, not the median duration of individual physics ticks. Godot publishes the interval's largest physics duration and then resets that maximum. It cannot by itself establish the room's average physics cost or a CPU/GPU bottleneck. [Godot main-loop implementation](https://github.com/godotengine/godot/blob/master/main/main.cpp).

The [causal follow-up](VaultPursuitPerformance.md) measured actor callbacks directly and found a juvenile repeatedly pushing through the partition into a coffee-table collider. Visible-target pursuit removed that contact loop; a controlled vault A/B/A comparison improved frame median by 10.19% and p95 by 14.61% while preserving collision, gravity and nearby attacks. These targeted results are separate from the historical full-route statistics above. Further graphics changes require measurement and visual comparison; alpha-scissor can reduce transparent overlap but changes edges. [Godot GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html), [Godot material transparency](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html).

## Reproduce

From the project root, with other game test processes closed and no concurrent build:

```powershell
& .\Godot\runtime\Godot_v4.7.2-stable_win64_console.exe --path .\Godot --resolution 960x540 --script D:\GameProjects\BlackwebHouseRebuild-20261103\Tools\Performance\profile_tutorial_route.gd -- --output=D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/tutorial-route-native-repeat.json
```

For headless route validation, add `--headless` before `--path` and `--validate-route` after `--`. Use a different output file and never label the resulting intervals as rendering performance. The primary native raw data, nine-leg path/events, source hashes and frame rows are in `tutorial-route-native-960.json`; machine and launch/process metadata are in the neighboring `tutorial-route-*.json` files.
