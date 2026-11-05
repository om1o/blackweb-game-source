# Full-route native performance after normal-texture compression

Measured 2026-11-05 UTC against source base `fc7a2bc06747978261610d88f8a066707159b989` plus the current environment, hand-contact, pursuit and layout changes. This is the latest **source-runtime** measurement in this pass, not an exported-package benchmark.

The native controller completed **all nine legs through all five rooms**, exit 0, with no route failures. Across **2,018 rendered frame intervals over 49.241 seconds**, mean frame duration was **24.400 ms** (about **41.0 FPS**), median **23.925 ms**, and p95 **33.957 ms**. The largest frame was **53.170 ms**. This is improved on the preceding run, but still does not establish sustained 60 FPS on this machine.

| Room | Samples | Median frame | p95 frame |
|---|---:|---:|---:|
| Entry / lore | 557 | 24.151 ms | 35.152 ms |
| Record / lore | 325 | 27.851 ms | 34.121 ms |
| Vault / spider | 248 | 27.425 ms | 34.853 ms |
| Supply / spider | 506 | 21.835 ms | 30.892 ms |
| Infested / spider | 382 | 20.396 ms | 32.175 ms |

Overall p99 was 39.917 ms. **6.29%** of intervals exceeded 33.333 ms and **0.05%** exceeded 50 ms. The 53.170 ms maximum occurred at 38.848 seconds during the infested-room knife sequence; it remains in the statistics. No frame above 100 ms occurred in this run, which does not guarantee that future runs will be hitch-free.

The workload used **11 knife actions and five jump inputs** with real enemies/collision. Its benchmark health budget fell from 1,000 to 921 and the flashlight ended at approximately 12.15 battery points. There were 343 frames with knife animation active (p95 31.105 ms) and 318 frames with adult attack or juvenile bite windup active (p95 32.649 ms). The encounter resolved normally during the exit-return portion.

## Change and comparison

Three new 2048×2048 normal maps now import as mipmapped RGTC_RG, with 5,592,432 stored image bytes each. The custom environment shader reconstructs normal Z from the stored red/green channels. The source texture files, texture dimensions, geometry and collision were retained. The imported-resource audit is `Evidence/environment-imported-textures.json`; root also reviewed the five native room captures before this measurement.

The [pre-compression run](WholeRouteEnvironmentV3Performance.md) averaged 32.7 FPS with median 30.461 ms and p95 41.097 ms. This follow-up observed **21.46% lower median frame duration** and **17.37% lower p95 duration**, with an average of 41.0 FPS. Of the thirteen script hashes recorded by both runs, only `environment_surfaces.gd` changed. The new import settings and imported texture-cache hashes are pinned in this run's manifests.

These are two full-route samples, not an A/B/A reversal or sustained thermal test. Live enemy contacts differ slightly (five versus six jump inputs; 921 versus 917 ending HP), ordinary OS scheduling and cache state remain uncontrolled, and the route lengths differ by about one second. The paired observations support keeping the import improvement; they do not assign every frame-time difference to it or guarantee the same gain on another device. The earlier [juvenile-pursuit A/B/A](VaultPursuitPerformance.md) is a separate, controlled attribution experiment.

## Conditions and limits

- Godot 4.7.2 Compatibility, ANGLE Direct3D11, **Intel HD Graphics 530**, driver 30.0.101.1339; recorded machine Windows 11 Pro, Intel Core i5-6600.
- Window requested/reported 960×540; actual start/end framebuffer PNGs **960×539**. VSync enabled, no FPS cap, 2× MSAA and 3D scale 1.0. The ViewportTexture getter still reports 674×378, so the actual image readbacks supply authoritative dimensions.
- **65 recorded source, data, scene, source-art, import-metadata and imported-cache files were unchanged** across the run. There were zero other Godot processes in the before/after snapshots; runtime PID 15700 exited normally. The launcher helper and all system GPU preferences remained untouched. Desktop/OS activity still shared the device.
- Four interior doors opened and the real encounter activated before measurement. The 1,000 HP benchmark budget prevented checkpoint reloads; enemy HP, attacks, collisions, gravity, animations, flashlight drain/flicker and item actions remained normal.
- Static paths and screenshots occurred outside timing. Ordinary input drove the nine legs, camera pans, knife actions and jumps. There were no timed teleports, healing, path searches, file writes or graphics-setting changes.
- Raw rows are monotonic `process_frame` intervals including rendering, presentation, automation and sampling overhead, not GPU execution times. Physics-monitor values are cached one-second maxima, not per-row individual physics-tick durations. [Godot main-loop implementation](https://github.com/godotengine/godot/blob/master/main/main.cpp).
- This is a short five-room workload, distinct from the narrative phone/key/blackout/retry test. It is not a human playtest, balance test, sustained benchmark or minimum-spec certification. The final package requires its separate packaging/smoke verification.

The installed Radeon RX550/550 currently reports Windows Device Manager **code 31** in both WMI and PnP checks. Neither game renderer executable has a per-app GPU override. That explains why an unverified Radeon preference is not the next benchmark: its driver-load problem must be resolved before its usability can be assumed. No driver or GPU setting was changed. See `Evidence/GpuPreferenceAudit.md` and `gpu-preference-readonly-audit.json`; [Microsoft's code 31 definition](https://support.microsoft.com/en-us/windows/hardware/drivers/error-codes-in-device-manager-in-windows).

## Evidence

- `Evidence/tutorial-route-v3-rgtc-native-960.json` and `.log`: full raw rows, route, events, source hashes and completion.
- `Evidence/tutorial-route-v3-rgtc-native-960-start.png` and `-end.png`: untimed, visually checked framebuffer readbacks.
- `Evidence/tutorial-route-v3-rgtc-manifest-before.json` and `-after.json`: 65 unchanged inputs and process inventories.
- `Evidence/tutorial-route-v3-rgtc-summary.json`: metrics, action counts, dimensions, worst intervals and paired percentages.
- The preceding `tutorial-route-v3-*` and historical `tutorial-route-native-960.*` evidence remain intact.

`Tools/Performance/profile_tutorial_route.gd` is the reusable harness. Later code/art, hardware or package changes need fresh evidence instead of relabeling this source run.
