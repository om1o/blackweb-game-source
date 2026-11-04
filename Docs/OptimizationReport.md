# Rendering optimization report

This is the Phase 0 measurement and package snapshot. The first Phase 1 controller cleanup is recorded in [Phase1Progress.md](Phase1Progress.md); the later house, movement, HUD and package pass is recorded in [GameplayMilestone.md](GameplayMilestone.md). A new rendered spot check is in [Phase1RenderCheck.md](Phase1RenderCheck.md), on a different GPU from this report, so it is not a before/after speedup.

The production change turns off two real-time room-light shadow maps and avoids repeated property writes to practical lights while power is steady. The flashlight retains its shadow, and the existing wall occluder, native 1280 × 720 resolution, 2× MSAA, recovered geometry, textures and material setup are retained. The final native entrance audit passed 11/11 checks and the full rendered route passed 29/29, including fatal retry and pause/restart. Entrance median frame time fell from 45.621 to 26.653 ms between the recorded production audits; stable 30 FPS across the opening is still not established.

## What the profiling established

The entrance comparison used one loaded recovered scene, one camera, Godot 4.7.2 Compatibility through ANGLE/D3D11 on Intel HD Graphics 530, and 180 process-frame samples per phase after settling. Only the two practical-light shadow flags changed during the sequence. These are wall-clock frame intervals, not isolated GPU timings. Desktop activity and host drift were present.

| Same-process phase | Median frame time | 95th percentile | Median draw calls |
| --- | ---: | ---: | ---: |
| Both practical shadows enabled, first | 37.403 ms | 59.878 ms | 496 |
| One practical shadow enabled | 23.871 ms | 34.517 ms | 285 |
| Both practical shadows disabled | 19.964 ms | 30.542 ms | 161 |
| Both practical shadows restored | 33.530 ms | 46.558 ms | 496 |

Disabling both practical shadow maps removed 335 of 496 entrance draw calls (67.5%). The no-shadow median was 40–47% lower than the two shadow-enabled samples in this sequence. The restoration phase also shows why independent runs cannot be treated as exact speedup ratios. These results supported the targeted source change; they are not the final route benchmark. [Raw shadow comparison](../Evidence/perf-shadow-aba.json), [profiling notes](../Evidence/perf-findings.md).

The flashlight shadow added 45 draw calls in its separate A/B/A comparison (206 versus 161), but frame-time drift prevented a reliable time-cost estimate. It was retained for the encounter. A separate occlusion-disabled probe rose to 748 draw calls and 61.587 ms median, so occlusion culling was retained. Disabling concrete normals or shortening camera range did not establish a reliable benefit and was not adopted. [Flashlight comparison](../Evidence/perf-flashlight-aba.json), [occlusion probe](../Evidence/perf-occlusion_off.json), [asset audit](../Tools/Performance/asset-opportunities.md).

## Production change and visual tradeoff

The two room practical lights still illuminate the room but no longer cast real-time object shadows. Flashlight shadowing remains active. Practical-light energy and ambient-energy writes are limited to actual power transitions, avoiding redundant updates when power is stable. The original static batching and occluder remain. This trades the room lights' shadow detail for substantially fewer rendering submissions; it does not replace or downsample the recovered assets.

The optimized default retains **native 1280 × 720 and 2× MSAA**. The two original room-shadow flags can be enabled with `--room-shadows`; from PowerShell in the repository use `& '.\Playable\Launch Blackweb.cmd' --room-shadows`. Double-clicking the launcher uses the optimized default. Both modes retain the camera flashlight shadow.

| Production entrance audit | Median frame time | 95th percentile | Draw calls | Samples |
| --- | ---: | ---: | ---: | ---: |
| Before this optimization, native batched | 45.621 ms | 51.647 ms | 496 | 180 |
| Optimized default, native batched | **26.653 ms** | **43.297 ms** | **161** | **180** |

The new entrance median is approximately 37.5 FPS; the p95 exceeds the 33.33 ms budget for stable 30 FPS. The recorded median decreased 41.6% between these separate runs, while the controlled shadow sequence above provides stronger evidence for the source of the improvement. Godot reported 594,741,661 texture-memory bytes and 615,209,725 video-memory bytes, engine monitor values rather than an independent GPU-memory measurement. [Prior native audit](../Evidence/performance-native-batched.json), [optimized native audit](../Evidence/performance-optimized-native.json).

The final automated rendered route passed **29/29 checks, exit 0**; the entrance audit passed **11/11, exit 0**. Route stage samples measured Mara message 17.581 ms median / 39.884 ms p95 (777 samples), preparation 19.596 / 41.958 (329), and encounter **38.244 / 85.136 ms** (153). The earlier encounter median was 47.724 ms. These are wall-clock automated-route samples with QA overhead, not isolated gameplay FPS. [Route log](../Evidence/playthrough-optimized.log), [route results](../Godot/data/playthrough_flashlight-first.json), [entrance log](../Evidence/opening-audit-optimized.log), [entrance results](../Godot/data/opening_audit_rendered.json).

A bounded true 960 × 540 probe measured 28.227 ms median in a separate run and did not demonstrate a gain over the 26.653 ms native audit. The default remains 1280 × 720. Earlier render-scale and no-MSAA probes were also not adopted. [960 × 540 results](../Evidence/perf-optimized-960.json).

## Verification and portable delivery

The optimized portable PCK was rebuilt successfully and passed **17/17 isolated headless checks, exit 0, empty stderr**, from an empty working directory outside the project. The test checked raw/imported input paths and sizes, critical source hashes, scene assembly, 102 geometry GLBs, Luke/spider rigs, material application, six WAVs and physics startup. It did not rely on the recovered-assets junction. [Full smoke report](../Evidence/portable-smoke.json), [log](../Evidence/portable-smoke.log), [build report and artifact hashes](../Evidence/portable-build-report.json).

The new PCK contains **1,566 files** and is **1,723,201,068 bytes**. SHA-256: **53E7E5894C53F8487F278FEBC380FE5A6710F9496E9987282B6B71EAB49E5939**. The official Godot 4.7.2 runtime remains unchanged. The final copied launcher exactly matches its packaging template. A bounded command-parsing test verified default mode, the explicit `--room-shadows` option after Godot's `--` separator, and ignoring an unrecognized option. That harness replaced only process launch with echo, so it is argument-parsing evidence, not an interactive GUI test. [Launcher test](../Evidence/launcher-argument-probe.json).

The source plus portable package stays below the **5,000,000,000-byte** cap; [ProjectFootprint.md](ProjectFootprint.md) records the final measurement. Preflight now explicitly budgets retained UserData/cache/report bytes, and staging remains outside the project. The previous PCK hash and test record are retained as small [before-build evidence](../Evidence/portable-before-optimization-build-report.json); the old generated PCK was replaced only after the new pack completed.

The portable package was rebuilt from the final QA-verified source. The packaging tool preserves raw runtime GLB/PNG/JSON files, .import settings and the matching import cache. The existing player save directory is preserved when replacing the PCK. Native desktop menu interaction remains a separate check from automated route and headless package tests.

## Measurement limits

A 180-frame stationary sample is not a whole-house worst-case benchmark. Full-route samples include route planning and screenshot overhead. Cached Godot physics-process monitor values are not isolated physics-tick timings. No isolated GPU timer, reliable CPU/GPU split, or human playtest is claimed. The measured results do not support a 100× performance claim. The broader AAA target still has the voice, interaction-animation and visual-fidelity gaps described in [Phase0Report.md](Phase0Report.md).
