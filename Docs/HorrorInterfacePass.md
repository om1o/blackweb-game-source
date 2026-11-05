# BLACKWEB interface pass — 2026-11-05

The game uses a corridor illustration, original BLACKWEB identity, Barlow typography, charcoal panels, ivory text, subdued green selection and muted red health. The menu is one 2D interface over a static bitmap with a slight optional drift; it creates no additional 3D scene.

## Behavior

- Start begins a new tutorial. A valid saved campaign enables Continue. An unsaved active run still has Resume when paused. Replacing existing progress opens an explicit in-game confirmation.
- Options immediately changes the game's Master and Dialogue buses, sound output, fullscreen state, reduced motion and HUD layout. `user://blackweb_settings.cfg` persists these choices independently of campaign progress. An unavailable saved output falls back to system default. This never changes Windows master volume.
- Test voice uses the existing Soundscape API and reports missing voice files, no available audio driver, muted in-game volume or the selected playback route. Successful playback is not proof that a person's physical speakers are audible.
- Reduced motion disables corridor drift, menu page fades and arrival-camera motion while retaining arrival captions and skip controls.
- Graphics offers Quality (100% 3D / 2× MSAA) and Performance (100% 3D / no MSAA), with unchanged 2D UI. The reverse-order native comparison found 75% scaling consistently slower on this Intel HD530/ANGLE setup, so the final Performance preset preserves native detail. Intel HD530 defaults to Performance only when no preference exists. `--graphics=quality` / `--graphics=performance` after the engine argument separator overrides one session for repeatable testing. The menu reversibly stops its parent viewport's hidden 3D drawing while visible. Details and measurement limits are in `IntelGraphicsAudit.md`.
- Extras contains controls, story context and concise source/license credits. The footer identifies this build as `House / Nov 05 UI & interaction pass`.
- Inventory keeps 50 cells, three usable quick items, separate four-piece armor equipment, wallet, condition, supplies and discovered records. The selected item provides a short usage summary. Empty cells, tooltips and keyboard focus remain available.
- The selected item thumbnail clones only the actual item's static mesh geometry/materials into an isolated 256-pixel viewport, frames its bounds and renders once. The viewport stops drawing until selection changes; no player rig, scripts or collision are cloned. Opening the same item again reuses the texture. The fixture reviews the real worn-knife factory output.
- The chosen Minimal gameplay HUD keeps thin health/stamina/battery meters and three item glyphs. Main objective, prompt, notice and subtitle labels inherit the same bundled body font.

## Implementation and source

`horror_theme.gd` is the shared palette/font/style helper used by menu, inventory and field overlays. Barlow Regular/Medium and Barlow Condensed SemiBold are unmodified official Google Fonts binaries under SIL OFL 1.1; attribution and the full notice are beside them in `assets/fonts/barlow`. Raw TTF bytes must be retained in packaged exports because the helper loads them directly.

Menu ticks are short, original synthesized PCM signals. There is no continuous menu score. The corridor bitmap was created for BLACKWEB; it depicts an atmosphere rather than a promise of geometry in the playable house.

The generated worn-steel nine-slice is used as a restrained physical panel frame; shared button styles add a thin rim, shallow shadow and pressed offset. The artwork is original, while information, controls and text remain native UI.

Relevant primary references:

- [Godot AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html): per-game output devices, bus gain and mute.
- [Godot DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html): fullscreen/windowed state.
- [Godot ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html): local preferences.
- [Google Fonts Barlow](https://github.com/google/fonts/tree/main/ofl/barlow), [Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed) and [upstream Barlow project](https://github.com/jpt/barlow).

## Verification

The standalone `tools/capture_horror_menu.gd` fixture exercises game-menu state, native input, settings persistence and bus changes, HUD visibility restoration and the inventory contract. It writes `Evidence/horror-menu-tests.json` plus native `Evidence/menu-*.png` captures without loading the house or touching existing saves. The focused intro lifecycle suite also checks reduced-motion camera behavior and restoration.

Native UI result: **37 checks, 0 failures**, including real mouse/Enter/Escape input, real fullscreen/windowed changes, the Graphics selector and Options/inventory bounds, and actual worn-knife model rendering with its viewport stopped afterward. Screenshot review caught and corrected an initially oversized Options panel, invisible zero-height slider rails and an overly end-on item camera. Captures: `menu-main.png`, `menu-options.png`, `menu-extras.png`, `menu-inventory.png`; these precede the final native-resolution Performance label/copy correction. The Options body scrolls independently while Test voice, Back and saved status remain visible.

Menu rendering/settings lifecycle: **23 checks, 0 failures** (`Evidence/menu-rendering-tests.json` / `.log`), rerun after the final native/no-MSAA Performance correction, including restoration of the original viewport state on hide and destruction, separate preview isolation, both graphics presets, CLI precedence, preference reload and hidden-inventory updates. Closed inventory text formatting is deferred; reopening refreshes health, stamina and battery even when selection is unchanged. The live Minimal meters continue to update.

Reduced-motion arrival lifecycle: **19 checks, 0 failures** (`Evidence/tutorial-intro-tests.json` / `.log`). All owned test processes exited 0 with clean teardown. The native log includes the already-known Intel OpenGL warning and successful ANGLE fallback; it contains no script errors or leaked-resource reports.

Full-house Start/New Game and campaign reset are verified separately by the assembled journey fixture. Standalone captures are UI reviews, not a human playtest or a claim of finished production art.
