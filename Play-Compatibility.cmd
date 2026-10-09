@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\portable.ps1" -Action play-compat
if errorlevel 1 pause
