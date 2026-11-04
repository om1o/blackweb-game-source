# Blackweb progression verification

`ProgressionTests.cpp` exercises the production `BWProgression.h` rules without Unreal.
The test translation unit is empty in an ordinary Unreal build; it only defines a
test executable when `BLACKWEB_PORTABLE_TEST` is set.

On 2026-11-03, compiled with installed MSVC 14.38.33130, C++17, `/W4 /WX`, then ran:

```text
PASS: 133429 checks; both pickup orders, exit gates, all 8192 persisted flag/stage combinations, reachable completion, idempotent restore, unknown-schema rejection.
```

Coverage includes early/duplicate interaction rejection, interrupted-message
restore, either item pickup order, encounter retry flags, exit gating, completed
save restore, all 256 persisted stage bytes combined with all 32 flag combinations,
and completion reachability after repairing each possible persisted state.

To repeat from a Visual Studio x64 Developer PowerShell, with an existing scratch
output directory and the current directory set to the project root:

```powershell
cl /nologo /std:c++17 /EHsc /W4 /WX /DBLACKWEB_PORTABLE_TEST /I Source\Blackweb\Public Source\Blackweb\Tests\ProgressionTests.cpp /Fe:work\ProgressionTests.exe /Fo:work\ProgressionTests.obj
if ($LASTEXITCODE -eq 0) { .\work\ProgressionTests.exe }
```

This is a portable state-machine test, not an Unreal compile, editor test,
packaged-build test, performance measurement, or human playtest. It does not verify
Unreal SaveGame I/O, scene collision, mesh/animation setup, lighting, or audio.
Those require the engine and actual scene.

## Runtime integration

- Place one `BWIntroDirector`. The game mode creates a fallback if none exists.
- Place `BWInteractable` actors with `Kind` set to Phone, Flashlight, Keys, ExitDoor.
  Assign their `Visual` meshes and size their `InteractionBounds` around the prop.
  Do not use the interaction box as the house's physical collision.
- Give the game mode a `PlayerMesh` and `PlayerAnimationClass`, or use a configured
  subclass of `BWPlayerCharacter`. No asset paths are embedded in C++.
- Subscribe scene lighting/audio to `StageChanged` and `PowerChanged`. Stage enums
  are Normal, Message, Preparation, Presence, PowerLoss, Encounter, ReadyToLeave,
  Complete. Message timing is controlled by the editable `MaraLines` array.
- The second required pickup enters Presence automatically. Presence and power-loss
  timers are adjustable or can be disabled with `bAutoAdvanceAtmosphere`.
- Timed encounter completion is a fallback. Set `bUseTimedEncounterResolution=false`
  when a working encounter exit uses `ResolveEncounter()`.
- `CheckpointAnchor` is a safe character-center transform, not a floor point.
  Without one, the character uses its initial spawn transform. Check that the
  anchor is unoccupied and capsule-clear. F9 reloads the last saved milestone.
- Saving uses a versioned main slot plus the previous valid milestone as backup.
  An unknown main schema is preserved, with writes blocked until an explicit
  `RestartOpening()`. Required pickups reappear correctly on reset/reload.
- `TryLeaveHouse()` only succeeds after warning, both items, and encounter survival;
  the HUD then shows a chapter end card and `OnHouseDeparture()` fires. R on that
  card replays the opening, including when a completed save was loaded at launch.
- The player accepts Unreal damage through `TakeDamage`: 100 health by default,
  brief configurable movement slowdown on a hit, then a 1.1-second defeat recovery
  at zero health. No weapons or camera shake are introduced. During recovery,
  movement/look/interaction/flashlight/manual retry are blocked, and director
  progression timers pause. Recovery reloads disk state, or replays the current
  in-memory milestone if disk loading fails; unknown save schemas are preserved.
  Reset and EndPlay clear the recovery timer. These engine-dependent paths have
  received source review only, not a runtime test.

The code supplies interaction and progression behavior. Recovered character
animation, actual held flashlight alignment, Mara voice/audio, scene dressing,
light/sound events, and rendered quality still require scene/asset integration.
