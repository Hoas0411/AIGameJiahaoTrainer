@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\portable.ps1" -Action verify
if errorlevel 1 pause
