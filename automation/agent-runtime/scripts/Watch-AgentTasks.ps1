param(
  [switch]$Recover,
  [int]$StaleMinutes = 15
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$results = @()
$staleCutoff = (Get-Date).ToUniversalTime().AddMinutes(-1 * $StaleMinutes)
$config = Get-AgentRuntimeConfig

foreach ($dir in Get-RecentTasks) {
  $taskId = $dir.Name
  $manifest = Get-TaskManifest -TaskId $taskId
  $needsRestart = $false
  $reason = ""
  $currentStatus = [string]$manifest.status
  $promotionCandidate = $false

  switch ($currentStatus) {
    "pending" {
      $needsRestart = $true
      $reason = "status:pending"
      break
    }
    "retrying" {
      $needsRestart = $true
      $reason = "status:retrying"
      break
    }
    "running" {
      if ($manifest.backend -eq "tmux") {
        if (-not (Test-TmuxSessionAlive -SessionName $manifest.sessionName)) {
          $needsRestart = $true
          $reason = "missing-tmux-session"
        }
      } else {
        if (-not (Test-DetachedProcessAlive -ProcessId $manifest.processId)) {
          $needsRestart = $true
          $reason = "missing-process"
        }
      }

      if (-not $needsRestart) {
        $lastActivity = Get-TaskLastActivity -TaskId $taskId
        if ($lastActivity -and $lastActivity -lt $staleCutoff) {
          $needsRestart = $true
          $reason = "stale-activity"
        }
      }

      if (-not $needsRestart -and $Recover -and $manifest.backend -eq 'detached-pwsh' -and $config.preferredBackend -eq 'tmux') {
        $availableBackend = Get-AvailableBackend
        if ($availableBackend -eq 'tmux' -and (Test-DetachedProcessAlive -ProcessId $manifest.processId)) {
          $promotionCandidate = $true
        }
      }
      break
    }
  }

  if ($promotionCandidate) {
    $oldPid = [int]$manifest.processId
    try {
      Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    } catch {
    }

    try {
      $tmux = Start-TmuxAgentProcess -TaskId $taskId
      $manifest = Update-TaskManifest -TaskId $taskId -Update {
        param($m)
        $m.backend = 'tmux'
        $m.sessionName = $tmux.SessionName
        $m.processId = $null
        $m.status = 'running'
        if ($m.PSObject.Properties.Name -notcontains 'recoveredAt') {
          $m | Add-Member -NotePropertyName recoveredAt -NotePropertyValue (Get-Timestamp) -Force
        } else {
          $m.recoveredAt = Get-Timestamp
        }
      }
      & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $taskId -Event restarted -Reason 'promoted-to-preferred-backend' -Extra 'Promoted from detached-pwsh to tmux after tmux became healthy again' | Out-Null
      $results += [pscustomobject]@{
        taskId = $taskId
        action = 'promoted'
        backend = 'tmux'
        sessionName = $tmux.SessionName
        pid = $null
        reason = 'promoted-to-preferred-backend'
        status = $manifest.status
      }
    } catch {
      $proc = Start-DetachedAgentProcess -TaskId $taskId
      $manifest = Update-TaskManifest -TaskId $taskId -Update {
        param($m)
        $m.backend = 'detached-pwsh'
        $m.processId = $proc.Id
        $m.sessionName = $null
        $m.status = 'running'
        if ($m.PSObject.Properties.Name -notcontains 'recoveredAt') {
          $m | Add-Member -NotePropertyName recoveredAt -NotePropertyValue (Get-Timestamp) -Force
        } else {
          $m.recoveredAt = Get-Timestamp
        }
      }
      & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $taskId -Event 'needs-attention' -Reason 'tmux-promotion-failed' -Extra $_.Exception.Message | Out-Null
      $results += [pscustomobject]@{
        taskId = $taskId
        action = 'promotion-failed-fallback-restored'
        backend = 'detached-pwsh'
        sessionName = $null
        pid = $proc.Id
        reason = 'tmux-promotion-failed'
        status = $manifest.status
      }
    }

    continue
  }

  if ($needsRestart -and $Recover) {
    if ($manifest.backend -eq "detached-pwsh" -and (Test-DetachedProcessAlive -ProcessId $manifest.processId)) {
      try {
        Stop-Process -Id ([int]$manifest.processId) -Force -ErrorAction SilentlyContinue
      } catch {
      }
    }

    $backend = Get-AvailableBackend
    if ($backend -eq "tmux") {
      try {
        $tmux = Start-TmuxAgentProcess -TaskId $taskId
        $manifest = Update-TaskManifest -TaskId $taskId -Update {
          param($m)
          $m.backend = "tmux"
          $m.sessionName = $tmux.SessionName
          $m.processId = $null
          $m.status = "running"
          if ($m.PSObject.Properties.Name -notcontains 'recoveredAt') {
            $m | Add-Member -NotePropertyName recoveredAt -NotePropertyValue (Get-Timestamp) -Force
          } else {
            $m.recoveredAt = Get-Timestamp
          }
        }
        & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $taskId -Event restarted -Reason $reason -Extra 'Recovered by watcher into tmux backend' | Out-Null
        $results += [pscustomobject]@{
          taskId = $taskId
          action = "restarted"
          backend = "tmux"
          sessionName = $tmux.SessionName
          pid = $null
          reason = $reason
          status = $manifest.status
        }
      } catch {
        $backend = 'detached-pwsh'
        & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $taskId -Event 'needs-attention' -Reason 'tmux-launch-failed' -Extra $_.Exception.Message | Out-Null
      }
    }

    if ($backend -eq "detached-pwsh") {
      $proc = Start-DetachedAgentProcess -TaskId $taskId
      $manifest = Update-TaskManifest -TaskId $taskId -Update {
        param($m)
        $m.backend = "detached-pwsh"
        $m.processId = $proc.Id
        $m.sessionName = $null
        $m.status = "running"
        if ($m.PSObject.Properties.Name -notcontains 'recoveredAt') {
          $m | Add-Member -NotePropertyName recoveredAt -NotePropertyValue (Get-Timestamp) -Force
        } else {
          $m.recoveredAt = Get-Timestamp
        }
      }
      & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $taskId -Event restarted -Reason $reason -Extra 'Recovered by watcher into detached backend' | Out-Null
      $results += [pscustomobject]@{
        taskId = $taskId
        action = "restarted"
        backend = "detached-pwsh"
        sessionName = $null
        pid = $proc.Id
        reason = $reason
        status = $manifest.status
      }
    }

    continue
  }

  if ($needsRestart -and -not $Recover) {
    & (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $taskId -Event 'needs-attention' -Reason $reason -Extra 'Watcher detected issue but recover was not requested' | Out-Null
  }

  $summary = Get-TaskSummary -TaskId $taskId
  $results += [pscustomobject]@{
    taskId = $summary.taskId
    action = if ($needsRestart) { "needs-restart" } else { "ok" }
    backend = $summary.backend
    sessionName = $summary.sessionName
    pid = $summary.processId
    reason = $reason
    status = $summary.status
    completedRequired = $summary.completedRequired
    totalRequired = $summary.totalRequired
    lastActivityUtc = $summary.lastActivityUtc
  }
}

$results | ConvertTo-Json -Depth 20
