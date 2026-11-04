# Spider encounter integration

`ABWSpiderEncounter` is a floor-bound `ACharacter` with a standard `AAIController`. It requires the `AIModule` and `NavigationSystem` modules. Source implementation is complete; engine compilation and in-editor playtesting are still required.

## Scene wiring

1. Place a `BWSpiderEncounter` at the intended reveal point, with its capsule on the floor (default half-height: 32 cm). Do not put it inside furnishings. Build a NavMesh covering the room and escape route.
2. Assign the recovered spider skeletal mesh to its inherited Mesh component. Adjust mesh scale, yaw and vertical offset using the actual imported asset; the source deliberately assumes no bone names or asset paths.
3. Assign matching-skeleton idle, walk and run sequences to `IdleAnimation`, `WalkAnimation`, `RunAnimation`. Reference speeds default to 165/420 cm/s and need visual stride calibration. Root motion is ignored; capsule movement is authoritative. Missing clips do not synthesize animation.
4. Set `IntroDirector`. With `bAutoBindDirector` enabled, it also finds the director if unassigned and listens for the Encounter stage automatically. Only one encounter spider should be wired to this director.
5. Set `SafeExitAnchor` to a marker inside the escape route and `RetreatAnchor` to a nearby clear patch of navigable floor away from the exit. Keep the safe marker outside the reveal/spawn area. Alternatively, have a player-filtered exit trigger call `ResolveAtExit()`.
6. Disable the director's `bUseTimedEncounterResolution` after verifying the safe region is reachable. The optional safe marker requires 1.25 seconds inside 160 cm, then a 1-second resolution beat. Reaching safety cancels attacks immediately when the hold finishes. The director's existing timer can remain enabled for an initial smoke test.
7. Assign licensed/recovered `WindupSound` and `LungeSound`, or bind `OnEncounterStateChanged` to appropriate presentation cues. `OnThreatenedPlayer` is a close-call cue with no implicit damage or checkpoint reload.

## Behavior

The spider waits hidden and disables actor, mesh and character-movement ticking outside its encounter. It pauses for 1.5 seconds, stalks at 165 cm/s, faces the player for a 0.85-second windup, then lunges toward the player's committed position for at most 0.7 seconds. A short retreat and 2.6-second cooldown give the player space to leave. Live movement uses NavMesh path following, bounded acceleration, capsule collision and ground movement. There is no wall climbing or procedural leg placement.

Attacks require a clear visibility ray and capsule-width collision sweep, similar floor height, and range, both after the windup and before a close-call event. Stepping behind geometry or out of range cancels the lunge. Failed navigation stops movement and pauses; it never teleports the spider or switches to geometry-ignoring movement. A hidden reposition to the original placement occurs only when restoring a pre-encounter checkpoint/stage.

## Required engine verification

- Compile in UE 5.3.2 and verify all imported clips use the assigned spider skeleton.
- Check capsule/mesh scale and foot contact on the actual house floor, stairs and thresholds. Avoid placing the encounter on stairs if the imported mesh has no suitable animation.
- Walk away during anticipation, sidestep a lunge, and step behind a closed door during windup. Confirm no threat event passes through the door.
- Remove/block a nav route: spider should pause or retreat, while the escape path remains usable.
- Reach the safe marker, reload a saved pre-encounter checkpoint, and repeat. Confirm timers stop, the encounter resets, and leaving the house completes the director flow.
- Inspect behavior at low frame rates; actor rotation and movement are time-based, decisions run at 0.12-second intervals.

API references checked: [AAIController](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/AIModule/AAIController), [MoveToLocation](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/AIModule/AAIController/MoveToLocation). Version-specific UE 5.3 documentation was unavailable through the lookup tool; these references do not substitute for compiling against the installed engine.
