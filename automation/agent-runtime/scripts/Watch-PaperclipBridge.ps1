param(
  [switch]$Once,
  [int]$PollSeconds = 0
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

function Get-CommentPreview {
  param([AllowNull()]$Comment)

  if ($null -eq $Comment) {
    return $null
  }

  $body = [string]$Comment.body
  if ([string]::IsNullOrWhiteSpace($body)) {
    return $null
  }

  $singleLine = (($body -split "`r?`n") -join ' ') -replace '\s+', ' '
  if ($singleLine.Length -gt 220) {
    return ($singleLine.Substring(0, 217) + '...')
  }

  return $singleLine
}

function Get-IssueSnapshot {
  param([Parameter(Mandatory = $true)][string]$IssueId)

  $cfg = Get-PaperclipBridgeConfig
  $issue = Invoke-PaperclipApi -Method GET -Path "issues/$IssueId"
  $latestComment = Get-PaperclipLatestComment -IssueId $IssueId
  $run = $null
  if ($issue.activeRun -and $issue.activeRun.id) {
    $run = Invoke-PaperclipApi -Method GET -Path "heartbeat-runs/$($issue.activeRun.id)"
  }

  [pscustomobject]@{
    issue = $issue
    latestComment = $latestComment
    activeRun = $run
    issueUrl = Get-PaperclipIssueUrl -Issue $issue -Config $cfg
  }
}

function Send-IssueUpdateIfNeeded {
  param(
    [Parameter(Mandatory = $true)]$WatchEntry,
    [Parameter(Mandatory = $true)]$Snapshot
  )

  $changes = @()
  $issue = $Snapshot.issue
  $run = $Snapshot.activeRun
  $latestComment = $Snapshot.latestComment

  if ([string]$WatchEntry.lastIssueStatus -ne [string]$issue.status) {
    $changes += "status: $($WatchEntry.lastIssueStatus) -> $($issue.status)"
  }

  $currentRunId = if ($run) { [string]$run.id } else { $null }
  $currentRunStatus = if ($run) { [string]$run.status } else { $null }

  if ([string]$WatchEntry.lastActiveRunId -ne [string]$currentRunId) {
    if ([string]::IsNullOrWhiteSpace($WatchEntry.lastActiveRunId) -and -not [string]::IsNullOrWhiteSpace($currentRunId)) {
      $changes += 'run started'
    } elseif (-not [string]::IsNullOrWhiteSpace($WatchEntry.lastActiveRunId) -and [string]::IsNullOrWhiteSpace($currentRunId)) {
      $changes += 'run cleared'
    } else {
      $changes += 'run changed'
    }
  }

  if ([string]$WatchEntry.lastRunStatus -ne [string]$currentRunStatus -and -not [string]::IsNullOrWhiteSpace($currentRunStatus)) {
    if ([string]::IsNullOrWhiteSpace($WatchEntry.lastRunStatus)) {
      $changes += "run status: $currentRunStatus"
    } else {
      $changes += "run status: $($WatchEntry.lastRunStatus) -> $currentRunStatus"
    }
  }

  $latestCommentId = if ($latestComment) { [string]$latestComment.id } else { $null }
  $latestCommentUpdatedAt = if ($latestComment) { [string]$latestComment.updatedAt } else { $null }

  if ([string]$WatchEntry.lastCommentId -ne [string]$latestCommentId -and -not [string]::IsNullOrWhiteSpace($latestCommentId)) {
    $changes += 'new comment'
  }

  if ($changes.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$WatchEntry.chatId)) {
    $lines = @(
      'Paperclip task update',
      "- Issue: $($issue.identifier)",
      "- Title: $($issue.title)",
      "- Status: $($issue.status)"
    )

    if ($currentRunStatus) {
      $lines += "- Active run: $currentRunStatus"
    }

    $lines += "- Changes: $($changes -join '; ')"

    $commentPreview = Get-CommentPreview -Comment $latestComment
    if ($commentPreview) {
      $lines += "- Latest comment: $commentPreview"
    }

    if ($run -and $run.status -eq 'failed' -and $run.error) {
      $lines += "- Run error: $($run.error)"
    }

    if ($Snapshot.issueUrl) {
      $lines += "- Paperclip URL: $($Snapshot.issueUrl)"
    }

    Send-TelegramBotMessage -Message ($lines -join "`n") -ChatId ([string]$WatchEntry.chatId) -TopicId ([string]$WatchEntry.topicId)
    $WatchEntry.lastNotifiedAt = Get-Timestamp
  }

  $WatchEntry.identifier = $issue.identifier
  $WatchEntry.title = $issue.title
  $WatchEntry.updatedAt = Get-Timestamp
  $WatchEntry.lastIssueStatus = $issue.status
  $WatchEntry.lastActiveRunId = $currentRunId
  $WatchEntry.lastRunStatus = $currentRunStatus
  $WatchEntry.lastCommentId = $latestCommentId
  $WatchEntry.lastCommentUpdatedAt = $latestCommentUpdatedAt
  $WatchEntry.issueUrl = $Snapshot.issueUrl
  $WatchEntry.lastErrorMessage = $null
  $WatchEntry.consecutiveErrors = 0

  if ($issue.status -in @('done','cancelled')) {
    $WatchEntry.follow = $false
  }
}

$cfg = Get-PaperclipBridgeConfig
$resolvedPollSeconds = if ($PollSeconds -gt 0) { $PollSeconds } else { [int]$cfg.watchPollSeconds }

while ($true) {
  $state = Get-PaperclipBridgeState
  $dirty = $false

  foreach ($prop in @($state.watchedIssues.PSObject.Properties)) {
    $watchEntry = $prop.Value
    if (-not $watchEntry.follow) {
      continue
    }

    try {
      $snapshot = Get-IssueSnapshot -IssueId ([string]$watchEntry.issueId)
      Send-IssueUpdateIfNeeded -WatchEntry $watchEntry -Snapshot $snapshot
      $dirty = $true
    } catch {
      $errorMessage = [string]$_.Exception.Message
      $lastErrorMessage = if ($watchEntry.PSObject.Properties['lastErrorMessage']) { [string]$watchEntry.lastErrorMessage } else { $null }
      $consecutiveErrors = if ($watchEntry.PSObject.Properties['consecutiveErrors']) { [int]$watchEntry.consecutiveErrors } else { 0 }
      $watchEntry.lastErrorMessage = $errorMessage
      $watchEntry.consecutiveErrors = ($consecutiveErrors + 1)

      $shouldNotify = (-not [string]::IsNullOrWhiteSpace([string]$watchEntry.chatId)) -and ($errorMessage -ne $lastErrorMessage)
      if ($shouldNotify) {
        $lines = @(
          'Paperclip task watcher warning',
          "- Issue id: $($watchEntry.issueId)",
          "- Title: $($watchEntry.title)",
          "- Error: $errorMessage"
        )
        Send-TelegramBotMessage -Message ($lines -join "`n") -ChatId ([string]$watchEntry.chatId) -TopicId ([string]$watchEntry.topicId)
        $watchEntry.lastNotifiedAt = Get-Timestamp
      }
      $dirty = $true
    }
  }

  if ($dirty) {
    Save-PaperclipBridgeState -State $state
  }

  if ($Once) {
    break
  }

  Start-Sleep -Seconds $resolvedPollSeconds
}

