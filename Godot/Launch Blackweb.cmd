@echo off
setlocal
cd /d "%~dp0"
if exist "runtime\Godot_v4.7.2-stable_win64.exe" (
  start "Blackweb" "runtime\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
) else (
  echo Runtime missing. See README for setup.
  pause
)
