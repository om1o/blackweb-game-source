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
    foreach ($test in @('res://tests/progression_tests.gd','res://tests/spider_tests.gd',
        'res://tests/adult_combat_tests.gd','res://tests/juvenile_combat_tests.gd',
        'res://tests/spider_navigation_tests.gd','res://tests/house_spider_combat_tests.gd',
        'res://tests/juvenile_visual_tests.gd','res://tests/combat_effects_tests.gd',
        'res://tests/player_survival_tests.gd','res://tests/tutorial_campaign_tests.gd',
        'res://tests/tutorial_intro_tests.gd','res://tests/tutorial_journey_tests.gd')) {
        & $godotExecutable --headless --path $godotProject --script $test
        if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
    }
}
