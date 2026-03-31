param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$manifest = Get-TaskManifest -TaskId $TaskId
$backend = Get-AvailableBackend

if ($backend -eq "tmux") {
  try {
    $tmux = Start-TmuxAgentProcess -TaskId $TaskId
    $manifest = Update-TaskManifest -TaskId $TaskId -Update {
      param($m)
      $m.backend = "tmux"
      $m.sessionName = $tmux.SessionName
      $m.processId = $null
      $m.status = "running"
    }
    & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $TaskId -Event started -Extra "tmux session launched" | Out-Null
    Write-Output "STARTED=$TaskId"
    Write-Output "BACKEND=tmux"
    Write-Output "SESSION_NAME=$($manifest.sessionName)"
    exit 0
  } catch {
    $fallbackReason = "tmux launch failed; falling back to detached-pwsh: $($_.Exception.Message)"
    & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $TaskId -Event 'needs-attention' -Reason 'tmux-launch-failed' -Extra $fallbackReason | Out-Null
  }
}

$proc = Start-DetachedAgentProcess -TaskId $TaskId
$manifest = Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  $m.backend = "detached-pwsh"
  $m.processId = $proc.Id
  $m.sessionName = $null
  $m.status = "running"
}

& (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $TaskId -Event started -Extra "detached PowerShell worker launched" | Out-Null
Write-Output "STARTED=$TaskId"
Write-Output "BACKEND=detached-pwsh"
Write-Output "PID=$($proc.Id)"
