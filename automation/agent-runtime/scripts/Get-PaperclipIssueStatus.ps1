param(
  [string]$IssueId = "",
  [string]$Identifier = ""
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

if ([string]::IsNullOrWhiteSpace($IssueId) -and [string]::IsNullOrWhiteSpace($Identifier)) {
  throw 'Provide -IssueId or -Identifier.'
}

$cfg = Get-PaperclipBridgeConfig

if ([string]::IsNullOrWhiteSpace($IssueId)) {
  $issues = ConvertTo-NormalizedArray (Invoke-PaperclipApi -Method GET -Path "companies/$($cfg.companyId)/issues")
  $match = $issues | Where-Object { $_.identifier -eq $Identifier } | Select-Object -First 1
  if ($null -eq $match) {
    throw "Paperclip issue not found for identifier: $Identifier"
  }
  $IssueId = [string]$match.id
}

$issue = Invoke-PaperclipApi -Method GET -Path "issues/$IssueId"
$latestComment = Get-PaperclipLatestComment -IssueId $IssueId
$run = $null
if ($issue.activeRun -and $issue.activeRun.id) {
  $run = Invoke-PaperclipApi -Method GET -Path "heartbeat-runs/$($issue.activeRun.id)"
}

[ordered]@{
  issueId = $issue.id
  identifier = $issue.identifier
  title = $issue.title
  status = $issue.status
  priority = $issue.priority
  assigneeAgentId = $issue.assigneeAgentId
  activeRunId = if ($run) { $run.id } else { $null }
  activeRunStatus = if ($run) { $run.status } else { $null }
  latestCommentId = if ($latestComment) { $latestComment.id } else { $null }
  latestCommentBody = if ($latestComment) { $latestComment.body } else { $null }
  updatedAt = $issue.updatedAt
  issueUrl = Get-PaperclipIssueUrl -Issue $issue -Config $cfg
} | ConvertTo-Json -Depth 6
