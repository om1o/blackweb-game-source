ARACHNOPHOBIA: BLACKWEB — PLAYABLE HOUSE REBUILD

Double-click "Launch Blackweb.cmd" on Windows x86_64. Keep this folder together.
On a slower PC, double-click "Launch Blackweb Fast.cmd" for a 960x540
window with the Performance preset. This disables anti-aliasing while
retaining native 3D resolution; frame rate depends on the hardware and scene.
No Unreal Engine, Godot installation, export templates, source asset junction,
network connection, or account is needed to run this package. A compatible
graphics driver is required; Godot selects its OpenGL/ANGLE backend.
Godot 4.7.2 is bundled unchanged.

The default keeps room lights illuminated without their two expensive shadow
maps; the flashlight still casts shadows. To opt into the original room-shadow
setting, run "Launch Blackweb.cmd" --room-shadows from a command prompt.
This costs performance. Quality renders at full resolution with 2x MSAA.
Options > Graphics offers Performance: full 3D resolution and no MSAA,
while menus and text stay at the window resolution. This is the initial
preset on Intel HD Graphics 530; saved choices take precedence. You can
also pass --graphics=quality or --graphics=performance to the launcher.
A command-line override, including the Fast launcher, locks the picker for
that run. Use the regular launcher to change and save graphics in Options.

Controls: WASD move; mouse look; Shift sprint; C crouch; Space jump;
E interact; 1-3 draw a quick item; left click uses it; F toggles the flashlight
while equipped; I opens the 50-cell inventory; M expands the house map;
F1-F4 choose one of four status HUD layouts; Escape pauses or closes the
inventory or map. Both panels pause combat. Sprinting and
jumping use stamina. The Minimal HUD is selected by default. The three
starter quick items are weak flashlight, worn knife and one candy bar.
In the inventory, click an occupied backpack cell, then a quick-slot
button to equip it. Only those three items can be used during play.
Item covers are renders of the actual game models. The map tracks explored
rooms, your facing, doors and the current search area. Exploration is saved.
The four armor slots are separate: select a leather piece, then click
"Equip selected armor". Click a worn piece to remove it. A full leather
shirt, pants, hood and shoes give 18% damage reduction; maximum HP is 100.
Candy restores 30 health after the eating animation commits. At full health
it is kept. Finish an active eating/reload action before changing equipment.

Battery packs, bandages and flares can be found on house surfaces and by
opening and searching the entry drawer and hall cabinet with E. Search
each opened fixture once. Battery packs go into inventory and must be
equipped and used to restore their listed +35% or +30% charge, including
when found at full charge. The drawer also contains an optional Project 08
record. Papers open their illustrated document in a paused reader. Scroll or
use +/- to zoom, drag to pan, F to fit, and T for the readable transcript.
Press E or Escape to close. A focused paper or phone also accepts left click.
Follow Mica's call, take the vault key from the record-room shelf, and
salvage cells from the spare flashlight. Her interrupted plant clue leads
to the hidden code paper beside the plant, outside the locked vault. Use both key and code at the reinforced vault
door. Inside are four leather armor pieces and $120 for the persistent wallet.
The code is recorded in inventory after you read the note. Survive the
encounter and leave through the opening door. The house spiders are ordinary;
the company records describe experiments elsewhere in the story.
The 42-second opening film can be skipped with Enter, Space or Escape.
The opening starts quietly. Mica's call leads to unhurried clue hunting;
reading and inventory pause the tension clock. After preparation, a harmless
spider sighting precedes the power loss and the first attacking spiders.
The weak starter flashlight remains steady during onboarding, with ordinary
battery drain. Low-charge flicker begins only after that first warning beat.
Open Options for Master/Dialogue volume, output device and Test voice.
Options also includes fullscreen, reduced motion and HUD layout. Changes are
saved locally. The menus use the new Nov 05 UI & interaction pass footer.

The launcher stores saves and logs in this folder's UserData directory.
It changes environment variables only for its own child process. Source-project
saves are separate. Copy UserData too if transferring your progress. Use a
writable folder. Story, health, battery, inventory, armor, wallet and loot
claims are saved together in blackweb_campaign_v2.json with a previous valid
backup. "New Game" deliberately resets the run after confirmation. Existing old story
checkpoints are migrated once. Restart a previously open game after updating
the package so it loads the new version.

This package plays the tutorial opening of the Blackweb game, which is still
in development. Materials approximate the original shaders. Some pickups lack
authored hand animation, and some creature motions are procedural. The plant
and folded pickup kit remain prototype props. Equipped armor uses credited
MakeHuman artist garments fitted to Luke's existing rig with a leather material
adaptation. Voices are stock synthetic performances. The opening is a
HeyGen-generated moving film using the project's character and scene references.
Read Docs/VaultTutorialPass.md, Docs/NormalSpiderEffects.md and the earlier
Docs/Phase0Report.md for implementation details and remaining work.

Blackweb.pck contains scripts, scenes, recovered GLBs/JSON, imported textures
and import mappings. Original PNG payloads stay in the source project, while
the portable package uses their imported images. package-build-info.json
records source hashes; build-report.json records artifact hashes and the
packaging test state.
licenses contains Godot, Luke/MIT, and asset provenance notices. The user's
permission to reuse their supplied assets is not a blanket redistribution grant.

Rebuild from the source repository using Tools/Packaging/BuildPortable.ps1.
This package uses the official editor executable as a runtime with --main-pack;
it is not a separately compiled release-template executable.
