param([switch]$Play, [switch]$Restart)
$ErrorActionPreference = 'Stop'
# A configured local model is part of startup, including when the game EXE is opened directly.
$jhConfigPath = Join-Path $PSScriptRoot 'config.local.json'
if (Test-Path -LiteralPath $jhConfigPath) {
    $jhConfig = Get-Content -LiteralPath $jhConfigPath -Raw | ConvertFrom-Json
    if ($jhConfig.provider -eq 'ollama' -and $jhConfig.ollamaExecutable -and (Test-Path -LiteralPath $jhConfig.ollamaExecutable)) {
        $jhOllamaUrl = [Uri]$jhConfig.url
        $jhOllamaOrigin = $jhOllamaUrl.GetLeftPart([UriPartial]::Authority)
        if ($jhOllamaUrl.Host -notin @("localhost", "127.0.0.1", "[::1]")) { throw "Local runtime requires a loopback endpoint." }
        $jhOllamaReady = $false
        try { $null = Invoke-RestMethod -Uri ($jhOllamaOrigin + "/api/tags") -TimeoutSec 1; $jhOllamaReady = $true } catch { }
        if (-not $jhOllamaReady) {
            $env:OLLAMA_HOST = $jhOllamaUrl.Authority
            $env:OLLAMA_NO_CLOUD = '1'
            $env:OLLAMA_NUM_PARALLEL = '1'
            $env:OLLAMA_MAX_LOADED_MODELS = '1'
            if ($jhConfig.ollamaModels) { $env:OLLAMA_MODELS = $jhConfig.ollamaModels }
            Start-Process -FilePath $jhConfig.ollamaExecutable -ArgumentList 'serve' -WindowStyle Hidden
        }
    }
}
$jhNode = Join-Path $PSScriptRoot 'runtime/node.exe'
if (-not (Test-Path -LiteralPath $jhNode)) {
    $jhNode = (Get-Command node -ErrorAction Stop).Source
}
if (-not (Test-Path -LiteralPath $jhNode)) {
    $jhNode = (Get-Command node -ErrorAction Stop).Source
}
$jhNode = [IO.Path]::GetFullPath($jhNode)
$jhKeyFromStore = $false
if ($jhConfig.provider -eq 'codex_agents' -and -not $env:JH_AI_KEY -and -not $env:OPENAI_API_KEY) {
    $jhSecretPath = Join-Path $PSScriptRoot 'credentials/openai-api-key.dpapi'
    if (Test-Path -LiteralPath $jhSecretPath) {
        $jhSecureKey = (Get-Content -LiteralPath $jhSecretPath -Raw).Trim() | ConvertTo-SecureString
        $jhKeyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($jhSecureKey)
        try {
            $env:OPENAI_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($jhKeyPointer)
            $jhKeyFromStore = $true
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($jhKeyPointer)
        }
    }
}
if ($jhConfig.provider -eq 'codex_agents') {
    $jhApiUri = [Uri]$jhConfig.url
    $jhSystemProxy = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($jhApiUri)
    if ($jhSystemProxy -and $jhSystemProxy.AbsoluteUri -ne $jhApiUri.AbsoluteUri) {
        $env:HTTPS_PROXY = $jhSystemProxy.AbsoluteUri
        $env:NODE_USE_ENV_PROXY = '1'
    }
}
$jhPidFile = Join-Path $PSScriptRoot 'service.pid.json'
if ($Restart -and (Test-Path -LiteralPath $jhPidFile)) {
    $jhRecord = Get-Content -LiteralPath $jhPidFile -Raw | ConvertFrom-Json
    $jhProcess = Get-Process -Id $jhRecord.id -ErrorAction SilentlyContinue
    if ($null -ne $jhProcess -and $jhProcess.Path -eq $jhNode -and $jhProcess.StartTime.ToUniversalTime().Ticks.ToString() -eq $jhRecord.started) {
        Stop-Process -Id $jhProcess.Id
        $jhProcess.WaitForExit(5000) | Out-Null
    }
}
$jhHealth = $null
try {
    $jhHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:18765/health' -TimeoutSec 2
} catch { }
if ($null -ne $jhHealth -and $jhHealth.service -ne 'jiahao-companion') {
    throw 'Port 18765 is occupied by a different service.'
}
if ($null -eq $jhHealth) {
    $jhStarted = Start-Process -FilePath $jhNode -ArgumentList ('"' + (Join-Path $PSScriptRoot 'server.mjs') + '"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
    if ($jhKeyFromStore) { Remove-Item Env:OPENAI_API_KEY }
    @{id=$jhStarted.Id; started=$jhStarted.StartTime.ToUniversalTime().Ticks.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $jhPidFile -Encoding ascii
    for ($jhTry = 0; $jhTry -lt 15; $jhTry++) {
        Start-Sleep -Milliseconds 300
        try { $jhHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:18765/health' -TimeoutSec 1; break } catch { }
    }
    if ($null -eq $jhHealth -or $jhHealth.service -ne 'jiahao-companion') { throw 'Companion service failed to start. Check config.local.json.' }
}
if ($jhKeyFromStore -and (Test-Path Env:OPENAI_API_KEY)) { Remove-Item Env:OPENAI_API_KEY }
if ($Play) {
    $jhRoot = Split-Path $PSScriptRoot -Parent
    $jhGame = Join-Path $jhRoot 'JiahaoTrainer.exe'
    if (Test-Path -LiteralPath $jhGame) {
        Start-Process -FilePath $jhGame
    } else {
        & (Join-Path $jhRoot 'launch_game.cmd')
    }
}
