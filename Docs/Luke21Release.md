# Luke21, spider visibility and town-film release

This release makes the house spiders easier to notice, gives Luke the creator-requested youthful, handsome 21-year-old mixed Black and white identity, and replaces the opening with a complete 42-second moving video.

Adult spider visuals are 30% larger; juveniles are 60% larger. Body and head hit regions scale with the presentation, and adult navigation uses the same capsule as movement. The starting juvenile is placed inside the arrival camera's view with its eight-second grace period retained. Health, damage and flashlight slowdown are unchanged. Readability comes from chitin shading and spatial sound cues without additional lights or shadow passes.

Luke uses the existing compatible 80-bone rig with a new head sculpt, generated facial texture and fitted curls. His 8,746 triangles and four 1K material surfaces preserve existing hands, knife, flashlight, supplies and armour bindings. The actual game mesh is an approximation of the higher-fidelity Meshy cinematic reference. See [character sources](Luke21Character.md).

The HeyGen video uses the new character design, original town/home artwork and an actual game spider reference. Three moving shots show the web-covered town, an attack and dodge, and Luke entering the house. It retains the accepted synthetic Luke/Mica voices, live captions, Enter skip, natural completion and stalled-decoder recovery. It is not described as a human performance or a realtime render of the game mesh. The editable 3D alternate separately uses PINOC's free Open Door Push motion. Source clips and the reproducible compositor are under Tools/Cinematics.

## Verification

| Check | Result |
|---|---:|
| Character, hand contact and supply actions, native Godot | 51 passed |
| Knife swing with final character, native Godot | 16 passed |
| Tutorial journey, native Godot | 52 passed |
| House spider combat, native Godot | 18 passed |
| Spider suites, headless | 185 passed across eight suites |
| Arrival visibility, native render | 17 passed |
| Film playback, audio, skip and watchdog, native Godot | 18 passed |
| Intro fallback, native Godot | 19 passed |
| Editable town choreography | 11 passed |
| Standalone package, isolated directory | 65 passed |

The movie contains 1,260 frames at 30fps and 42 seconds of audio, with all streams decoded successfully. Frame review covered all three clips, the attack and the entry action. Native playback completed in 41.979 seconds with audible, unclipped dialogue. Native portrait, full-body, spider and source-film captures were visually reviewed. These checks do not imply every frame was watched and listened to by a person.

## Measured performance

The packaged five-room route ran on the Radeon RX550/550 at 960x540 using the Performance setting, warmed house and equipped armour. Mean frame time was **23.63ms** (about **42.3fps**), median **19.96ms**, 95th percentile **32.85ms**, and worst frame **2088.87ms**. This is one automated route measurement; it is not a promise of stable 60fps or hitch-free play. Raw evidence is in Evidence/Luke21/route.json.

The final Theora/Vorbis movie is 10,266,406 bytes, down from 16,732,946 bytes. Package size is 1,168,681,540 bytes. Its SHA-256 is `976eaab5ceea5eef67edaf434b18c1c7e00baa0873f8b9a412999c2ef521fe44`. The project is checked against the existing 5,000,000,000-byte budget before installation. Prior captures and previous build backups remain outside the active project. Installation preserves UserData and uses a validated replacement package.
