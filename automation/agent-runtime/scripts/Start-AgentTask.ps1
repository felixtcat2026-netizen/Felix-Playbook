param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$manifest = Get-TaskManifest -TaskId $TaskId
$backend = Get-AvailableBackend

if ($backend -eq "tmux") {
  $tmux = Start-TmuxAgentProcess -TaskId $TaskId
  $manifest = Update-TaskManifest -TaskId $TaskId -Update {
    param($m)
    $m.backend = "tmux"
    $m.sessionName = $tmux.SessionName
    $m.status = "running"
  }
  Write-Output "STARTED=$TaskId"
  Write-Output "BACKEND=tmux"
  Write-Output "SESSION_NAME=$($manifest.sessionName)"
  exit 0
}

$proc = Start-DetachedAgentProcess -TaskId $TaskId
$manifest = Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  $m.backend = "detached-pwsh"
  $m.processId = $proc.Id
  $m.status = "running"
}

Write-Output "STARTED=$TaskId"
Write-Output "BACKEND=detached-pwsh"
Write-Output "PID=$($proc.Id)"
