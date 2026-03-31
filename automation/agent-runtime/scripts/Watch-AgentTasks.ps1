param(
  [switch]$Recover,
  [int]$StaleMinutes = 15
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$results = @()
$staleCutoff = (Get-Date).ToUniversalTime().AddMinutes(-1 * $StaleMinutes)

foreach ($dir in Get-RecentTasks) {
  $taskId = $dir.Name
  $manifest = Get-TaskManifest -TaskId $taskId
  $needsRestart = $false
  $reason = ""
  $currentStatus = [string]$manifest.status

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
      break
    }
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
      $results += [pscustomobject]@{
        taskId = $taskId
        action = "restarted"
        backend = "tmux"
        sessionName = $tmux.SessionName
        pid = $null
        reason = $reason
        status = $manifest.status
      }
    } else {
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
