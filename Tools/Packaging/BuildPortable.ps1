param(
    [switch]$PlanOnly,
    [switch]$KeepRecoveredSourcePngs,
    [string]$OutputRoot = '',
    [string]$ScratchRoot = 'D:\CodexTemp\Arachnophobia-Blackweb-20261103\work\portable-packaging',
    [long]$ProjectBudgetBytes = 5000000000
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$godotRoot = Join-Path $projectRoot 'Godot'
$recoveredRoot = Join-Path $projectRoot 'RecoveredAssets'
$canonicalPlayableRoot = Join-Path $projectRoot 'Playable'
$playableRoot = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { $canonicalPlayableRoot }
$writingCanonicalPlayable = [string]::Equals($playableRoot.TrimEnd('\'), $canonicalPlayableRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
if (-not $writingCanonicalPlayable -and $playableRoot.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Temporary portable output must be outside the source project.'
}
$runtimeName = 'Godot_v4.7.2-stable_win64.exe'
$consoleName = 'Godot_v4.7.2-stable_win64_console.exe'
$godotConsole = Join-Path $godotRoot ('runtime\' + $consoleName)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inputFiles = @{}
$elidedSourcePngCount = 0
[long]$elidedSourcePngBytes = 0
function Add-InputFile([string]$Source, [string]$Resource) {
    if ($inputFiles.ContainsKey($Resource)) { return }
    $item = Get-Item -LiteralPath $Source
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "A package input must be a regular file: $Source"
    }
    $inputFiles[$Resource] = [ordered]@{ path = $Resource; source = $item.FullName; bytes = $item.Length; modified_ticks = $item.LastWriteTimeUtc.Ticks }
}
function Add-InputTree([string]$Source, [string]$Resource, [scriptblock]$Filter, [bool]$SlimRecoveredPngs = $false) {
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected linked input: $($item.FullName)" }
        $target = $Resource + '/' + $item.Name
        if ($item.PSIsContainer) { Add-InputTree $item.FullName $target $Filter $SlimRecoveredPngs }
        elseif (& $Filter $target) {
            if ($SlimRecoveredPngs -and $target.EndsWith('.png')) {
                $importPath = $item.FullName + '.import'
                if (-not (Test-Path -LiteralPath $importPath)) { throw "Cannot slim a texture without its Godot import mapping: $($item.FullName)" }
                $importText = [IO.File]::ReadAllText($importPath)
                $cachePaths = @([regex]::Matches($importText, 'res://\.godot/imported/[^"\r\n]+') | ForEach-Object { $_.Value } | Select-Object -Unique)
                if ($cachePaths.Count -eq 0) { throw "Cannot slim a texture without an imported cache: $($item.FullName)" }
                foreach ($cachePath in $cachePaths) {
                    if (-not (Test-Path -LiteralPath (Join-Path $godotRoot $cachePath.Substring(6)))) {
                        throw "Missing imported texture cache for $($item.FullName): $cachePath"
                    }
                }
                Add-InputFile $emptyTextureMarker $target
                $script:elidedSourcePngCount += 1
                $script:elidedSourcePngBytes += $item.Length
            } else { Add-InputFile $item.FullName $target }
        }
    }
}
function Measure-RegularTree([string]$Root) {
    [long]$size = 0
    foreach ($item in Get-ChildItem -LiteralPath $Root -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($item.PSIsContainer) { $size += Measure-RegularTree $item.FullName }
        else { $size += $item.Length }
    }
    return $size
}
if (-not (Test-Path -LiteralPath $godotConsole)) { throw 'Bundled Godot 4.7.2 is missing.' }
if ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($ScratchRoot)) -ne 'D:\') { throw 'Use D: for this task scratch directory.' }
New-Item -ItemType Directory -Force -Path $ScratchRoot | Out-Null
$emptyTextureMarker = Join-Path $ScratchRoot 'imported-texture-placeholder.png'
[IO.File]::WriteAllBytes($emptyTextureMarker, [byte[]]@())
Add-InputFile (Join-Path $godotRoot 'project.godot') 'res://project.godot'
Add-InputTree (Join-Path $godotRoot 'scripts') 'res://scripts' { param($p) $p -match '\.(gd|uid)$' }
Add-InputTree (Join-Path $godotRoot 'scenes') 'res://scenes' { param($p) $p.EndsWith('.tscn') }
Add-InputTree (Join-Path $godotRoot 'data') 'res://data' {
    param($p)
    $p.EndsWith('.json') -and $p -notmatch '/([^/]*_test_report|playthrough_[^/]*|[^/]*_capture)\.json$'
}
Add-InputFile (Join-Path $godotRoot 'tools\recovered_materials.gd') 'res://tools/recovered_materials.gd'
Add-InputFile (Join-Path $PSScriptRoot 'portable_smoke.gd') 'res://tools/portable_smoke.gd'
Add-InputTree (Join-Path $godotRoot 'licenses') 'res://licenses' { param($p) $true }
foreach ($name in @('LICENSE.md','NOTICE.txt','provenance.json')) {
    Add-InputFile (Join-Path $godotRoot ('assets\luke\' + $name)) ('res://assets/luke/' + $name)
}
Add-InputTree (Join-Path $godotRoot 'assets\luke\Textures') 'res://assets/luke/Textures' { param($p) $p.EndsWith('.import') }
if (Test-Path -LiteralPath (Join-Path $godotRoot 'assets\generated')) {
    Add-InputTree (Join-Path $godotRoot 'assets\generated') 'res://assets/generated' {
        param($p) $p -match '\.(glb|gltf|bin|png|jpg|jpeg|webp|wav|import|json|md|txt)$'
    }
}
if (Test-Path -LiteralPath (Join-Path $godotRoot 'assets\third_party')) {
    Add-InputTree (Join-Path $godotRoot 'assets\third_party') 'res://assets/third_party' {
        param($p) $p -match '\.(glb|gltf|bin|png|jpg|jpeg|webp|import|json|gd|tscn|tres|md|txt)$'
    }
}
Add-InputTree (Join-Path $recoveredRoot 'Geometry') 'res://assets/recovered/Geometry' { param($p) $p -match '\.(glb|import|json)$' }
foreach ($part in @('Arachnophobia','Engine','Metadata','Audio')) {
    Add-InputTree (Join-Path $recoveredRoot $part) ('res://assets/recovered/' + $part) {
        param($p)
        $p -match '\.(png|import|json|wav)$' -and -not $p.Contains('/Animations/') -and -not $p.EndsWith('.glb.import')
    } ($part -eq 'Arachnophobia' -and -not $KeepRecoveredSourcePngs)
}
# The material adapter reads raw GLB/JSON/PNG files and .import channel settings.
# Include only cache destinations referenced by active imports.
foreach ($entry in @($inputFiles.Values)) {
    if (-not $entry.path.EndsWith('.import')) { continue }
    $importText = [IO.File]::ReadAllText($entry.source)
    foreach ($match in [regex]::Matches($importText, 'res://\.godot/imported/[^"\r\n]+')) {
        $resource = $match.Value
        Add-InputFile (Join-Path $godotRoot $resource.Substring(6)) $resource
    }
}
foreach ($name in @('global_script_class_cache.cfg','uid_cache.bin')) {
    Add-InputFile (Join-Path $godotRoot ('.godot\' + $name)) ('res://.godot/' + $name)
}
$entries = @($inputFiles.Values | Sort-Object { $_.path })
[long]$inputBytes = ($entries | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum
[long]$runtimeBytes = (Get-Item -LiteralPath (Join-Path $godotRoot ('runtime\' + $runtimeName))).Length + (Get-Item -LiteralPath $godotConsole).Length
[long]$oldPlayableBytes = 0
if (Test-Path -LiteralPath $playableRoot) { $oldPlayableBytes = Measure-RegularTree $playableRoot }
[long]$replaceablePlayableBytes = 0
foreach ($name in @('Blackweb.pck', $runtimeName, $consoleName)) {
    $oldArtifact = Join-Path $playableRoot $name
    if (Test-Path -LiteralPath $oldArtifact) { $replaceablePlayableBytes += (Get-Item -LiteralPath $oldArtifact).Length }
}
# Preserve and budget existing saves, shader cache, notices, and small reports.
[long]$retainedPlayableBytes = $oldPlayableBytes - $replaceablePlayableBytes
[long]$currentProjectBytes = Measure-RegularTree $projectRoot
[long]$canonicalPlayableBytes = 0
if (Test-Path -LiteralPath $canonicalPlayableRoot) { $canonicalPlayableBytes = Measure-RegularTree $canonicalPlayableRoot }
[long]$baseBytes = $currentProjectBytes - $canonicalPlayableBytes
[long]$estimatedTotal = $currentProjectBytes + 2000000
if ($writingCanonicalPlayable) {
    $estimatedTotal = $baseBytes + $retainedPlayableBytes + $inputBytes + $runtimeBytes + 2000000
}
$packageMethod = 'PCKPacker; recovered PNG source payloads elided in portable build only; Godot .import mappings and imported textures retained'
if ($KeepRecoveredSourcePngs) { $packageMethod = 'PCKPacker; full recovered PNG sources, .import mappings, and imported textures retained' }
$plan = [ordered]@{ input_files = $entries.Count; input_bytes = $inputBytes; runtime_bytes = $runtimeBytes; source_project_bytes_excluding_playable = $baseBytes; retained_playable_bytes = $retainedPlayableBytes; estimated_project_bytes = $estimatedTotal; budget_bytes = $ProjectBudgetBytes; fits = ($estimatedTotal -le $ProjectBudgetBytes); output_directory = $playableRoot; output_is_project_playable = $writingCanonicalPlayable; elided_source_png_count = $elidedSourcePngCount; elided_source_png_bytes = $elidedSourcePngBytes; method = $packageMethod }
[IO.File]::WriteAllText((Join-Path $ScratchRoot 'plan.json'), ($plan | ConvertTo-Json), $utf8)
$plan | ConvertTo-Json
if (-not $plan.fits) { throw 'Package would exceed the total project storage limit.' }
if ($PlanOnly) { return }
$critical = @('res://project.godot','res://scripts/main.gd','res://scripts/player.gd','res://scripts/progression.gd','res://scripts/spider.gd','res://scripts/mini_spider.gd','res://scripts/house_dressing.gd','res://scripts/environment_surfaces.gd','res://scripts/modeled_silk.gd','res://scripts/tutorial_house.gd','res://tools/recovered_materials.gd','res://scenes/recovered_house.tscn','res://scenes/luke.tscn','res://scenes/spider_visual.tscn','res://data/house_layout.json','res://data/opening_components.json')
$critical += @('res://scripts/spider_navigation.gd','res://scripts/spider_profile.gd','res://data/common_flesh_spider.json')
$critical += @('res://scripts/inventory_grid.gd','res://scripts/status_hud.gd','res://scripts/tutorial_campaign.gd','res://scripts/field_overlay.gd','res://scripts/tutorial_intro.gd','res://scripts/tutorial_props.gd','res://scripts/tutorial_evidence.gd','res://scripts/tutorial_door.gd','res://scripts/tutorial_door_handle.gd','res://scripts/combat_effects.gd','res://scripts/soundscape.gd','res://scripts/item_audio.gd','res://data/phone_dialogue.json')
$hashes = [ordered]@{}
foreach ($resource in $critical) { $hashes[$resource] = (Get-FileHash -LiteralPath $inputFiles[$resource].source -Algorithm SHA256).Hash }
$publicInfo = [ordered]@{
    built_utc = [DateTime]::UtcNow.ToString('o'); engine = 'Godot 4.7.2 official Windows x86_64 editor/runtime';
    package_method = $packageMethod;
    elided_source_png_count = $elidedSourcePngCount;
    elided_source_png_bytes = $elidedSourcePngBytes;
    critical_source_sha256 = $hashes; files = @($entries | ForEach-Object { [ordered]@{ path = $_.path; bytes = $_.bytes } });
    raw_recovered_geometry_glb_count = @($entries | Where-Object { $_.path -like 'res://assets/recovered/Geometry/*.glb' }).Count;
    original_project_or_junction_required = $false
}
$buildInfoPath = Join-Path $ScratchRoot 'package-build-info.json'
[IO.File]::WriteAllText($buildInfoPath, ($publicInfo | ConvertTo-Json -Depth 8), $utf8)
Add-InputFile $buildInfoPath 'res://package-build-info.json'
$entries = @($inputFiles.Values | Sort-Object { $_.path })
$inputManifestPath = Join-Path $ScratchRoot 'inputs.json'
[IO.File]::WriteAllText($inputManifestPath, (ConvertTo-Json -InputObject $entries -Depth 5), $utf8)
$stageRoot = Join-Path $ScratchRoot 'packer-project'
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
$stageProject = @'
config_version=5
[application]
config/name="Blackweb Portable Packager"
[rendering]
renderer/rendering_method="gl_compatibility"
'@
[IO.File]::WriteAllText((Join-Path $stageRoot 'project.godot'), $stageProject, $utf8)
New-Item -ItemType Directory -Force -Path $playableRoot | Out-Null
$packagePath = Join-Path $playableRoot 'Blackweb.pck'
$pendingPackage = Join-Path $ScratchRoot 'Blackweb.pending.pck'
$originalEnv = @{}
foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) { $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
try {
    foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
        $localDir = Join-Path $ScratchRoot $key
        New-Item -ItemType Directory -Force -Path $localDir | Out-Null
        [Environment]::SetEnvironmentVariable($key, $localDir, 'Process')
    }
    & $godotConsole --headless --path $stageRoot --script (Join-Path $PSScriptRoot 'pack_portable.gd') -- --manifest=$inputManifestPath --output=$pendingPackage
    if ($LASTEXITCODE -ne 0) { throw 'PCKPacker failed; see the console output.' }
} finally {
    foreach ($key in $originalEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $originalEnv[$key], 'Process') }
}
foreach ($entry in $entries) {
    $now = Get-Item -LiteralPath $entry.source
    if ($now.Length -ne $entry.bytes -or $now.LastWriteTimeUtc.Ticks -ne $entry.modified_ticks) { throw "Input changed during packing: $($entry.path). Rebuild when source edits are complete." }
}
# Only replace this builder's prior artifact after the pack finishes successfully.
Move-Item -LiteralPath $pendingPackage -Destination $packagePath -Force
foreach ($name in @($runtimeName,$consoleName)) {
    Copy-Item -LiteralPath (Join-Path $godotRoot ('runtime\' + $name)) -Destination (Join-Path $playableRoot $name) -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch Blackweb.cmd') -Destination $playableRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch Blackweb Fast.cmd') -Destination $playableRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Playable-README.txt') -Destination (Join-Path $playableRoot 'README.txt') -Force
New-Item -ItemType Directory -Force -Path (Join-Path $playableRoot 'licenses') | Out-Null
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $godotRoot 'licenses') -File) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $playableRoot 'licenses') -Force }
Copy-Item -LiteralPath (Join-Path $godotRoot 'assets\luke\LICENSE.md') -Destination (Join-Path $playableRoot 'licenses\Luke-MIT-LICENSE.md') -Force
Copy-Item -LiteralPath (Join-Path $godotRoot 'assets\luke\NOTICE.txt') -Destination (Join-Path $playableRoot 'licenses\Luke-NOTICE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'Docs\ASSET_PROVENANCE.md') -Destination (Join-Path $playableRoot 'licenses\ASSET_PROVENANCE.md') -Force
Copy-Item -LiteralPath $buildInfoPath -Destination (Join-Path $playableRoot 'package-build-info.json') -Force
$artifactHashes = [ordered]@{}
foreach ($name in @('Blackweb.pck',$runtimeName,$consoleName)) { $artifactHashes[$name] = (Get-FileHash -LiteralPath (Join-Path $playableRoot $name) -Algorithm SHA256).Hash }
$report = [ordered]@{ built_utc = $publicInfo.built_utc; package_bytes = (Get-Item -LiteralPath $packagePath).Length; package_files = $entries.Count; playable_bytes = Measure-RegularTree $playableRoot; project_bytes = Measure-RegularTree $projectRoot; budget_bytes = $ProjectBudgetBytes; artifact_sha256 = $artifactHashes; portable_smoke_status = 'PENDING; run from an isolated directory outside the project'; plan = $plan }
[IO.File]::WriteAllText((Join-Path $playableRoot 'build-report.json'), ($report | ConvertTo-Json -Depth 8), $utf8)
$report | ConvertTo-Json -Depth 8
if ($report.project_bytes -gt $ProjectBudgetBytes) { throw 'Actual project size exceeds the budget.' }
