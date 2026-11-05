# Portable packaging

Run from the repository root in PowerShell:

```powershell
& '.\Tools\Packaging\BuildPortable.ps1' -PlanOnly
& '.\Tools\Packaging\BuildPortable.ps1'
& '.\Tools\Packaging\TestPortable.ps1'
```

The first command measures the proposed output without starting Godot. The second creates `Playable/Blackweb.pck`, copies the existing official Godot 4.7.2 Windows runtime, records source/artifact hashes, and includes license notices. It requires finished Godot imports and a stable source tree. Source changes detected during packaging cause failure. The third runs the bundled package from an isolated directory outside the project and records `Playable/portable-smoke.json` and logs. The default scratch directories are on D:; no export-template download or installation is used.

The Blackweb tutorial-opening PCK keeps all recovered GLB/JSON inputs, `.import` settings, and their referenced Godot texture caches. It replaces 248 recovered source PNG payloads with zero-byte files at the same paths. `FileAccess.file_exists` still sees these paths, while `ResourceLoader` follows their `.import` remaps to the full imported textures. This removes about 907 MB of duplicate source texture bytes from the portable PCK without changing any original source PNGs. The isolated smoke test checks every remap, loads a sample image, and verifies runtime material overrides. Use `-KeepRecoveredSourcePngs` with `BuildPortable.ps1` to make the larger full-source package if a future engine change breaks this arrangement.

To test a new package without replacing the current `Playable`, pass the same separate D: directory as `-OutputRoot` to both scripts. The test script writes its logs there and only copies evidence into the project when testing the canonical `Playable` directory. The builder omits archived reference GLBs, source animation USDA, source Luke FBX/TGA copies, previous scene backups, and editor state. The runtime uses imported Luke textures and the assembled Luke scene.

All required runtime asset paths resolve inside the package; provenance metadata may still name original locations. `package-build-info.json` embedded in the PCK lists every packaged input except itself; the outside copy and build report support auditing. The builder counts regular files once and skips junctions when enforcing the 5,000,000,000-byte total source-plus-Playable limit. Scratch data and the separate original-game backup are outside that project budget.

`portable_smoke.gd` is included only in the package as `res://tools/portable_smoke.gd`. Launch it with the bundled console runtime from an empty directory outside the source project, using `--headless --main-pack <absolute Blackweb.pck> --script res://tools/portable_smoke.gd -- --report=<absolute writable json>`. Set APPDATA, LOCALAPPDATA, TEMP and TMP to that test directory first. It verifies packaged raw/import inputs, source hashes, main scene, runtime props/materials, Luke, spider, and audio. It does not substitute for rendered or full-route playtesting.

The launcher keeps saves/cache/logs under `Playable/UserData` through process-local environment variables. It leaves Windows user or system settings unchanged. Rebuilds preserve existing UserData, and preflight includes those retained bytes in the storage estimate. The temporary replacement PCK stays on D: outside the source-plus-Playable budget until the completed pack replaces the old generated artifact.

The optimized default disables the two practical room shadow maps while retaining illumination and flashlight shadows. Run `& '.\Playable\Launch Blackweb.cmd' --room-shadows` in PowerShell to opt into the original room-shadow flags. The launcher forwards this specific option after Godot's `--` separator. Quality uses native 3D resolution with 2× MSAA; Performance keeps native resolution and disables MSAA. The Fast launcher selects 960×540 and a Performance override. See [current interface and graphics evidence](../../Docs/InterfaceAndPacingRelease.md); [OptimizationReport.md](../../Docs/OptimizationReport.md) describes the earlier room-shadow pass.

Official references: [PCKPacker](https://docs.godotengine.org/en/stable/classes/class_pckpacker.html), [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [Windows data-path implementation](https://github.com/godotengine/godot/blob/master/platform/windows/os_windows.cpp).

## Private source plus tested playable handoff

After committing the intended source and passing `TestPortable.ps1` on the final build, run:

```powershell
& '.\Tools\Packaging\BuildAIHandoff.ps1'
# Optional: include selected current evidence, without copying all historical output.
& '.\Tools\Packaging\BuildAIHandoff.ps1' -EvidenceFiles @('Evidence/menu-main.png','Evidence/menu-options.png','Evidence/menu-inventory.png','Evidence/horror-menu-tests.json','Evidence/menu-rendering-tests.json')
```

Each invocation creates a unique `Blackweb-InterfaceRelease-<UTC>-<commit>-<suffix>.zip` under `D:\BlackwebHandoffs`, its SHA-256 sidecar, a validation report and retained staging directory. It refuses dirty/uncommitted source, stale package/source or launcher hashes, failed/mismatched portable smoke reports, and payloads over 5,000,000,000 bytes. It validates every ZIP file against its SHA-256 manifest and exact entry count. It never launches Godot, uploads files, replaces an old archive or includes personal saves.

The handoff includes Git-tracked source, explicit recovered house/adult-spider inputs and derived scenes/data, source import settings, the tested portable runtime/PCK and notices. It omits Git internals, `.godot` caches, unused restricted candidates, both raw Literock roots and all standalone imported derivatives. Literock remains only inside the packaged game; its notice/link is included, and editable source uses the existing CC0 fallback unless the recipient independently obtains the asset. This is private owner-authorized collaboration content: the supplied recovered game art has no separately documented public redistribution grant. See `Docs/ASSET_PROVENANCE.md` and the [creator's Literock terms](https://literock-studios.itch.io/giant-spider-lite).

The archive's root launchers run the packaged game or prepare an extraction-relative recovered-asset junction and open/import editable source with the same bundled runtime. Source import caches are regenerated on first editor/source use. ZIP, staging, extraction and newly generated caches need additional free space outside the project budget. This integrity check does not substitute for a new relocated native test; the script records that distinction. `-PlayableRoot` can select a tested staged package; `-OutputRoot` must remain on D: outside the source project.

The explicit `ArmorAuthoringInputs.json` allowlist also includes 18 external authoring inputs under `Handoff/Authoring/Armor`: the final fitted and Luke reference `.blend` scenes, four selected garment OBJs, eight color/normal maps and four source license headers. It excludes whole archives, unused candidates, thumbnails, specular maps and backups. These are copied directly from `-ArmorAuthoringRoot` (default `D:\CodexTemp\Blackweb-RealArmor-20261105`) into the external handoff stage, so no large authoring files are added to the game project. Their bytes count toward the handoff cap and every file is hashed in its manifest. Missing inputs fail the build.

The included armor README, `relink_blend.py` and `rebuild_armor.py` resolve the extracted project and selected inputs without the original scratch path. They preserve delivered scenes when creating a relinked editing copy, and the rebuild wrapper runs the committed fitting pipeline with only directory constants changed. Blender is required only for this optional authoring workflow. Packaging validates input existence, sizes and archive integrity; it does not launch Blender or claim a relocated regeneration test.
