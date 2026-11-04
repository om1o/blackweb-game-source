param(
    [string]$OutputRoot = '',
    [string]$ScratchRoot = 'D:\CodexTemp\Arachnophobia-Blackweb-20261103\work\portable-package-smoke'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$canonicalPlayableRoot = Join-Path $projectRoot 'Playable'
$playableRoot = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { $canonicalPlayableRoot }
$writingCanonicalPlayable = [string]::Equals($playableRoot.TrimEnd('\'), $canonicalPlayableRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
$console = Join-Path $playableRoot 'Godot_v4.7.2-stable_win64_console.exe'
$pack = Join-Path $playableRoot 'Blackweb.pck'
$reportPath = Join-Path $playableRoot 'portable-smoke.json'
$stdoutPath = Join-Path $playableRoot 'portable-smoke.log'
$stderrPath = Join-Path $playableRoot 'portable-smoke-stderr.log'
$resolvedScratch = [IO.Path]::GetFullPath($ScratchRoot)
if ([IO.Path]::GetPathRoot($resolvedScratch) -ne 'D:\') { throw 'Use D: for this task scratch directory.' }
if ($resolvedScratch.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Portable test must run outside the source project.' }
if (-not (Test-Path -LiteralPath $pack) -or -not (Test-Path -LiteralPath $console)) { throw 'Build Playable first.' }
New-Item -ItemType Directory -Force -Path $resolvedScratch | Out-Null
if (Test-Path -LiteralPath (Join-Path $resolvedScratch 'project.godot')) { throw 'Smoke working directory must not contain a Godot project.' }
$originalEnv = @{}
foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) { $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
try {
    foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
        $localDir = Join-Path $resolvedScratch $key
        New-Item -ItemType Directory -Force -Path $localDir | Out-Null
        [Environment]::SetEnvironmentVariable($key, $localDir, 'Process')
    }
    $arguments = @('--headless','--main-pack',('"' + $pack + '"'),'--script','res://tools/portable_smoke.gd','--',('--report="' + $reportPath + '"'))
    $run = Start-Process -FilePath $console -ArgumentList $arguments -WorkingDirectory $resolvedScratch -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $exitCode = $run.ExitCode
} finally {
    foreach ($key in $originalEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $originalEnv[$key], 'Process') }
}
if (-not (Test-Path -LiteralPath $reportPath)) { throw "Smoke produced no report (exit $exitCode); read portable-smoke logs." }
$smoke = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$buildReportPath = Join-Path $playableRoot 'build-report.json'
$build = Get-Content -LiteralPath $buildReportPath -Raw | ConvertFrom-Json
$status = if ($exitCode -eq 0 -and $smoke.passed) { 'PASSED: isolated outside-project headless package/dependency/startup checks' } else { 'FAILED: see portable-smoke.json and logs' }
$build.portable_smoke_status = $status
$build | Add-Member -NotePropertyName portable_smoke_exit_code -NotePropertyValue $exitCode -Force
$build | Add-Member -NotePropertyName portable_smoke_checks -NotePropertyValue $smoke.checks.Count -Force
$build | Add-Member -NotePropertyName portable_smoke_working_directory -NotePropertyValue $resolvedScratch -Force
[IO.File]::WriteAllText($buildReportPath, ($build | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
if ($writingCanonicalPlayable) {
    $evidenceRoot = Join-Path $projectRoot 'Evidence'
    New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
    foreach ($name in @('portable-smoke.json','portable-smoke.log','portable-smoke-stderr.log')) {
        Copy-Item -LiteralPath (Join-Path $playableRoot $name) -Destination (Join-Path $evidenceRoot $name) -Force
    }
    Copy-Item -LiteralPath $buildReportPath -Destination (Join-Path $evidenceRoot 'portable-build-report.json') -Force
}
Get-Content -LiteralPath $stdoutPath
if ((Get-Item -LiteralPath $stderrPath).Length -gt 0) { Get-Content -LiteralPath $stderrPath }
if ($exitCode -ne 0 -or -not $smoke.passed) { throw "Portable smoke failed (exit $exitCode)." }
Write-Output "Portable smoke passed: $($smoke.checks.Count) checks from $resolvedScratch."
