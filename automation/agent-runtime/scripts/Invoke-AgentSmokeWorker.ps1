param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'runtime\AgentRuntime.psm1'
Import-Module $modulePath -Force

$manifest = Get-TaskManifest -TaskId $TaskId
$logDir = $manifest.logDir
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$loopLog = Join-Path $logDir 'loop.log'
$completionPath = $manifest.completionPath
$started = Get-Timestamp

$manifest = Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  $m.status = 'running'
  if ($m.PSObject.Properties['lastAttemptAt']) { $m.lastAttemptAt = $started } else { $m | Add-Member -NotePropertyName lastAttemptAt -NotePropertyValue $started -Force }
}

"[$started] smoke-worker started" | Add-Content -LiteralPath $loopLog
Start-Sleep -Seconds 90
$finished = Get-Timestamp
"[$finished] smoke-worker completed" | Add-Content -LiteralPath $loopLog
Set-Content -LiteralPath $completionPath -Value "# Completion`n`nSmoke worker completed successfully."
$manifest = Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  $m.status = 'completed'
  if ($m.PSObject.Properties['completedAt']) { $m.completedAt = $finished } else { $m | Add-Member -NotePropertyName completedAt -NotePropertyValue $finished -Force }
}
& (Join-Path $PSScriptRoot 'Invoke-CompletionHook.ps1') -TaskId $TaskId | Out-Null
