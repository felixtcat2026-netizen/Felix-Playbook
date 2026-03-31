param(
  [Parameter(Mandatory = $true)][string]$TaskId,
  [Parameter(Mandatory = $true)][ValidateSet('started','restarted','failed','completed','needs-attention')][string]$Event,
  [string]$Reason = '',
  [string]$Extra = ''
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'runtime\AgentRuntime.psm1'
Import-Module $modulePath -Force

$root = Get-AgentRuntimeRoot
$config = Get-AgentRuntimeConfig
$manifest = Get-TaskManifest -TaskId $TaskId
$logPath = Join-Path $root 'logs\ops-events.jsonl'

$eventRecord = [ordered]@{
  timestamp = Get-Timestamp
  event = $Event
  taskId = $TaskId
  title = $manifest.title
  status = $manifest.status
  backend = $manifest.backend
  sessionName = $manifest.sessionName
  processId = $manifest.processId
  reason = $Reason
  extra = $Extra
}

($eventRecord | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $logPath

if ($config.notifyTransport -ne 'telegram') {
  Write-Output "OPS_NOTICE_LOGGED=$TaskId"
  exit 0
}

$openclawConfig = 'C:\Users\Damian\.openclaw\openclaw.json'
if (-not (Test-Path -LiteralPath $openclawConfig)) {
  Write-Output "OPS_NOTICE_LOGGED=$TaskId"
  exit 0
}

try {
  $cfg = Get-Content -LiteralPath $openclawConfig -Raw | ConvertFrom-Json
  $token = $cfg.channels.telegram.botToken
  $chatId = $config.defaultTopicChatId
  $topicId = [string]$config.defaultTopicId
  if ($token -and $chatId -and $topicId) {
    $eventLabel = switch ($Event) {
      'started' { 'Task started' }
      'restarted' { 'Task restarted' }
      'failed' { 'Task failed' }
      'completed' { 'Task completed' }
      'needs-attention' { 'Task needs attention' }
      default { 'Task update' }
    }

    $lines = @(
      $eventLabel,
      "- ID: $TaskId",
      "- Title: $($manifest.title)",
      "- Backend: $($manifest.backend)"
    )

    if ($manifest.sessionName) { $lines += "- Session: $($manifest.sessionName)" }
    if ($manifest.processId) { $lines += "- PID: $($manifest.processId)" }
    if ($Reason) { $lines += "- Reason: $Reason" }
    if ($Extra) { $lines += "- Details: $Extra" }

    $body = @{
      chat_id = $chatId
      message_thread_id = $topicId
      text = ($lines -join "`n")
    }

    Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$token/sendMessage" -Body $body | Out-Null
  }
} catch {
  # Event log is the durable fallback.
}

Write-Output "OPS_NOTICE_OK=$TaskId"
