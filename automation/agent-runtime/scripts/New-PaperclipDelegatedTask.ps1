param(
  [Parameter(Mandatory = $true)][string]$Title,
  [string]$Description = "",
  [ValidateSet('low','medium','high','critical')][string]$Priority = "high",
  [string]$ProjectId = "",
  [string]$GoalId = "",
  [string]$ParentIssueId = "",
  [string]$AssigneeAgentId = "",
  [string]$ChatId = "",
  [string]$TopicId = "",
  [switch]$SkipWake,
  [switch]$SkipTelegramNotice,
  [switch]$SkipWatchRegistration
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$cfg = Get-PaperclipBridgeConfig
$targetAgentId = if ([string]::IsNullOrWhiteSpace($AssigneeAgentId)) { [string]$cfg.felixAgentId } else { $AssigneeAgentId }
$resolvedProjectId = if ([string]::IsNullOrWhiteSpace($ProjectId)) { [string]$cfg.defaultProjectId } else { $ProjectId }
$resolvedGoalId = if ([string]::IsNullOrWhiteSpace($GoalId)) { [string]$cfg.defaultGoalId } else { $GoalId }
$resolvedChatId = if ([string]::IsNullOrWhiteSpace($ChatId)) { [string]$cfg.defaultChatId } else { $ChatId }
$resolvedTopicId = if ([string]::IsNullOrWhiteSpace($TopicId)) { [string]$cfg.defaultTopicId } else { $TopicId }

$payload = [ordered]@{
  title = $Title
  description = $Description
  assigneeAgentId = $targetAgentId
  status = 'todo'
  priority = $Priority
}

if (-not [string]::IsNullOrWhiteSpace($resolvedProjectId)) {
  $payload.projectId = $resolvedProjectId
}

if (-not [string]::IsNullOrWhiteSpace($resolvedGoalId)) {
  $payload.goalId = $resolvedGoalId
}

if (-not [string]::IsNullOrWhiteSpace($ParentIssueId)) {
  $payload.parentId = $ParentIssueId
}

$issue = Invoke-PaperclipApi -Method POST -Path "companies/$($cfg.companyId)/issues" -Body $payload
$issueUrl = Get-PaperclipIssueUrl -Issue $issue -Config $cfg
$wakeSent = $false

if (-not $SkipWake) {
  $wakeBody = @{
    source = 'assignment'
    triggerDetail = 'manual'
    reason = "Telegram requested task $($issue.identifier): $Title"
  }

  Invoke-PaperclipApi -Method POST -Path "agents/$targetAgentId/wakeup" -Body $wakeBody | Out-Null
  $wakeSent = $true
}

if (-not $SkipWatchRegistration) {
  $state = Get-PaperclipBridgeState
  $watchEntry = [ordered]@{
    issueId = $issue.id
    identifier = $issue.identifier
    title = $issue.title
    chatId = $resolvedChatId
    topicId = $resolvedTopicId
    follow = $true
    createdAt = Get-Timestamp
    updatedAt = Get-Timestamp
    lastIssueStatus = $issue.status
    lastActiveRunId = if ($issue.activeRun) { [string]$issue.activeRun.id } else { $null }
    lastRunStatus = if ($issue.activeRun) { [string]$issue.activeRun.status } else { $null }
    lastCommentId = $null
    lastCommentUpdatedAt = $null
    lastNotifiedAt = $null
    issueUrl = $issueUrl
  }

  $state.watchedIssues | Add-Member -NotePropertyName $issue.id -NotePropertyValue ([pscustomobject]$watchEntry) -Force
  Save-PaperclipBridgeState -State $state
}

if (-not $SkipTelegramNotice -and -not [string]::IsNullOrWhiteSpace($resolvedChatId)) {
  $lines = @(
    'Paperclip task created',
    "- Issue: $($issue.identifier)",
    "- Title: $($issue.title)",
    "- Status: $($issue.status)",
    "- Assigned to agent: $targetAgentId"
  )

  if ($wakeSent) {
    $lines += '- Wake sent: yes'
  }

  if ($issueUrl) {
    $lines += "- Paperclip URL: $issueUrl"
  }

  Send-TelegramBotMessage -Message ($lines -join "`n") -ChatId $resolvedChatId -TopicId $resolvedTopicId
}

[pscustomobject]@{
  issueId = $issue.id
  identifier = $issue.identifier
  title = $issue.title
  status = $issue.status
  assigneeAgentId = $issue.assigneeAgentId
  wakeSent = $wakeSent
  issueUrl = $issueUrl
  chatId = $resolvedChatId
  topicId = $resolvedTopicId
} | ConvertTo-Json -Depth 6

