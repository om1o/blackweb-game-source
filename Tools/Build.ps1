[CmdletBinding()]
param(
    [ValidateSet('Check','Build','Import','Editor','Package')]
    [string]$Action = 'Check',
    [string]$EngineRoot = 'D:\FootballDev\Epic Games\UE_5.3'
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot 'Blackweb.uproject'
$EngineRoot = [IO.Path]::GetFullPath($EngineRoot)
$BuildBatch = Join-Path $EngineRoot 'Engine\Build\BatchFiles\Build.bat'
$EditorExe = Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor.exe'
$VersionFile = Join-Path $EngineRoot 'Engine\Build\Build.version'
if (!(Test-Path -LiteralPath $ProjectFile)) { throw "Project missing: $ProjectFile" }
if (!(Test-Path -LiteralPath $VersionFile) -or !(Test-Path -LiteralPath $BuildBatch)) {
    throw "Unreal Engine is not installed at $EngineRoot. Install UE 5.3.2, or pass -EngineRoot with its actual directory. No build has run."
}
$Version = Get-Content -LiteralPath $VersionFile -Raw | ConvertFrom-Json
if ($Version.MajorVersion -ne 5 -or $Version.MinorVersion -ne 3 -or $Version.PatchVersion -ne 2) {
    throw 'Initial recovered-asset validation requires Unreal 5.3.2. Engine upgrades need a separate compatibility pass.'
}
# Session-scoped caches only. Do not change the user's global Unreal/Windows settings.
$ScratchRoot = 'D:\CodexTemp\Arachnophobia-Blackweb-20261103\work'
$TaskTemp = Join-Path $ScratchRoot 'unreal-temp'
$TaskDDC = Join-Path $ScratchRoot 'unreal-ddc'
New-Item -ItemType Directory -Path $TaskTemp,$TaskDDC -Force | Out-Null
$env:TEMP = $TaskTemp
$env:TMP = $TaskTemp
[Environment]::SetEnvironmentVariable('UE-LocalDataCachePath', $TaskDDC, 'Process')
Write-Output "Engine $($Version.MajorVersion).$($Version.MinorVersion).$($Version.PatchVersion); project $ProjectFile"
if ($Action -eq 'Check') { return }
& $BuildBatch BlackwebEditor Win64 Development "-Project=$ProjectFile" -WaitMutex -NoHotReloadFromIDE
if ($LASTEXITCODE -ne 0) { throw "Unreal editor target build failed: $LASTEXITCODE" }
switch ($Action) {
    'Build' { Write-Output 'Editor target build succeeded.' }
    'Import' {
        $ImportScript = Join-Path $PSScriptRoot 'Import\import_recovered_house.py'
        if (!(Test-Path -LiteralPath $ImportScript)) { throw 'House import script is not available.' }
        $EditorCmd = Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
        & $EditorCmd $ProjectFile '-run=pythonscript' "-script=$ImportScript" -unattended -nop4 -NullRHI -stdout -FullStdOutLogOutput
        if ($LASTEXITCODE -ne 0) { throw "House import failed: $LASTEXITCODE. Inspect Saved/Logs; no success is assumed." }
    }
    'Editor' {
        # The user requested an interactive game/editor review, so show this window.
        Start-Process -FilePath $EditorExe -ArgumentList @(('"' + $ProjectFile + '"'), '-log') -WindowStyle Normal | Out-Null
    }
    'Package' {
        if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot 'Content\Maps\BlackwebHouse.umap'))) {
            throw 'The recovered house map has not been built/imported. Packaging is blocked.'
        }
        $UAT = Join-Path $EngineRoot 'Engine\Build\BatchFiles\RunUAT.bat'
        $PackageOutput = Join-Path $ProjectRoot 'Saved\Packaged'
        & $UAT BuildCookRun "-project=$ProjectFile" -noP4 -platform=Win64 -clientconfig=Development -build -cook -stage -pak -archive "-archivedirectory=$PackageOutput" -utf8output
        if ($LASTEXITCODE -ne 0) { throw "Packaging failed: $LASTEXITCODE" }
    }
}
