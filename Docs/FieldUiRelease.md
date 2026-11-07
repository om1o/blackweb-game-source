# Model covers, house survey and objective tracker

The inventory now shows the actual item models in each occupied cell and quick slot. Ten transparent 256-pixel images were rendered in Godot from the same meshes Luke holds or wears: flashlight, worn knife, candy, battery, bandage, flare and four leather pieces. Small stack counts and quick-slot numbers preserve useful information without covering the models. The selected-item panel uses the matching image. Inventory capacity remains 50 cells with three active items.

The map now follows the five-room layout, shows Luke's facing, live interior door states, the exit and visited-room shading, and records exploration in the campaign save. **M** opens a larger survey and pauses combat; **M or Escape** returns to play. **I** switches from the map to inventory while keeping combat paused. Room names appear after discovery. An objective diamond identifies a search area, never the exact hidden paper or its code.

The objective panel gives one current task, a short hint and four story milestones. It follows real progression and updates when the key, hidden note, vault, exit keys or silk lock changes. During combat it replaces the search marker with a survival instruction. It hides during menus, inventory, the map and the intro.

## Art and implementation

The [design concept](Design/field-ui-concept-v2.png) was generated with **built-in imagegen**. Its [exact prompt](Design/FieldUiImagePrompt.txt) is retained. The delivered UI is native Godot code; the concept image is not loaded into gameplay. Item covers are renders of existing models, not generated substitutes. Their builder and per-image SHA-256 records are in `Godot/tools/bake_item_covers.gd` and `Godot/assets/generated/item_covers/provenance.json`. Underlying asset credits remain in [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md).

The images are cached and shared across cells. The map redraws at 10 Hz using 2D geometry. This avoids a separate 3D camera for each inventory cell or the map. No frame-rate improvement is claimed without a new performance measurement.

The separate [first boss plan](FirstBossPlan.md) proposes the later greenhouse capture and awakening. It is a design document, not an implemented boss.

## Verification

Native captures use the real running house; the ten-item inventory shown in QA includes test supplies to exercise every cover. The player's saved inventory is preserved during installation.


| Check | Result |
|---|---:|
| Field UI state, geometry, covers and layout | 39 passed |
| Assembled house UI, native renderer | 14 passed |
| Inventory ownership, capacity and equipment | 23 passed |
| Campaign persistence and validation | 54 passed |
| Escape route, actual mouse input and lock cutting | 30 passed |
| Standalone package in an isolated directory | 76 passed |

All three native house UI captures were inspected. The older escape fixture was updated for the existing authored animation library and the current 0.95-second knife action; it now explicitly requires a native window for mouse input. A JSON round-trip check restores numeric room IDs through the same conversion used by the game. Earlier test failures were resolved before packaging.

Source and installed package hashes are verified during promotion. UserData is checked before and after installation. Raw evidence is retained in `Evidence/FieldUI/`.

Package size: **1,169,127,720 bytes**. SHA-256: `31ae5b1d72bd4f727444b4e4a85a3085d775f422cc90e146ba3230e05daa955f`.
