param(
    [string]$ProjectRoot = 'D:\GameProjects\BlackwebHouseRebuild-20261103',
    [string]$ScratchRoot = 'D:\CodexTemp\Blackweb-RealArmor-20261105\Performance',
    [ValidatePattern('^[a-z0-9-]+$')][string]$OutputBase = 'render-variant-comparison'
)
$ErrorActionPreference = 'Stop'
# Reuse the previous isolated performance run's driver/shader cache. Never point
# this at the user's real profile, touch another process, or change Windows audio.
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$scratch = (Resolve-Path -LiteralPath $ScratchRoot).Path
if (-not $scratch.StartsWith('D:\CodexTemp\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Use the isolated D:\CodexTemp performance profile.' }
$evidence = Join-Path $project 'Evidence\InterfaceRelease'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$output = Join-Path $evidence ($OutputBase + '.json')
if (Test-Path -LiteralPath $output) { throw "Comparison evidence already exists; choose a unique -OutputBase: $output" }
$before = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Select-Object ProcessId,Name,CommandLine)
if ($before.Count -ne 0) { throw 'Another Godot process is present. Wait for the engine slot; do not terminate it.' }
$original = @{}
$manifest = [ordered]@{
    utc_started = [DateTime]::UtcNow.ToString('o')
    before = $before
    scratch_profile = $scratch
    source_commit = ((& git -C $project rev-parse HEAD) -join '').Trim()
    resolution_requested = '1280x720'
    no_other_processes_stopped = $true
    output = $output
}
try {
    foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
        $directory = Join-Path $scratch $key
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw "Missing existing isolated cache directory: $directory" }
        $original[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $directory, 'Process')
    }
    $engine = Join-Path $project 'Godot\runtime\Godot_v4.7.2-stable_win64_console.exe'
    $script = Join-Path $project 'Tools\Performance\compare_render_presets.gd'
    $manifest.harness_sha256 = (Get-FileHash -LiteralPath $script -Algorithm SHA256).Hash
    $arguments = @('--path',(Join-Path $project 'Godot'),'--windowed','--resolution','1280x720','--script',$script,'--','--graphics=quality',('--source-commit=' + $manifest.source_commit),('--output=' + $output))
    $run = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $scratch -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $evidence ($OutputBase + '.log')) -RedirectStandardError (Join-Path $evidence ($OutputBase + '-stderr.log'))
    $manifest.launcher_process_id = $run.Id
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence ($OutputBase + '-processes.json')) -Encoding utf8
    $run.WaitForExit()
    $run.Refresh()
    $manifest.exit_code = $run.ExitCode
} finally {
    foreach ($key in $original.Keys) { [Environment]::SetEnvironmentVariable($key, $original[$key], 'Process') }
    $manifest.utc_finished = [DateTime]::UtcNow.ToString('o')
    $manifest.after = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Select-Object ProcessId,Name,CommandLine)
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence ($OutputBase + '-processes.json')) -Encoding utf8
}
Get-Content -LiteralPath (Join-Path $evidence ($OutputBase + '.log')) -Tail 8
if ($manifest.exit_code -ne 0) { throw "Native comparison failed: $($manifest.exit_code)" }
$result = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
if (-not $result.complete -or $result.failures.Count -ne 0 -or $result.phases.Count -ne 6) { throw 'Comparison did not produce six valid phases.' }
Write-Output "Comparison complete: $output"
