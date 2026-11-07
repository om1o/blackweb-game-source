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
| Boss integration | 69 checks, 0 failures |
| Menu rendering and completion route | 25 checks, 0 failures |
| Garden geometry/collision | Open sky, floor, house, boundary and gate all pass |
| Isolated portable package | 85 checks pass, including house startup and the new boss scene |
| Native Extras entry | Visible and within the 960×540 viewport |
| Native combat | All six attacks complete on the actual RX550 renderer |
| Render inspection | Connected leg segments in gameplay, sweep and leap captures |

The rig checks sample every leg chain in every attack and verify that the walking loop closes. A stale-parent-transform error found during the first render was fixed in the Blender pose bake before these results. The camera in offscreen captures ignores synthetic mouse events so the captures represent a controlled gameplay view.

The validated portable pack is 1,192,411,860 bytes, SHA-256 `29E1C9BBF3D96432F6BA128B9C5D7180B4DE66DD1BD30D7012657310CCAAD650`. Tests ran from an isolated directory and user-data profile.

At 960×540, the final quality-preset run sampled 1,117 frames: mean 20.43 ms, p95 37.52 ms. The performance-preset run sampled 1,182 frames: mean 19.22 ms (about 52 FPS), p95 32.06 ms. These bounded automated runs on a Radeon RX550 show remaining frame-time spikes; they do not establish a locked 60 FPS or game-wide performance guarantee.

## Actual rendered artifacts

- [Blender studio render](Design/smiling-spider-blender-render-v2.png).
- [Outdoor gameplay capture](Design/smiling-spider-garden-gameplay-v2.png).
- Editable final master: `D:/GameProjects/Blackweb-BossWorkshop/SmilingSpider-v2/smiling_spider_final.blend`.
- [Attack reel](Design/smiling-spider-attacks-v2.mp4). Godot Movie Maker recorded 717 frames at 30 FPS, 1280×720 (23.9 seconds), using the actual mesh, rig, combat timeline and effects. The reel adds a fixed review camera and fill light; it is not a first-person gameplay recording. The uncompressed recording remains in the external workshop.

The reproducible geometry, refinement, material finishing and animation rebake scripts live in `Tools/Assets`. The original imagegen material and exact prompt are retained in `Tools/Assets/References`.

## Storage and remaining work

Unused imported derivatives, superseded extracted textures and the ignored `Tools/Recovery/bin` build cache were archived to `D:/CodexTemp/Blackweb-BossPass/`. Sources and recovered game assets were retained. Blender masters and the uncompressed movie remain in the external workshop to respect the active-project 5 GB limit; the 1.8 MB compressed reel is retained with the source documentation.

The crown, anatomy, surface detail, environment dressing and voice acting still need an art-direction pass. The boss defeat does not yet implement the planned capture and greenhouse wake-up story sequence. The original Meshy task still exposes no supported downloadable model formats; no new paid generation or subscription was used.
