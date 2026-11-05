param(
    [string]$OutputRoot = '',
    [string]$ScratchRoot = 'D:\CodexTemp\Blackweb-Spider-Combat-QA'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$playableRoot = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $projectRoot 'Playable' }
$scratch = [IO.Path]::GetFullPath($ScratchRoot)
if ($scratch.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Combat QA must use a scratch directory outside the source project.' }
$pack = Join-Path $playableRoot 'Blackweb.pck'
$console = Join-Path $playableRoot 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $pack) -or -not (Test-Path -LiteralPath $console)) { throw 'Build the portable game first.' }
$runner = Join-Path $scratch 'runner'
New-Item -ItemType Directory -Path $runner,(Join-Path $scratch 'Evidence') -Force | Out-Null
$oldEnv = @{}
$runs = @()
try {
    foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
        $oldEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        $isolated = Join-Path $scratch $key
        New-Item -ItemType Directory -Path $isolated -Force | Out-Null
        [Environment]::SetEnvironmentVariable($key, $isolated, 'Process')
    }
    foreach ($test in @('adult_combat_tests.gd','juvenile_combat_tests.gd','spider_navigation_tests.gd','house_spider_combat_tests.gd','juvenile_visual_tests.gd')) {
        $testCopy = Join-Path $runner $test
        Copy-Item -LiteralPath (Join-Path $projectRoot ('Godot\tests\' + $test)) -Destination $testCopy -Force
        $log = Join-Path $scratch ($test + '.log')
        Push-Location $runner
        try {
            # Only the test harness comes from source. Its res:// dependencies
            # resolve inside the actual packaged game, with separate save data.
            & $console --headless --main-pack $pack --script $testCopy *> $log
            $code = $LASTEXITCODE
        } finally { Pop-Location }
        $lines = Get-Content -LiteralPath $log
        $runs += [ordered]@{ suite = $test; exit_code = $code; summary = @($lines | Select-Object -Last 2) }
        $lines | Select-Object -Last 2 | Write-Output
        if ($code -ne 0 -or ($lines | Where-Object { $_ -match 'SCRIPT ERROR:|ERROR:' })) { throw ('Packaged combat test failed: ' + $test) }
    }
} finally {
    foreach ($key in $oldEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $oldEnv[$key], 'Process') }
}
$report = [ordered]@{
    completed_utc = [DateTime]::UtcNow.ToString('o')
    package_sha256 = (Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash
    passed = $true
    suites = $runs
    isolated_user_data = $true
    limitations = 'Automated headless physics and rig checks; native review and human playtesting are separate.'
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $scratch 'spider-combat-package.json') -Encoding UTF8
Write-Output 'All packaged spider combat, navigation, house and rig checks passed.'
