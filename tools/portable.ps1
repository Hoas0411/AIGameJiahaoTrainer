param([ValidateSet('play','play-compat','edit','verify','export')][string]$Action='play')
$ErrorActionPreference='Stop'
$bundleRoot=Split-Path $PSScriptRoot -Parent
$projectRoot=Join-Path $bundleRoot 'game'
$godotExe=Join-Path $bundleRoot 'runtime/godot/Godot_v4.7.2-stable_win64.exe'
$godotConsole=Join-Path $bundleRoot 'runtime/godot/Godot_v4.7.2-stable_win64_console.exe'
# Fresh user data and temporary files stay in this D-drive project; original player saves stay untouched.
foreach($envName in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
  $folder=Join-Path $bundleRoot ('local-data/'+$envName.ToLower())
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  [Environment]::SetEnvironmentVariable($envName,$folder,'Process')
}
# Forward+ is the authored renderer (SSAO/SSIL/SSR, volumetrics, shadows). Compatibility stays as a fallback entry for old GPUs.
if($Action -eq 'play') { & $godotExe --path $projectRoot; exit $LASTEXITCODE }
if($Action -eq 'play-compat') { & $godotExe --path $projectRoot --rendering-method gl_compatibility; exit $LASTEXITCODE }
if($Action -eq 'edit') { Start-Process -FilePath $godotExe -ArgumentList @('--editor','--path',('"'+$projectRoot+'"')); exit 0 }
if($Action -eq 'verify') {
  & (Join-Path $bundleRoot 'runtime/python/python.exe') -B (Join-Path $PSScriptRoot 'verify.py')
  exit $LASTEXITCODE
}
if($Action -eq 'export') {
  $target=Join-Path $bundleRoot ('exports/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  & $godotConsole --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $target 'JiahaoTrainer.exe')
  if($LASTEXITCODE -ne 0){throw 'Godot export failed; review the console log.'}
  Copy-Item -LiteralPath (Join-Path $projectRoot 'companion-service') -Destination $target -Recurse
  Get-ChildItem (Join-Path $target 'companion-service') -Filter '*.local.json' | Remove-Item
  $startup='@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'start "" "%~dp0JiahaoTrainer.exe"' + "`r`n"
  [IO.File]::WriteAllText((Join-Path $target 'Play.cmd'),$startup)
  $compat='@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'start "" "%~dp0JiahaoTrainer.exe" --rendering-method gl_compatibility' + "`r`n"
  [IO.File]::WriteAllText((Join-Path $target 'Play-Compatibility.cmd'),$compat)
  Copy-Item -LiteralPath (Join-Path $bundleRoot 'runtime/licenses') -Destination $target -Recurse
  Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/OFL.txt') -Destination $target
  Write-Host ('Exported '+$target+'; verify Play.cmd before registering a delivery.')
}
