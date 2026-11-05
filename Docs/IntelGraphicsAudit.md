# Intel HD 530 graphics audit — 2026-11-05

The final Performance preset keeps **100% 3D resolution with MSAA off**. A native Q/N/S/S/N/Q comparison found 75% scaling consistently slower than native/no-MSAA in all three fixed views on this Intel HD530/ANGLE configuration. This supports removing scaling from the preset; it does not establish a universal driver explanation or a live-game FPS guarantee.

The historical five-room result of **41.0 FPS**, median 23.925 ms and p95 33.957 ms, predates the new menu/armor pass (`WholeRouteRgtcPerformance.md`). The earlier current-build Quality/75%-Performance/Quality probe also had uncertain external-game contention. Neither establishes the final preset's gameplay performance. The current release's separate live-route results and limitations belong in `InterfaceAndPacingRelease.md`.

## Applied bounded changes

The opaque main/pause menu previously left the house's root viewport drawing behind it. `horror_menu.gd` now owns a reversible `Viewport.disable_3d` lease: record the original flag on show, disable root 3D, restore on hide or tree exit. It does not hide house nodes or change simulation, lights, audio or the separate selected-item viewport.

`menu_settings.gd` exposes two explicit options, both preserving full resolution:

| Preset | 3D resolution | MSAA | 2D UI |
|---|---:|---:|---|
| Quality | 100% | 2× | Unchanged |
| Performance | 100% | Off | Unchanged |

No torch, web, blood, material, model or enemy is removed. Performance skips edge smoothing, and applying it also resets any already-active 75% scaling from the earlier implementation. The preset persists in `user://blackweb_settings.cfg`. The first-run default is Performance only when the active renderer names Intel HD Graphics 530; other adapters default to Quality. A valid existing preference wins over detection.

For repeatable runs, pass `-- --graphics=quality` or `-- --graphics=performance`. A valid CLI override takes precedence for that process without replacing the persisted preference; the menu identifies the override and disables its selector for that session. Invalid values are ignored.

Full-game measurement remains separate from this paused rendering comparison. The headless state suite only verifies settings and restoration.

`status_hud.gd` also skips inventory text formatting/layout refresh while the inventory is closed, and refreshes on every open even if the selected item is unchanged. Live health/stamina/battery meter updates remain active. This removes hidden UI work; no separate frame-time gain is claimed.

Focused verification: `Evidence/menu-rendering-tests.json` records **23/23** lifecycle, preset, CLI, persistence and hidden-inventory checks, rerun against the final native/no-MSAA mapping. CLI and Options assertions verify anti-aliasing as well as resolution. The earlier native menu fixture records **37/37**, including the Graphics row inside the scroll area and the fixed Options footer remaining on screen; it preceded the final preset label/copy correction. Both runs exited 0 cleanly. These are correctness checks, not the full-house performance measurement.

Because the hidden house no longer renders during the title menu, first-use material/shader work can occur during the arrival rather than while the menu is open. The comparison's first native house draw completed **28.09 seconds** after setup began using the existing isolated Performance cache. This includes scene construction and is not a pure shader-compilation time. The earlier fresh-cache journey took much longer; cache warmth matters for startup evidence.

## Controlled native rendering comparison

`Tools/Performance/compare_render_presets.gd` loads the full house once in QA mode and freezes the starter simulation. It enables the actual torch/shadow, leaves environment materials and HUD present, and moves the same camera through entry, records and web-room views. These are staged performance views, not normal first-person gameplay screenshots or animation validation. No armor is equipped in this fixture; the live route separately exercises armor and active combat.

Each of the nine configuration/view combinations is prewarmed for at least one second. The measured order is Quality → Native/no-AA → Scaled/no-AA → Scaled/no-AA → Native/no-AA → Quality, with 1.5 seconds of warm-up and three seconds of sampling per view. The scene, camera targets and requested 1280×720 window stay unchanged. Screenshot readback and writing happen outside the samples.

Measured framebuffer: **1280×719**; Compatibility renderer on **Intel HD Graphics 530 via ANGLE/D3D11**, VSync enabled, no explicit engine FPS cap. Median frame intervals in milliseconds, first / reverse repeat:

| Configuration | Entry | Records | Web room |
|---|---:|---:|---:|
| 100% + 2× MSAA | 17.12 / 26.13 | 16.65 / 16.83 | 16.62 / 16.72 |
| 100% + no MSAA | 16.67 / 16.67 | 16.67 / 17.45 | 16.67 / 16.87 |
| 75% + no MSAA | 27.95 / 27.99 | 24.86 / 24.54 | 24.78 / 24.99 |

The scaled path is slower in every matched view/repeat here. Native/no-MSAA stays close to the display pacing limit; removing MSAA has no precise proven speedup over Quality because several samples are VSync-limited and the second Quality entry sample shows substantial drift (p95 48.41 ms). The result justifies the native/no-MSAA Performance choice on this machine, not a universal anti-aliasing percentage claim. It also does not prove which internal driver, copy/composite or resource operation causes the scaled-path penalty.

The script exited **0**, completed **6 phases / 18 samples**, and reported **0 failures**. All **2,690 raw frame intervals** have strictly increasing monotonic timestamps and one observed rendered frame per interval. Eighteen screenshots are retained. The inspected entry comparison shows unchanged geometry/lighting with visible softness in the scaled image; both native configurations retain detailed webs and torch illumination. The launch manifest records **no other Godot processes before or after**. Ordinary desktop work and OS/thermal variation remain uncontrolled.

Evidence in `Evidence/InterfaceRelease/`:

- `render-variant-comparison.json`: raw intervals, monotonic timestamps, draw deltas, per-view statistics, actual scale/MSAA/window settings, runtime/harness hashes and repeated-view summaries.
- `render-variant-comparison-processes.json`: isolated environment, launch/exit times, no-other-engine snapshots and exit 0.
- `render-variant-comparison.log` and `render-variant-comparison-stderr.log`: completed phases and only the expected Intel ANGLE notice.
- `render-variant-comparison-00-quality-entry.png`, `-01-native_no_msaa-entry.png`, `-02-scaled_no_msaa-entry.png` and the remaining 15 named captures.

Reproduce with `Tools/Performance/RunRenderPresetComparison.ps1 -OutputBase <new-unique-name>` after all other Godot processes exit. It reuses only `D:\CodexTemp\Blackweb-RealArmor-20261105\Performance`'s isolated caches, refuses to overwrite prior JSON, records exact source/harness identity, and never stops another process. The harness configures the viewport directly without changing saved preferences. Internal 3D target dimensions are estimated from configured scale and final readback size; the final framebuffer is directly verified.

## Already present; retain

- `main.gd` disables practical omni-light shadow cubemaps unless explicitly launched with `--room-shadows`.
- `player.gd` retains one shadowed flashlight spot; flare and hand fill are unshadowed. Preserve the torch's energy/range and shadows for route visibility.
- `house_dressing.gd` batches web strands/cards and disables their shadow casting. Photo/ceiling web cards and `environment_surfaces.gd` masks use alpha scissor. Do not remove the user's web coverage as a first optimization.
- The large new normal textures already import as RGTC with mipmaps, which had a favorable previous full-route comparison. Do not reimport them to uncompressed RGBA.
- `item_preview.gd` renders a 256px mesh-only isolated view once when selection changes, then disables updates. Repeated selection does not render again.

## Further candidates only if the measured preset is insufficient

1. Reduce the positional shadow atlas from its 2048 default to 1024 while preserving the torch's shadow. Measure and compare close spider/hand shadows; this does not remove the illumination.
2. Profile the five-texture PBR orb-web shader. A Low variant could retain color/opacity plus constant roughness while omitting normal and AO reads. It needs visible flashlight checks before adoption because it reduces material depth.
3. Inspect runtime draw-call/triangle counts after the new garments, and reduce only offscreen or redundant geometry if it is significant. Earlier room batching/pursuit fixes already removed known waste; do not assume old counts apply to current armor.

Do not disable 60Hz physics, remove enemies, lower flashlight brightness or apply a frame cap before establishing the bottleneck. A 30FPS cap can improve pacing only if the final workload reliably stays below 33.3ms; current historical p95 slightly exceeds that.

Primary references: [Godot Viewport scaling/disable_3d/MSAA](https://docs.godotengine.org/en/stable/classes/class_viewport.html), [RenderingServer adapter information](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html), [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html). The native logs show ANGLE/D3D11 on Intel HD 530; the separate historical Radeon Code31 issue was diagnosed read-only and is not changed by this pass.
