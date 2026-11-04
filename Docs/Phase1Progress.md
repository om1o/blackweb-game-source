# Phase 1 first controller cleanup — historical checkpoint

This report records the first Phase 1 package. The later house, movement, HUD and story pass is documented in [GameplayMilestone.md](GameplayMilestone.md), [HouseDressing.md](HouseDressing.md), and [Phase1RenderCheck.md](Phase1RenderCheck.md).

Phase 1 has started with a bounded update in the active Godot opening. Luke's controller previously assigned `visual.visible` and `lamp.visible` on every active physics tick and emitted the current interaction prompt on every tick, even when all three values were unchanged. It now writes the visibility properties and emits `focus_changed` only when their values change. This avoids repeated render/UI update work during long stretches of steady camera, flashlight and focus state while preserving the same visible states and interaction rules. Source: [player.gd](../Godot/scripts/player.gd).

The reason to investigate this is the recorded Phase 0 performance gap: entrance 43.297 ms at p95 and automated encounter 38.244 ms median / 85.136 ms p95 on the target Intel HD Graphics 530. Those numbers are **pre-change baseline evidence**, not a measurement of this update. No rendered same-machine A/B was run for this change, so no FPS gain or 30 FPS pass is claimed. The full headless route validates behavior, not performance. [Prior performance evidence](OptimizationReport.md).

## Verification

| Check after source change | Result | Evidence |
| --- | --- | --- |
| Progression suite | 56 checks, 0 failures, exit 0 | `--headless --script res://tests/progression_tests.gd` |
| Spider integration suite | 18 checks, 0 failures, exit 0 | `--headless --script res://tests/spider_tests.gd` |
| Flashlight-first full opening, fatal retry and restart | 29 checks, 0 failures, exit 0 | [Route result](../Evidence/phase1-headless-route.json), [log](../Evidence/phase1-headless-route.log) |
| Rebuilt portable package, tested outside the project | 17 checks, passed, exit 0 | [Package smoke](../Evidence/portable-smoke.json), [build report](../Playable/build-report.json) |

The route test preserved the earlier rendered `Godot/data/playthrough_flashlight-first.json` measurement; the new headless result was saved separately. This matters because a dummy headless renderer cannot replace the recorded native render timings.

At this checkpoint, the PCK contained 1,566 files and was **1,723,201,356 bytes**, SHA-256 **DA17BB6EEE2CEC2F94A6BE2A385FC3696B16D498DCD8FD077CA12EC8465C8FAD**. The build report then measured the project at **4,599,119,716 logical bytes**, below the 5,000,000,000-byte cap. The current package hash and size are in [Playable/build-report.json](../Playable/build-report.json).

Next performance gate: run a native rendered, same-machine before/after traversal with comparable camera and route conditions; inspect frame-time p95, encounter median and the flashlight/prompt presentation. Stable 30 FPS and a human playtest remain open.
