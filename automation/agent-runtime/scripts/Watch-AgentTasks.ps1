param(
  [switch]$Recover,
  [int]$StaleMinutes = 15
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$results = @()
$config = Get-AgentRuntimeConfig

foreach ($dir in Get-RecentTasks) {
  $taskId = $dir.Name
  $manifest = Get-TaskManifest -TaskId $taskId
  $summary = Get-TaskSummary -TaskId $taskId

  $manifest = Update-TaskManifest -TaskId $taskId -Update {
    param($m)
    $timestamp = Get-Timestamp
    if ($m.PSObject.Properties['lastHealthCheckAt']) { $m.lastHealthCheckAt = $timestamp } else { $m | Add-Member -NotePropertyName lastHealthCheckAt -NotePropertyValue $timestamp -Force }
    if ($m.PSObject.Properties['liveVerified']) { $m.liveVerified = $summary.liveVerified } else { $m | Add-Member -NotePropertyName liveVerified -NotePropertyValue $summary.liveVerified -Force }
    if ($m.PSObject.Properties['runtimeState']) { $m.runtimeState = $summary.runtimeState } else { $m | Add-Member -NotePropertyName runtimeState -NotePropertyValue $summary.runtimeState -Force }
    if ($m.PSObject.Properties['hasRecentActivity']) { $m.hasRecentActivity = $summary.hasRecentActivity } else { $m | Add-Member -NotePropertyName hasRecentActivity -NotePropertyValue $summary.hasRecentActivity -Force }
    if ($m.PSObject.Properties['hasArtifactProgress']) { $m.hasArtifactProgress = $summary.hasArtifactProgress } else { $m | Add-Member -NotePropertyName hasArtifactProgress -NotePropertyValue $summary.hasArtifactProgress -Force }
    if ($m.PSObject.Properties['stallReason']) { $m.stallReason = $summary.stallReason } else { $m | Add-Member -NotePropertyName stallReason -NotePropertyValue $summary.stallReason -Force }
    if ($m.PSObject.Properties['idleMinutes']) { $m.idleMinutes = $summary.idleMinutes } else { $m | Add-Member -NotePropertyName idleMinutes -NotePropertyValue $summary.idleMinutes -Force }
    if ([string]$m.status -eq 'running' -and $summary.runtimeState -eq 'stalled') {
      $m.status = 'stalled'
    }
  }

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
      # Only restart if the backing process is actually dead — if it's alive it's mid-sleep between retries
      $isAlive = if ($manifest.backend -eq 'tmux') {
        Test-TmuxSessionAlive -SessionName $manifest.sessionName
      } elseif ($manifest.backend -eq 'detached-pwsh') {
        Test-DetachedProcessAlive -ProcessId $manifest.processId
      } else { $false }
      if (-not $isAlive) {
        $needsRestart = $true
        $reason = "status:retrying-process-dead"
      }
      break
    }
    "stalled" {
      $needsRestart = $true
      $reason = if ($summary.stallReason) { $summary.stallReason } else { 'status:stalled' }
      break
    }
    "running" {
      switch ($summary.runtimeState) {
        "stalled" {
          $needsRestart = $true
          $reason = if ($summary.stallReason) { $summary.stallReason } else { "stalled" }
          break
        }
        "running-idle" {
          if (-not $summary.hasArtifactProgress -and $null -ne $summary.idleMinutes -and $summary.idleMinutes -ge $StaleMinutes) {
            $needsRestart = $true
            $reason = if ($summary.stallReason) { $summary.stallReason } else { "idle-no-artifact-progress" }
          }
          break
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
        $m.runtimeState = 'running-live'
        $m.liveVerified = $true
        $m.stallReason = $null
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
        $m.runtimeState = 'running-live'
        $m.liveVerified = $true
        $m.stallReason = $null
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
          $m.attempt = 0
          $m.runtimeState = 'running-live'
          $m.liveVerified = $true
          $m.stallReason = $null
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
        $m.attempt = 0
        $m.runtimeState = 'running-live'
        $m.liveVerified = $true
        $m.stallReason = $null
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

  $results += [pscustomobject]@{
    taskId = $summary.taskId
    action = if ($needsRestart) { 'needs-restart' } elseif ($summary.runtimeState -eq 'running-idle') { 'idle' } else { 'ok' }
    backend = $summary.backend
    sessionName = $summary.sessionName
    pid = $summary.processId
    reason = if ($reason) { $reason } else { $summary.stallReason }
    status = $manifest.status
    runtimeState = $summary.runtimeState
    liveVerified = $summary.liveVerified
    hasArtifactProgress = $summary.hasArtifactProgress
    completedRequired = $summary.completedRequired
    totalRequired = $summary.totalRequired
    idleMinutes = $summary.idleMinutes
    lastActivityUtc = $summary.lastActivityUtc
  }
}

$results | ConvertTo-Json -Depth 20
