# House atmosphere integration

Place one `BWAtmosphere` and assign the level's `BWIntroDirector` to `IntroDirector`.
It can find a placed director once at BeginPlay; there are no repeating actor searches.

Assign lamp/ceiling-light actors to `PracticalLights`. Assign window fill and skylight
actors to `FillLights`. All light components on those actors are cached once, including
their authored intensity and visibility. Fill takes precedence if an actor appears in
both arrays. Use runtime-adjustable lights; baked static lighting cannot be switched
off by changing a light component's intensity.

- Normal/message/preparation: original practical and fill intensities.
- Presence: slow, low-amplitude practical-light dimming, default 10%, capped at 20%.
- Power loss onward: practicals fade to zero; fill/window intensity stays unchanged.
- Restart/checkpoint: the director's stage and power delegates restore the corresponding
  light state from the original cached values. EndPlay also restores authored values.

The actor ticks at 0.05 seconds only while lighting/audio is changing or presence
dimming is active. It disables its tick when settled. No light actors are spawned.

Audio assets are optional and deliberately unassigned in source:

| Property | Purpose |
| --- | --- |
| `RoomTone` | Quiet, non-spatial household ambience; repeats on completion, or may be an authored looping cue. |
| `PresenceScratch` | One brief spatial cue when entering Presence. |
| `ScratchSourceMarker` | Actor whose location places that cue behind/above a wall. |
| `PowerCut` | Brief spatial power interruption cue at the atmosphere actor's location. |
| `SpatialAttenuation` | Optional authored attenuation; defaults use a small inner radius and 10 m falloff. |

Room tone decreases with the power change and fades out at the end card. Cues have
restrained editable volume defaults; there is no horror-music loop. Assign only
authorized, reviewed sounds. Check audibility and spatial position in the actual
house; this source work does not establish audio or lighting quality.

The power-cut sound is edge-triggered separately from the stage event, so receiving
StageChanged before PowerChanged does not suppress it. Loading an already-dark save
does not play a fresh power-cut sound. Fill lights never participate in flickering.

Validation so far: static source review only. UnrealHeaderTool, engine compilation,
PIE, recovered-asset integration, rendered comparison, and performance profiling
remain pending an installed engine.
