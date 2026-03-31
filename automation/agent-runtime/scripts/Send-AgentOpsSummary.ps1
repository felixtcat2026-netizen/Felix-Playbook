param(
  [int]$Top = 10
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'runtime\AgentRuntime.psm1'
Import-Module $modulePath -Force

$config = Get-AgentRuntimeConfig
$summaryScript = Join-Path $PSScriptRoot 'Get-AgentOpsSummary.ps1'
$text = & $summaryScript -Top $Top

$root = Get-AgentRuntimeRoot
$logPath = Join-Path $root 'logs\ops-events.jsonl'
$eventRecord = [ordered]@{
  timestamp = Get-Timestamp
  event = 'summary'
  taskId = ''
  title = 'Ops summary'
  status = ''
  backend = ''
  sessionName = ''
  processId = $null
  reason = ''
  extra = $text
}
($eventRecord | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $logPath

if ($config.notifyTransport -ne 'telegram') {
  Write-Output $text
  exit 0
}

$openclawConfig = 'C:\Users\Damian\.openclaw\openclaw.json'
if (-not (Test-Path -LiteralPath $openclawConfig)) {
  Write-Output $text
  exit 0
}

try {
  $cfg = Get-Content -LiteralPath $openclawConfig -Raw | ConvertFrom-Json
  $token = $cfg.channels.telegram.botToken
  $chatId = $config.defaultTopicChatId
  $topicId = [string]$config.defaultTopicId

  if ($token -and $chatId -and $topicId) {
    Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$token/sendMessage" -Body @{
      chat_id = $chatId
      message_thread_id = $topicId
      text = $text
    } | Out-Null
  }
} catch {
  # The local event log is the durable fallback.
}

Write-Output $text
