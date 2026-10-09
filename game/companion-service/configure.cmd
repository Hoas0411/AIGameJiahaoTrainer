@echo off
if not exist "%~dp0config.local.json" copy "%~dp0config.example.json" "%~dp0config.local.json" >nul
start "Companion model settings" notepad.exe "%~dp0config.local.json"
