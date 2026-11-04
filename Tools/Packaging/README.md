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

The optimized default disables the two practical room shadow maps while retaining illumination and flashlight shadows. Run `& '.\Playable\Launch Blackweb.cmd' --room-shadows` in PowerShell to opt into the original room-shadow flags. The launcher forwards this specific option after Godot's `--` separator; native 1280 × 720 and 2× MSAA remain unchanged. See [optimization evidence](../../Docs/OptimizationReport.md) for the performance tradeoff.

Official references: [PCKPacker](https://docs.godotengine.org/en/stable/classes/class_pckpacker.html), [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [Windows data-path implementation](https://github.com/godotengine/godot/blob/master/platform/windows/os_windows.cpp).
