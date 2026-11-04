# Default launcher uses the tested source variant without optional FMOD.
param([switch]$Build, [Parameter(ValueFromRemainingArguments=$true)][string[]]$RecoveryArguments)
$ErrorActionPreference = 'Stop'
$taskScratch = 'D:\CodexTemp\Arachnophobia-Blackweb-20261103\work'
$env:DOTNET_CLI_HOME = Join-Path $taskScratch 'dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_NOLOGO = '1'
$env:NUGET_PACKAGES = Join-Path $taskScratch 'nuget-packages'
$env:NUGET_HTTP_CACHE_PATH = Join-Path $taskScratch 'nuget-http-cache'
$env:NUGET_PLUGINS_CACHE_PATH = Join-Path $taskScratch 'nuget-plugins-cache'
$env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = Join-Path $taskScratch 'dotnet-bundle-cache'
$env:TEMP = Join-Path $taskScratch 'temp'
$env:TMP = $env:TEMP
$env:DOTNET_ROOT = Join-Path $taskScratch 'dotnet10'
$env:CUE4PARSE_SKIP_NATIVE = 'true'
$taskBuiltDll = Join-Path $PSScriptRoot 'NoFmod\bin\Release\net10.0\Blackweb.Recovery.NoFmod.dll'
if ((Test-Path -LiteralPath $taskBuiltDll) -and -not $Build) {
    & (Join-Path $env:DOTNET_ROOT 'dotnet.exe') $taskBuiltDll @RecoveryArguments
} else {
    & (Join-Path $env:DOTNET_ROOT 'dotnet.exe') run --project (Join-Path $PSScriptRoot 'NoFmod\Blackweb.Recovery.NoFmod.csproj') --configuration Release -- @RecoveryArguments
}
exit $LASTEXITCODE
