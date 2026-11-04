param([ValidateSet('Check','RecoverScene','Run')][string]$Action = 'Check')
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
$godotProject = Join-Path $gameRoot 'Godot'
$godotExecutable = Join-Path $godotProject 'runtime\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotExecutable)) { throw 'The bundled Godot console runtime is missing.' }
if ($Action -eq 'Run') {
    & $godotExecutable --path $godotProject
    exit $LASTEXITCODE
}
if ($Action -eq 'RecoverScene') {
    $recoveredSource = Join-Path $gameRoot 'RecoveredAssets'
    $assetRoot = Join-Path $godotProject 'assets'
    $recoveredLink = Join-Path $assetRoot 'recovered'
    if (-not (Test-Path -LiteralPath $recoveredSource)) { throw 'Interchange recovery must finish first.' }
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null
    if (-not (Test-Path -LiteralPath $recoveredLink)) {
        New-Item -ItemType Junction -Path $recoveredLink -Target $recoveredSource | Out-Null
    }
}
& $godotExecutable --headless --path $godotProject --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed. Check the console output.' }
if ($Action -eq 'RecoverScene') {
    & $godotExecutable --headless --path $godotProject --script res://tools/build_house.gd -- --manifest=res://data/opening_components.json
    if ($LASTEXITCODE -ne 0) { throw 'House reconstruction is incomplete; read Godot/data/house_import_report.json.' }
} else {
    foreach ($test in @('res://tests/progression_tests.gd','res://tests/spider_tests.gd')) {
        & $godotExecutable --headless --path $godotProject --script $test
        if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
    }
}
