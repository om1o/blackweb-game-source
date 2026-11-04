# Blackweb asset recovery

The tested console utility reads the unchanged UE5.3.2 game archives and exports portable GLB meshes, PNG textures, raw property JSON and animation USDA. CUE4Parse is pinned to commit e76778c10ed25860e11ec488750753224d067d87 (1.2.2.202611). The exact original runtime schema is preserved in Mappings/Arachnophobia-UE5.3.2.usmap; see exact-mappings-provenance.json.

Run run-recovery.ps1 (or run-recovery-nofmod.ps1) with --input, --out, --native-dir and --mappings paths. Select packages with repeated --package or --packages-file arguments. Use --format Gltf2 --geometry-only for meshes with retained material slots and no embedded images. Use --metadata-only for properties. USD supports animation output; the converter does not write animation directly into GLB. The default launcher invokes the tested source build without optional FMOD. Add -Build only when source changes.

## Recovered output contract

- RecoveredAssets/Geometry contains all 102 runtime house mesh GLBs, preserving package paths. They total 12,810,752 bytes, with zero embedded images. geometry-validation.json records each mesh and its material slot names.
- RecoveredAssets/Arachnophobia/Content contains shared PNG textures and the original Spider.glb. SpiderAnimated.glb preserves that original geometry, skin and material binary and appends the three recovered Idle, Walk and Run clips. The merge helper validates the entire 142-bone hierarchy, frame samples and quaternion data. Source cook sampled at about 1920Hz; the sampled durations are about 1.6495 seconds for Idle/Walk and 0.3161 seconds for Run.
- RecoveredAssets/Metadata contains raw property JSON, including material parameter arrays and Parent references. These retain evidence for Godot material reconstruction. Original Unreal shader graphs are not restored.
- The raw Map_House world metadata reports 130 root actors. The original runtime capture at Godot/data/recovered_components.json records individual instance placements and lights; use that capture for the house layout.
- RecoveredAssets/Audio contains six original BINKA streams and decoded WAV files. decode-report.json records actual decoder exit codes and audio properties.
- RecoveredAssets/ReferenceTexturedExports preserves the 22 preliminary house GLBs (21 runtime meshes and one probe wall) with duplicated embedded textures. A .gdignore excludes those reference copies from Godot import. They were moved, not deleted.

Each recovery-results.jsonl is append-only evidence of actual package/export results. Earlier failed probes remain in the history. RECOVERY-STATUS.json summarizes the current successful outputs. Metadata alone is not proof of a usable export; geometry-validation.json and the animation merge report provide additional structural checks. In-engine visual and gameplay verification is separate.

## Reproducible source variant

The original NuGet build encountered Windows Application Control denial of Fmod5Sharp.dll during eager core registration. Security policy and the blocked DLL were not changed. A separate build of the same pinned official source omits optional FMOD bank code, its three JSON converters and its package reference. ObjectTypeRegistry and non-FMOD parsing remain unchanged. prepare-no-fmod.mjs records these edits and adds the independent NAudio.Core2.2.1 dependency required by retained CriWare/HCA code. The NoFmod project references that source build. resolved-dependencies.json records the actual dependency graph, which contains no FMOD package.

Portable .NET10.0.403, caches, native helpers and scratch files reside on D: under D:/CodexTemp/Arachnophobia-Blackweb-20261103/work. The launcher sets D: paths for CLI home, NuGet, temporary files and bundle extraction. SETUP-LOG.md records the unintended first-run untrusted development certificate; no certificate was trusted and no existing certificate was changed.

## Tool provenance and licenses

- CUE4Parse and its native wrapper: Apache-2.0, https://github.com/FabianFG/CUE4Parse . LICENSE and third-party NOTICE retained in Licenses.
- ACL animation decoder: MIT, https://github.com/nfrechette/acl . ACL-LICENSE retained. The unchanged native DLL came from the official FModel November2026 release bundle; native-decoder-provenance.json records source and hashes. The FModel executable and blocked FMOD library were not executed.
- vgmstream r2168: original ISC-style license, https://github.com/vgmstream/vgmstream/releases/tag/r2168 . Official archive and DLLs remain in D: scratch; vgmstream-provenance.json records hashes and COPYING is retained in Licenses.
- Portable .NET SDK: official Microsoft distribution; license and third-party notices are included in its installation.
- Oodle helper follows CUE4Parse's upstream download mechanism. Source is https://github.com/WorkingRobot/OodleUE ; retain the downloaded helper with its recovery setup.
- ImageSharp remains the upstream3.1.12 pin for conversion of this local owned archive. NuGet reported security advisories. The3.2.0 upgrade was not used because its build requires a license key; no license requirement was bypassed. Tool dependencies are not part of the game runtime.
- User permission to reuse the supplied assets does not transfer ownership or grant additional rights. Original asset and third-party license terms remain applicable.
