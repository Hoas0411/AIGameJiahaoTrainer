$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Optional installation on another PC; CPU runtime works without an NVIDIA GPU.
$jhVoiceRoot = Join-Path $PSScriptRoot 'voice-runtime'
New-Item -ItemType Directory -Force -Path $jhVoiceRoot | Out-Null
function Get-JhVerifiedFile([string]$Uri, [string]$Path, [string]$Hash) {
    if ((Test-Path -LiteralPath $Path) -and (Get-FileHash -LiteralPath $Path).Hash -eq $Hash) { return }
    for ($jhAttempt = 0; $jhAttempt -lt 3; $jhAttempt++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile ($Path + '.download') -TimeoutSec 600
            if ((Get-FileHash -LiteralPath ($Path + '.download')).Hash -ne $Hash) { throw 'Checksum mismatch' }
            Move-Item -LiteralPath ($Path + '.download') -Destination $Path -Force
            return
        } catch { if ($jhAttempt -eq 2) { throw } }
    }
}
Write-Output 'Installing local speech recognition (about 500 MB).'
$jhZip = Join-Path $jhVoiceRoot 'whisper.zip'
Get-JhVerifiedFile 'https://github.com/ggml-org/whisper.cpp/releases/download/b4938/whisper-bin-x64.zip' $jhZip 'c2a4b60edb11f7e11a9191ffb50929535527d4d91c9903dbe3e554583bbbc63d'
Expand-Archive -LiteralPath $jhZip -DestinationPath $jhVoiceRoot -Force
$jhModel = Join-Path $jhVoiceRoot 'ggml-small.bin'
Get-JhVerifiedFile 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin?download=true' $jhModel '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b'
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/ggml-org/whisper.cpp/b4938/LICENSE' -OutFile (Join-Path $jhVoiceRoot 'LICENSE')
$jhConfigPath = Join-Path $PSScriptRoot 'config.local.json'
$jhConfig = if (Test-Path -LiteralPath $jhConfigPath) { Get-Content -LiteralPath $jhConfigPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$jhConfig | Add-Member -Force NoteProperty speechExecutable (Join-Path $jhVoiceRoot 'Release/whisper-cli.exe')
$jhConfig | Add-Member -Force NoteProperty speechModel $jhModel
[IO.File]::WriteAllText($jhConfigPath, ($jhConfig | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
& (Join-Path $PSScriptRoot 'start.ps1') -Restart
Write-Output 'Local speech is installed. Choose a microphone mode in the game.'
