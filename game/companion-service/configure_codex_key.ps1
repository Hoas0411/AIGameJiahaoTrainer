$ErrorActionPreference = 'Stop'
$jhSecretDir = 'D:/Codex/必要依赖/嘉豪训练器/credentials'
$jhSecretPath = Join-Path $jhSecretDir 'openai-api-key.dpapi'
New-Item -ItemType Directory -Force -Path $jhSecretDir | Out-Null
Write-Host '请输入 OpenAI Platform API Key；输入内容不会显示，也不会发送到 Codex 聊天。'
$jhSecureKey = Read-Host 'API Key' -AsSecureString
if ($jhSecureKey.Length -lt 20) { throw 'Key 太短，未保存。' }
$jhSecureKey | ConvertFrom-SecureString | Set-Content -LiteralPath $jhSecretPath -Encoding ascii
Write-Host '密钥已用当前 Windows 用户的 DPAPI 加密，保存在 D 盘独立依赖目录。正在重启麦小鼠服务。'
& (Join-Path $PSScriptRoot 'start.ps1') -Restart
$jhHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:18765/health' -TimeoutSec 5
Write-Host ('服务模型：' + $jhHealth.model)
Write-Host ('配置状态：' + $(if ($jhHealth.ready) { '可发起验证请求' } else { $jhHealth.error }))
Write-Host '请回到 Codex，告诉我“已在窗口输入密钥”。不要把 Key 发在聊天里。'
Read-Host '按 Enter 关闭窗口' | Out-Null
