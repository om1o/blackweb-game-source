@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0UserData"
set "LOCALAPPDATA=%~dp0UserData\Cache"
set "TEMP=%~dp0UserData\Temp"
set "TMP=%~dp0UserData\Temp"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%~dp0Blackweb.pck" (
  echo Blackweb.pck is missing. Keep the entire Playable folder together.
  pause
  exit /b 1
)
if not exist "%~dp0Godot_v4.7.2-stable_win64.exe" (
  echo The bundled Godot runtime is missing.
  pause
  exit /b 1
)
set "BLACKWEB_RENDER_ARGS="
set "BLACKWEB_DISPLAY_ARGS="
set "BLACKWEB_GRAPHICS_ARGS="
:parse_args
if "%~1"=="" goto launch
if /I "%~1"=="--graphics" goto graphics_arg
if /I "%~1"=="--room-shadows" set "BLACKWEB_RENDER_ARGS=--room-shadows"
if /I "%~1"=="--fast" set "BLACKWEB_DISPLAY_ARGS=--resolution 960x540"
if /I "%~1"=="--graphics=quality" set "BLACKWEB_GRAPHICS_ARGS=--graphics=quality"
if /I "%~1"=="--graphics=performance" set "BLACKWEB_GRAPHICS_ARGS=--graphics=performance"
shift
goto parse_args
:graphics_arg
rem cmd.exe splits an unquoted --graphics=value at the equals sign.
shift
if /I "%~1"=="quality" set "BLACKWEB_GRAPHICS_ARGS=--graphics=quality"
if /I "%~1"=="performance" set "BLACKWEB_GRAPHICS_ARGS=--graphics=performance"
shift
goto parse_args
:launch
start "Blackweb" "%~dp0Godot_v4.7.2-stable_win64.exe" --main-pack "%~dp0Blackweb.pck" %BLACKWEB_DISPLAY_ARGS% --log-file "%~dp0UserData\blackweb.log" -- %BLACKWEB_RENDER_ARGS% %BLACKWEB_GRAPHICS_ARGS%
