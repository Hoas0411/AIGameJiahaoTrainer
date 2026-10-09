param([Parameter(ValueFromRemainingArguments=$true)][string[]]$CliArgs)
$ErrorActionPreference='Stop'
$bundleRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$env:GAME_WORKBENCH_PYTHON=Join-Path $bundleRoot 'runtime/python/python.exe'
$env:GODOT_EXE=Join-Path $bundleRoot 'runtime/godot/Godot_v4.7.2-stable_win64_console.exe'
if(-not $CliArgs){$CliArgs=@('context','--profile','level')}
if($CliArgs -contains '--project'){throw 'This entry fixes --project jiahao.'}
if($CliArgs[0] -in @('context','audit','begin')){$CliArgs+=@('--project','jiahao')}
& (Join-Path $bundleRoot 'workbench/workbench.ps1') @CliArgs
exit $LASTEXITCODE
