# Smiling Spider garden build — 7 November 2026

This pass replaces the temporary spider body with an independently authored Blender model and moves the encounter outside the house. It is a working art/combat prototype, not a finished AAA asset or the unavailable Meshy export.

## Delivered model and encounter

- Runtime GLB: `Godot/assets/generated/smiling_spider/smiling_spider.glb`, 14,696,368 bytes, 189,704 triangles, 31 bones and nine clips (idle, walk, death and six attacks).
- Four pale stone portrait sculptures, a wide grin, fangs, eight eyes, textured chitin and articulated legs. The portraits are sculptures, not remains.
- Garden courtyard, house exterior, locked research-annex gate, greenhouse silhouette, trees and modeled webs. Repeated architecture is merged by material.
- Enter through **Extras → The garden / Smiling Spider**, or **Enter the garden** after completing the house. Completion carries the player's survival snapshot; retry restores the entry loadout without overwriting the house checkpoint.
- Existing voiced lines now drive the jaw from measured audio envelopes. These remain stock synthetic Kokoro voices.

## Checks on the final model

| Check | Result |
|---|---|
| Boss integration | 77 checks, 0 failures in both headless and native RX550 runs |
| Menu rendering and completion route | 25 checks, 0 failures |
| Garden geometry/collision | Open sky, floor, house, boundary and gate all pass |
| Isolated portable package | 88 checks pass, including house startup, the new boss scene, lethal-hit cancellation and retry |
| Native Extras entry | Visible and within the 960×540 viewport |
| Native combat | All six attacks complete on the actual RX550 renderer |
| Render inspection | Connected leg segments in gameplay, sweep and leap captures |

The rig checks sample every leg chain in every attack and verify that the walking loop closes. A stale-parent-transform error found during the first render was fixed in the Blender pose bake before these results. The camera in offscreen captures ignores synthetic mouse events so the captures represent a controlled gameplay view.

A launch-log error exposed a lethal-hit cancellation bug that was reproduced on the current source: player recovery clears the attack synchronously, while the same update was still reading its recovery duration. The update now exits after a cancelling damage callback. Regression checks cover lethal bite, slam, leap and silk impacts, including no restarted hazards; they pass under both headless and native rendering. The launch verifier also uses a fresh log file for each process so a previous run's errors cannot be misattributed to a new build.

The corrected portable pack is 1,192,413,076 bytes, SHA-256 `1E1603D1A8063889315C04C9B52F9B98308D7474C5D1D4CC6AAE99773A3D1733`. Tests ran from an isolated directory and user-data profile.

The corrected garden installation completed with identical save/configuration hashes before and after replacement. Its native window was verified responsive for four seconds, with the RX550 renderer initialized and no script errors in its fresh launch log. The active project measured 4,951,572,055 bytes before adding the final single-image reference, below the 5,000,000,000-byte limit.

At 960×540, the final quality-preset run sampled 1,117 frames: mean 20.43 ms, p95 37.52 ms. The performance-preset run sampled 1,182 frames: mean 19.22 ms (about 52 FPS), p95 32.06 ms. These bounded automated runs on a Radeon RX550 show remaining frame-time spikes; they do not establish a locked 60 FPS or game-wide performance guarantee.

## Actual rendered artifacts

- [Blender studio render](Design/smiling-spider-blender-render-v2.png).
- [Outdoor gameplay capture](Design/smiling-spider-garden-gameplay-v2.png).
- Editable final master: `D:/GameProjects/Blackweb-BossWorkshop/SmilingSpider-v2/smiling_spider_final.blend`.
- [Attack reel](Design/smiling-spider-attacks-v2.mp4). Godot Movie Maker recorded 717 frames at 30 FPS, 1280×720 (23.9 seconds), using the actual mesh, rig, combat timeline and effects. The reel adds a fixed review camera and fill light; it is not a first-person gameplay recording. The uncompressed recording remains in the external workshop.

The reproducible geometry, refinement, material finishing and animation rebake scripts live in `Tools/Assets`. The original imagegen material and exact prompt are retained in `Tools/Assets/References`.

The later [axe turnaround concept](Design/smiling-spider-axe-turnaround-v1.png) is an imagegen reference sheet requested after this game build. It shows front, rear, both sides, three-quarter and top views, with the front limbs gripping a huge axe. It is concept art only; this weapon and altered forelimbs are not present in the shipped GLB or its six attacks. Its exact prompt is stored alongside the image.

The user's refined direction is the [single cinematic axe reference](Design/smiling-spider-axe-cinematic-reference-v1.png): a photorealistic creature image outside the house, with wet chitin, stone busts and a huge held axe. This generated reference is an art target, not a screenshot of the current game model. Its exact prompt is also retained.

## Storage and remaining work

Unused imported derivatives, superseded extracted textures and the ignored `Tools/Recovery/bin` build cache were archived to `D:/CodexTemp/Blackweb-BossPass/`. Sources and recovered game assets were retained. Blender masters and the uncompressed movie remain in the external workshop to respect the active-project 5 GB limit; the 1.8 MB compressed reel is retained with the source documentation.

The crown, anatomy, surface detail, environment dressing and voice acting still need an art-direction pass. The boss defeat does not yet implement the planned capture and greenhouse wake-up story sequence. The original Meshy task still exposes no supported downloadable model formats; no new paid generation or subscription was used.
