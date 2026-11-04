# Luke character asset

Luke uses Microsoft Rocketbox's `Male_Adult_04`, selected from its official preview for this rebuild. This is a separately sourced, MIT-licensed character, not a recovered asset from the original Arachnophobia package.

## Source and license

- Repository: <https://github.com/microsoft/Microsoft-Rocketbox>
- Pinned commit: `0943055db6ec570bcef9f2c8b41c9e5467c808f9`
- License: MIT, copyright (c) 2020 Microsoft. Keep `Godot/assets/luke/LICENSE.md` and `NOTICE.txt` with redistributed copies.
- `Godot/assets/luke/provenance.json` records every downloaded file's official URL, byte count and SHA-256 checksum.
- Plain rigged FBX, seven TGA textures and idle/walk/run FBX clips: 96,079,844 bytes, plus the 1,066-byte license. No account, purchase, agreement click, external conversion tool or full repository clone was needed.

The original directory relationship between `Export/Male_Adult_04.fbx` and `Textures/` is preserved. Source animation files are in `Animations/`. Original downloads remain unmodified.

## Rebuilding

Godot 4.7.2 uses its built-in ufbx importer. Run the editor import to completion before the builder:

```powershell
& .\Godot\runtime\Godot_v4.7.2-stable_win64_console.exe --headless --path .\Godot --editor --import --quit
& .\Godot\runtime\Godot_v4.7.2-stable_win64_console.exe --headless --path .\Godot --script res://tools/build_luke.gd
```

Do not run another project import concurrently. The first import can take several minutes on this machine.

## Runtime contract and adaptations

Load `res://scenes/luke.tscn` with `player.attach_model(scene, 1.0)`. Its root is an identity `Node3D`; feet start at local Y=0, idle standing height is 1.75 metres, and the character faces local -Z. `AnimationPlayer` is a direct child and contains looping `idle`, `walk`, and `run`, plus `RESET`. Idle autoplays. The player controller owns world translation and turns the visual root.

The actual source contains one high-detail mesh, three material surfaces and an 81-bone skeleton. No overlapping LOD meshes remain. Skinning resources and animations are embedded in the assembled scene; the only external scene dependencies are five textures at their exact, case-correct `Textures/` paths. The source FBX's lowercase texture references cause warnings during its first import, but are not retained as dependencies of the playable scene.

The builder preserves the source skeleton and animation rotations, removes animation-authoring Footsteps/MotionExtractionHelper tracks, fixes root X/Z translation at zero and preserves vertical motion. It calculates scale and grounding from CPU-skinned vertices, rather than the raw source mesh AABB (which is Z-up before skinning). A 180-degree Y rotation changes source +Z facing to Godot -Z. A conservative custom culling AABB covers the animated body.

Materials use original albedo and normal textures, restrained nonmetallic roughness, and double-sided alpha scissor for the source opacity material. Original specular maps are retained in the licensed source bundle; they are not misinterpreted as metallic maps.

## Validation performed

Godot 4.7.2 imported all four FBX files and seven TGA textures. The builder passed with exit code 0, with no final build warnings. It validated every animation node and bone path, every skin bind, zero horizontal root motion, the 1.75-metre idle bounds and -Z facing, nine skinned poses per clip, and loading the saved scene from disk.

| Clip | Duration | Bound tracks | Removed helper tracks | Lowest sampled vertex |
| --- | ---: | ---: | ---: | ---: |
| idle | 2.733 s | 66 | 3 | -0.000354 m |
| walk | 1.067 s | 61 | 4 | -0.000514 m |
| run | 0.767 s | 37 | 4 | -0.006059 m |

Exact build measurements are recorded in `Godot/assets/luke/validation.json`; the final log is `Godot/assets/luke/build.log`. These are import and deformation checks. In-game lighting, camera composition and movement speed matching are checked by the main scene integration work.
