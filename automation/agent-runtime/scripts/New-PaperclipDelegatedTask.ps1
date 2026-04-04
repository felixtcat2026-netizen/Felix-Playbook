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

$params = @{
  Title = $Title
  Description = $Description
  Priority = $Priority
  ProjectId = $ProjectId
  GoalId = $GoalId
  ParentIssueId = $ParentIssueId
  AssigneeAgentId = $AssigneeAgentId
  ChatId = $ChatId
  TopicId = $TopicId
  SkipWake = [bool]$SkipWake
  SkipTelegramNotice = [bool]$SkipTelegramNotice
  SkipWatchRegistration = [bool]$SkipWatchRegistration
}

New-PaperclipDelegatedIssue @params | ConvertTo-Json -Depth 6
