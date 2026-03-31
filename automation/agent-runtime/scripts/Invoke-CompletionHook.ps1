param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$root = Get-AgentRuntimeRoot
$config = Get-AgentRuntimeConfig
$manifest = Get-TaskManifest -TaskId $TaskId
$completion = Get-Content -LiteralPath $manifest.completionPath -Raw
$logPath = Join-Path $root "logs\completion-events.jsonl"
$sentinelPath = Join-Path $manifest.taskDir "done.json"

$event = [ordered]@{
  timestamp = Get-Timestamp
  taskId = $TaskId
  title = $manifest.title
  workdir = $manifest.workdir
  completionPath = $manifest.completionPath
  backend = $manifest.backend
  status = $manifest.status
  summary = $completion
}

($event | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $logPath
$event | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $sentinelPath
& (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $TaskId -Event completed -Extra $manifest.completionPath | Out-Null

if ($config.customCompletionHook -and -not [string]::IsNullOrWhiteSpace([string]$config.customCompletionHook)) {
  try {
    & $config.customCompletionHook $TaskId $manifest.taskDir $manifest.completionPath | Out-Null
  } catch {
    # Do not fail completion because a custom hook failed.
  }
}

Write-Output "HOOK_OK=$TaskId"
