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
  [string]$MessageId = "",
  [switch]$SkipWake,
  [switch]$SkipTelegramNotice,
  [switch]$SkipWatchRegistration
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force
Ensure-PaperclipIntakeLayout

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$safeMessageId = if ([string]::IsNullOrWhiteSpace($MessageId)) { 'manual' } else { ($MessageId -replace '[^A-Za-z0-9_-]', '-') }
$fileName = "paperclip-intake-$stamp-$safeMessageId.json"
$path = Join-Path (Get-PaperclipIntakePendingRoot) $fileName

$request = [ordered]@{
  source = 'manual-queue'
  createdAt = Get-Timestamp
  title = $Title
  description = $Description
  priority = $Priority
  projectId = $ProjectId
  goalId = $GoalId
  parentIssueId = $ParentIssueId
  assigneeAgentId = $AssigneeAgentId
  chatId = $ChatId
  topicId = $TopicId
  messageId = $MessageId
  skipWake = [bool]$SkipWake
  skipTelegramNotice = [bool]$SkipTelegramNotice
  skipWatchRegistration = [bool]$SkipWatchRegistration
}

Write-JsonFile -Path $path -InputObject $request
[pscustomobject]@{
  queued = $true
  path = $path
  title = $Title
  createdAt = $request.createdAt
} | ConvertTo-Json -Depth 5
