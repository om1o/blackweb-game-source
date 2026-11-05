param(
    [string]$OutputRoot = 'D:\BlackwebHandoffs',
    [string]$PlayableRoot = '',
    [string[]]$EvidenceFiles = @(),
    [string]$ArmorAuthoringRoot = 'D:\CodexTemp\Blackweb-RealArmor-20261105',
    [long]$BudgetBytes = 5000000000
)
# Run only after committing source and testing the final portable package.
# This packages files; it never starts Godot, uploads anything, or changes saves.
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$output = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\')
$playable = if ($PlayableRoot) { [IO.Path]::GetFullPath($PlayableRoot) } else { Join-Path $project 'Playable' }
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($BudgetBytes -le 0 -or $BudgetBytes -gt 5000000000) { throw 'The handoff budget must be positive and cannot exceed the owner''s 5,000,000,000-byte cap.' }
if ([IO.Path]::GetPathRoot($output) -ne 'D:\' -or $output.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase) -or $output -eq $project) {
    throw 'Handoffs must be outside the source project on D:.'
}
function Git-Lines([string[]]$Arguments) {
    $result = @(& git -C $project -c core.quotepath=false @Arguments)
    if ($LASTEXITCODE -ne 0) { throw ('Git failed: ' + ($Arguments -join ' ')) }
    return $result
}
function Assert-CleanSource {
    if (@(Git-Lines @('status','--porcelain','--untracked-files=all')).Count -ne 0) {
        throw 'Commit all intended source files first. Tracked edits or untracked nonignored files remain.'
    }
}
function Measure-RegularTree([string]$Directory) {
    [long]$total = 0
    foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($item.PSIsContainer) { $total += Measure-RegularTree $item.FullName } else { $total += $item.Length }
    }
    return $total
}
function Safe-Relative([string]$Name) {
    $relative = $Name.Replace('\','/')
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative.StartsWith('/') -or $relative.Contains(':') -or $relative -match '[\r\n]' -or @($relative.Split('/') | Where-Object { $_ -eq '..' -or $_ -eq '.' -or $_ -eq '' }).Count -gt 0) {
        throw "Unsafe archive path: $Name"
    }
    return $relative
}
function Is-Excluded([string]$Relative) {
    return $Relative -match '(^|/)(\.git|\.godot|\.openai|node_modules|UserData|\.nuget|obj|bin|shader_cache)(/|$)' -or
        $Relative -match '^Godot/(assets/recovered|runtime|BlackwebHouseRebuild|validation)(/|$)' -or
        $Relative -match '^Godot/assets/third_party/(literock|grab3d|3dassets)(/|$)' -or
        $Relative -match '^RecoveredAssets/LicensedThirdParty(/|$)' -or
        $Relative -match '(^|/)(\.env(\..*)?|credentials(\.[^/]*)?|id_rsa|id_ed25519)$'
}
function Read-Json([string]$Path) { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) }
function Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

Assert-CleanSource
$commit = @(Git-Lines @('rev-parse','HEAD'))[0]
[long]$projectBytes = Measure-RegularTree $project
if ($projectBytes -gt $BudgetBytes) { throw "Current source plus Playable exceeds the $BudgetBytes-byte project budget: $projectBytes" }
$build = Read-Json (Join-Path $playable 'build-report.json')
$smoke = Read-Json (Join-Path $playable 'portable-smoke.json')
$packageInfo = Read-Json (Join-Path $playable 'package-build-info.json')
if ($build.portable_smoke_exit_code -ne 0 -or -not $smoke.passed -or $build.portable_smoke_status -notlike 'PASSED:*' -or @($smoke.checks).Count -eq 0 -or @($smoke.checks).Count -ne $build.portable_smoke_checks -or @($smoke.checks | Where-Object { -not $_.passed }).Count -gt 0) {
    throw 'The selected portable package does not have a successful matching smoke report.'
}
foreach ($name in @('Blackweb.pck','Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe')) {
    $expected = $build.artifact_sha256.PSObject.Properties[$name]
    if ($null -eq $expected -or (Sha256 (Join-Path $playable $name)) -ne $expected.Value.ToLowerInvariant()) { throw "Tested artifact hash mismatch: $name" }
}
foreach ($property in $packageInfo.critical_source_sha256.PSObject.Properties) {
    if (-not $property.Name.StartsWith('res://')) { throw 'Invalid packaged source path.' }
    $relative = Safe-Relative ($property.Name.Substring(6))
    $source = if ($relative -eq 'tools/portable_smoke.gd') { Join-Path $PSScriptRoot 'portable_smoke.gd' } elseif ($relative.StartsWith('assets/recovered/')) { Join-Path $project ('RecoveredAssets/' + $relative.Substring(17)) } else { Join-Path $project ('Godot/' + $relative) }
    if ((Sha256 $source) -ne $property.Value.ToLowerInvariant()) { throw "Source differs from tested package: $($property.Name)" }
}
if ((Get-Item -LiteralPath (Join-Path $playable 'Blackweb.pck')).Length -ne $build.package_bytes) { throw 'Tested PCK byte count mismatch.' }
foreach ($name in @('Launch Blackweb.cmd','Launch Blackweb Fast.cmd')) {
    if ((Sha256 (Join-Path $playable $name)) -ne (Sha256 (Join-Path $PSScriptRoot $name))) { throw "Rebuild/promote the current launcher before packaging: $name" }
}
if ((Sha256 (Join-Path $playable 'README.txt')) -ne (Sha256 (Join-Path $PSScriptRoot 'Playable-README.txt'))) { throw 'Playable README is stale.' }

# An allowlist of actual source inputs avoids copying ignored local candidates,
# credentials, the original archive, recovery-tool caches, or user save state.
$inputs = @{}
function Add-File([string]$Source, [string]$Target, [string]$Category) {
    $relative = Safe-Relative $Target
    if (Is-Excluded $relative) { throw "Excluded input requested: $relative" }
    $item = Get-Item -LiteralPath $Source
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Input must be a regular file: $Source" }
    if ($inputs.ContainsKey($relative)) { return }
    $inputs[$relative] = [ordered]@{ path = $relative; source = $item.FullName; bytes = $item.Length; category = $Category }
}
function Add-Tree([string]$Source, [string]$Target, [string]$Category, [bool]$ImportsOnly = $false) {
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        $relative = ($Target + '/' + $item.Name).Replace('\','/')
        if (Is-Excluded $relative) { continue }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected linked input: $($item.FullName)" }
        if ($item.PSIsContainer) { Add-Tree $item.FullName $relative $Category $ImportsOnly }
        elseif (-not $ImportsOnly -or $item.Extension -eq '.import') { Add-File $item.FullName $relative $Category }
    }
}
foreach ($relative in (Git-Lines @('ls-files'))) {
    $relative = Safe-Relative $relative
    if (-not (Is-Excluded $relative)) { Add-File (Join-Path $project $relative) $relative 'committed-source' }
}
foreach ($part in @('Arachnophobia','Audio','Engine','Geometry','Metadata','ReferenceTexturedExports')) {
    Add-Tree (Join-Path $project ('RecoveredAssets/' + $part)) ('RecoveredAssets/' + $part) 'private-owner-supplied-recovered-content'
}
foreach ($relative in @('Godot/scenes/recovered_house.tscn','Godot/scenes/spider_visual.tscn','Godot/data/opening_components.json','Godot/data/recovered_components.json','Godot/data/recovered_lights.json','Godot/data/house_import_report.json','Godot/data/normal_import_report.json')) {
    Add-File (Join-Path $project $relative) $relative 'private-owner-supplied-derived-scene-or-data'
}
# Import settings are source configuration; imported cache payloads are omitted.
# The recovered junction is excluded before recursion and created after extraction.
Add-Tree (Join-Path $project 'Godot/assets') 'Godot/assets' 'source-import-settings' $true
foreach ($name in @('Blackweb.pck','Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe','Launch Blackweb.cmd','Launch Blackweb Fast.cmd','README.txt','build-report.json','package-build-info.json','portable-smoke.json')) {
    Add-File (Join-Path $playable $name) ('Playable/' + $name) 'tested-portable-game'
}
Add-Tree (Join-Path $playable 'licenses') 'Playable/licenses' 'runtime-notices'
Add-File (Join-Path $project 'Godot/assets/third_party/literock/LICENSE.txt') 'Handoff/Licenses/Literock-Giant-Spider-Lite.txt' 'notice-only-no-raw-asset'
# Only the inspected, licensed garment inputs used by the final fitting pass.
# Keep these external files outside the game project; include them directly in
# the unique handoff stage and account for their bytes in the same payload cap.
$armorSource = [IO.Path]::GetFullPath($ArmorAuthoringRoot)
$armorListPath = Join-Path $PSScriptRoot 'ArmorAuthoringInputs.json'
$armorList = Read-Json $armorListPath
if ($armorList.schema -ne 1 -or @($armorList.files).Count -ne 18) { throw 'Unexpected armor authoring input list.' }
foreach ($name in $armorList.files) {
    $relative = Safe-Relative $name
    if ($relative -notmatch '\.(blend|obj|png|mhclo)$') { throw "Unexpected armor authoring type: $relative" }
    Add-File (Join-Path $armorSource $relative) ('Handoff/Authoring/Armor/' + $relative) 'licensed-armor-authoring-input'
}
Add-File $armorListPath 'Handoff/Authoring/Armor/Input-list.json' 'armor-authoring-manifest'
foreach ($name in @('README.md','rebuild_armor.py','relink_blend.py')) {
    Add-File (Join-Path $PSScriptRoot ('ArmorAuthoring/' + $name)) ('Handoff/Authoring/Armor/' + $name) 'armor-authoring-relocation-helper'
}
Add-File (Join-Path $project 'Tools/Assets/leather_boots/fit_armor.py') 'Tools/Assets/leather_boots/fit_armor.py' 'committed-armor-fitting-source'
foreach ($notice in @(
    @('Godot/licenses/MakeHumanArmor.txt','Armor-credits.txt'),
    @('Godot/assets/third_party/makehuman_armor/ATTRIBUTION.md','Garment-attribution.md'),
    @('Godot/assets/luke/LICENSE.md','Rocketbox-MIT-LICENSE.md'),
    @('Godot/assets/luke/NOTICE.txt','Rocketbox-NOTICE.txt')
)) {
    Add-File (Join-Path $project $notice[0]) ('Handoff/Authoring/Armor/Licenses/' + $notice[1]) 'armor-authoring-license'
}
foreach ($relative in $EvidenceFiles) {
    $relative = Safe-Relative $relative
    if (-not $relative.StartsWith('Evidence/') -or $relative -notmatch '\.(json|png|jpg|md|txt|csv)$') { throw 'EvidenceFiles must name selected JSON/image/text evidence under Evidence/.' }
    Add-File (Join-Path $project $relative) $relative 'selected-qa-evidence'
}
[long]$inputBytes = ($inputs.Values | Measure-Object -Property bytes -Sum).Sum
if ($inputBytes + 4000000 -gt $BudgetBytes) { throw "Handoff payload plus manifest allowance exceeds $BudgetBytes bytes: $inputBytes" }

# Unique names and CreateNew archive semantics preserve every older handoff.
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$release = 'Blackweb-InterfaceRelease-' + $stamp + '-' + $commit.Substring(0,8) + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
New-Item -ItemType Directory -Force -Path $output | Out-Null
$stage = Join-Path $output ($release + '-staging')
$root = Join-Path $stage 'Blackweb'
$archive = Join-Path $output ($release + '.zip')
if ((Test-Path -LiteralPath $stage) -or (Test-Path -LiteralPath $archive)) { throw 'Unique handoff destination already exists.' }
New-Item -ItemType Directory -Path $root | Out-Null
foreach ($entry in ($inputs.Values | Sort-Object path)) {
    $destination = Join-Path $root $entry.path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $entry.source -Destination $destination
    if ((Sha256 $destination) -ne (Sha256 $entry.source)) { throw "Copy changed while staging: $($entry.path)" }
}
function Write-Handoff([string]$Relative, [string]$Text) {
    $destination = Join-Path $root (Safe-Relative $Relative)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    [IO.File]::WriteAllText($destination, $Text, $utf8)
}
Write-Handoff 'Prepare Source.cmd' @'
@echo off
setlocal
if not exist "%~dp0RecoveredAssets\Geometry" exit /b 1
if exist "%~dp0Godot\assets\recovered\Geometry" exit /b 0
if exist "%~dp0Godot\assets\recovered" (
  echo An existing asset folder needs inspection. No folder was replaced.
  exit /b 1
)
mklink /J "%~dp0Godot\assets\recovered" "%~dp0RecoveredAssets"
'@
Write-Handoff 'PLAY BLACKWEB.cmd' @'
@echo off
setlocal
call "%~dp0Playable\Launch Blackweb Fast.cmd" %*
'@
Write-Handoff 'OPEN GODOT EDITOR.cmd' @'
@echo off
setlocal
call "%~dp0Prepare Source.cmd"
if errorlevel 1 (pause & exit /b 1)
set "APPDATA=%~dp0SourceUserData"
set "LOCALAPPDATA=%~dp0SourceUserData\Cache"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "Blackweb Editor" "%~dp0Playable\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0Godot"
'@
Write-Handoff 'RUN EDITABLE GAME.cmd' @'
@echo off
setlocal
call "%~dp0Prepare Source.cmd"
if errorlevel 1 (pause & exit /b 1)
set "APPDATA=%~dp0SourceUserData"
set "LOCALAPPDATA=%~dp0SourceUserData\Cache"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
"%~dp0Playable\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --import --path "%~dp0Godot"
if errorlevel 1 (pause & exit /b 1)
start "Blackweb Source" "%~dp0Playable\Godot_v4.7.2-stable_win64.exe" --path "%~dp0Godot"
'@
$packHash = Sha256 (Join-Path $root 'Playable/Blackweb.pck')
Write-Handoff 'START HERE.md' @"
# BLACKWEB — InterfaceRelease private development handoff

Extract the whole ZIP to a writable Windows x64 folder. **PLAY BLACKWEB.cmd** runs the tested packaged game without an engine installation or account. It starts at 960x540 with a Performance graphics override. To choose graphics in Options, use **Playable/Launch Blackweb.cmd** instead; a command-line override locks the picker for that run. Keep the Playable folder together. Saves are created locally under Playable/UserData; no existing personal saves are included.

**OPEN GODOT EDITOR.cmd** creates the recovered-asset link relative to this extraction and opens the bundled editor. **RUN EDITABLE GAME.cmd** first imports source assets, then runs the editable project. Both keep source-run settings/saves in a new local SourceUserData directory, separate from Playable/UserData and the original development project. The first import takes time and requires additional disk space. Godot caches are deliberately omitted. The same official Godot 4.7.2 executable serves both editor and packaged game; this is an executable plus PCK, not a custom compiled release-template binary.

The source contains committed gameplay, scenes, art, voices, tests, authoring tools and docs, plus explicitly listed original recovered inputs. It omits raw Literock assets, unused restricted model candidates, machine caches, Git internals/credentials, user saves and the original downloaded archive. Runtime dependencies are self-contained in Playable. Optional regeneration tools can require separately installed Blender, .NET, Node or model caches; they are not needed to play. No website deployment or website account state is included.

**Handoff/Authoring/Armor** includes the final and reference Blender scenes plus the selected licensed OBJ/color/normal inputs. Its README explains the supplied image-relink and rebuild helpers, which resolve paths from this extraction instead of the original D: scratch directory. These armor inputs are included in the archive manifest and size cap; Blender is a separate optional tool. Other generation pipelines can still have external dependencies documented in their own tools.

**This is private collaboration content, not a blanket redistribution license.** The owner stated permission to reuse the supplied game art; exact public redistribution terms were not supplied. Do not publish the recovered house/adult-spider/source content on that basis. Refer to Docs/ASSET_PROVENANCE.md and all bundled notices. Open-source/CC0/CC BY/OFL assets keep their respective license terms.

The packaged game contains Literock's juvenile spider as permitted in an end product. Raw Literock meshes, textures and imported derivatives are absent from editable source. The source automatically uses the existing CC0 Quaternius fallback. Obtain Giant Spider Lite from https://literock-studios.itch.io/giant-spider-lite separately if licensed source parity is needed; Docs/LiterockSpider.md describes the expected local path and 1K conversion. The included Literock notice prohibits raw redistribution and ML training. No upload or training is performed by this builder.

Source commit: **$commit**. Tested PCK SHA-256: **$packHash**. Portable smoke: **$($build.portable_smoke_checks) checks**, successful recorded exit. Handoff/Snapshot.json records scope and package evidence; Handoff/File-manifest.json records every payload file except itself. The adjacent archive validation report verifies entry count, size and hashes. Archive integrity is distinct from a new relocated native playtest; this builder never launches Godot.

Read Docs/InterfaceAndPacingRelease.md and Docs/HorrorInterfacePass.md for the current interface, armor and opening changes. Historical reports describe older builds and are not current performance guarantees. Source edits do not update Playable/Blackweb.pck until rebuilt and retested. The original build scripts may retain D: scratch defaults; adjust them intentionally when relocating development. The handoff payload is under the 5,000,000,000-byte cap; ZIP plus extracted files plus newly imported caches require additional storage outside that project budget.
"@
$snapshot = [ordered]@{
    schema = 1; created_utc = [DateTime]::UtcNow.ToString('o'); source_commit = $commit;
    source_state = 'clean committed source plus explicit private recovered inputs'; package_sha256 = $packHash;
    portable_smoke_checks = $build.portable_smoke_checks; portable_smoke_status = $build.portable_smoke_status;
    project_bytes_before_staging = $projectBytes; budget_bytes = $BudgetBytes;
    source_reimport_required = $true; source_juvenile_visual = 'CC0 fallback; raw Literock not redistributed';
    armor_authoring_inputs = @($armorList.files).Count; armor_authoring_scope = 'Final and Luke reference Blender scenes, selected licensed OBJ/color/normal inputs and source license headers; relocation helpers included; no engine run during packaging';
    restrictions = 'Private owner-authorized collaboration; public redistribution of recovered game content not established. Literock only inside packaged game; raw assets/caches omitted.';
    exclusions = @('.git','.godot caches','UserData','Godot/assets/recovered junction','Godot/assets/third_party/literock','RecoveredAssets/LicensedThirdParty','unused grab3d/3dassets','original archive','credentials and tool caches');
    selected_evidence = $EvidenceFiles; validation_scope = 'Recorded tested PCK plus archive file hashes/counts; no new engine run by this script'
}
Write-Handoff 'Handoff/Snapshot.json' ($snapshot | ConvertTo-Json -Depth 6)
Write-Handoff 'Handoff/Commit-history.txt' ((Git-Lines @('log','-20','--format=%H %s')) -join "`n")
Assert-CleanSource
if (@(Git-Lines @('rev-parse','HEAD'))[0] -ne $commit) { throw 'Source commit changed while staging.' }

$rows = @()
foreach ($item in (Get-ChildItem -LiteralPath $root -File -Recurse -Force | Sort-Object FullName)) {
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Unexpected staged link.' }
    $relative = Safe-Relative ($item.FullName.Substring($root.Length + 1))
    if (Is-Excluded $relative) { throw "Excluded staged file: $relative" }
    $rows += [ordered]@{ path = $relative; bytes = $item.Length; sha256 = (Sha256 $item.FullName); category = $(if ($inputs.ContainsKey($relative)) { $inputs[$relative].category } else { 'handoff-metadata-or-launcher' }) }
}
[long]$payloadBytes = ($rows | Measure-Object -Property bytes -Sum).Sum
$manifest = [ordered]@{ schema = 1; algorithm = 'SHA-256'; source_commit = $commit; excludes_self = $true; files = $rows; total_file_bytes = $payloadBytes }
Write-Handoff 'Handoff/File-manifest.json' ($manifest | ConvertTo-Json -Depth 6)
[long]$stagedBytes = Measure-RegularTree $root
if ($stagedBytes -gt $BudgetBytes) { throw "Staged payload exceeds $BudgetBytes bytes: $stagedBytes" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($root, $archive, [IO.Compression.CompressionLevel]::Fastest, $true)
$expectedEntries = @{}
foreach ($row in $rows) { $expectedEntries['Blackweb/' + $row.path] = $row }
$manifestFile = Join-Path $root 'Handoff/File-manifest.json'
$expectedEntries['Blackweb/Handoff/File-manifest.json'] = @{ bytes = (Get-Item -LiteralPath $manifestFile).Length; sha256 = (Sha256 $manifestFile) }
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
$seen = @{}
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        $name = Safe-Relative $entry.FullName
        if ($seen.ContainsKey($name) -or -not $expectedEntries.ContainsKey($name)) { throw "Unexpected or duplicate ZIP entry: $name" }
        $expected = $expectedEntries[$name]
        if ($entry.Length -ne $expected.bytes) { throw "ZIP byte count mismatch: $name" }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $stream.Dispose(); $sha.Dispose() }
        if ($actual -ne $expected.sha256) { throw "ZIP hash mismatch: $name" }
        $seen[$name] = $true
    }
} finally { $zip.Dispose() }
if ($seen.Count -ne $expectedEntries.Count) { throw 'ZIP file count differs from the manifest.' }
$archiveHash = Sha256 $archive
[IO.File]::WriteAllText($archive + '.sha256', ($archiveHash + '  ' + [IO.Path]::GetFileName($archive) + "`n"), $utf8)
$validation = [ordered]@{ completed_utc = [DateTime]::UtcNow.ToString('o'); archive = $archive; archive_bytes = (Get-Item -LiteralPath $archive).Length; archive_sha256 = $archiveHash; source_commit = $commit; payload_bytes_including_manifest = $stagedBytes; verified_files = $seen.Count; manifest_payload_files = $rows.Count; all_entry_sizes_and_sha256_match = $true; engine_started = $false; personal_saves_included = $false }
[IO.File]::WriteAllText((Join-Path $output ($release + '-validation.json')), ($validation | ConvertTo-Json), $utf8)
$validation | ConvertTo-Json
