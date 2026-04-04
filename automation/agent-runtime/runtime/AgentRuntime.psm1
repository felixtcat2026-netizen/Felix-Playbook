Set-StrictMode -Version Latest

function Get-AgentRuntimeRoot {
  Split-Path -Parent $PSScriptRoot
}

function Ensure-AgentRuntimeLayout {
  $root = Get-AgentRuntimeRoot
  @(
    (Join-Path $root "tasks"),
    (Join-Path $root "state"),
    (Join-Path $root "logs"),
    (Join-Path $root "archive")
  ) | ForEach-Object {
    if (-not (Test-Path -LiteralPath $_)) {
      New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
  }
}

function Get-AgentRuntimeConfig {
  Ensure-AgentRuntimeLayout
  $path = Join-Path (Get-AgentRuntimeRoot) "state\runtime-config.json"
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing runtime config: $path"
  }
  Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$InputObject
  )

  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  $InputObject | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path
}

function ConvertTo-NormalizedArray {
  param($InputObject)

  if ($null -eq $InputObject) {
    return @()
  }

  if ($InputObject -is [string]) {
    return @($InputObject)
  }

  if ($InputObject -is [System.Collections.IEnumerable]) {
    return @($InputObject)
  }

  return @($InputObject)
}
function Get-TaskRoot {
  Join-Path (Get-AgentRuntimeRoot) "tasks"
}

function Get-TaskPath {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Join-Path (Get-TaskRoot) $TaskId
}

function Get-TaskManifestPath {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Join-Path (Get-TaskPath $TaskId) "task.json"
}

function Get-ChecklistPath {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Join-Path (Get-TaskPath $TaskId) "checklist.json"
}

function Get-PRDPath {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Join-Path (Get-TaskPath $TaskId) "prd.md"
}

function Get-CompletionPath {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Join-Path (Get-TaskPath $TaskId) "completion.md"
}

function Get-LogsPath {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Join-Path (Get-TaskPath $TaskId) "logs"
}

function Get-Timestamp {
  (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
}

function Get-OpenClawConfigPath {
  "C:\Users\Damian\.openclaw\openclaw.json"
}

function Get-OpenClawConfig {
  $path = Get-OpenClawConfigPath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing OpenClaw config: $path"
  }

  Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Get-PaperclipBridgeConfigPath {
  Join-Path (Get-AgentRuntimeRoot) "state\paperclip-bridge.config.json"
}

function Get-PaperclipBridgeStatePath {
  Join-Path (Get-AgentRuntimeRoot) "state\paperclip-bridge.state.json"
}

function Get-PaperclipIntakeRoot {
  Join-Path (Get-AgentRuntimeRoot) "state\paperclip-intake"
}

function Get-PaperclipIntakePendingRoot {
  Join-Path (Get-PaperclipIntakeRoot) "pending"
}

function Get-PaperclipIntakeProcessedRoot {
  Join-Path (Get-PaperclipIntakeRoot) "processed"
}

function Get-PaperclipIntakeFailedRoot {
  Join-Path (Get-PaperclipIntakeRoot) "failed"
}

function Ensure-PaperclipIntakeLayout {
  @(
    (Get-PaperclipIntakeRoot),
    (Get-PaperclipIntakePendingRoot),
    (Get-PaperclipIntakeProcessedRoot),
    (Get-PaperclipIntakeFailedRoot)
  ) | ForEach-Object {
    if (-not (Test-Path -LiteralPath $_)) {
      New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
  }
}

function Get-PaperclipBridgeConfig {
  Ensure-AgentRuntimeLayout
  $path = Get-PaperclipBridgeConfigPath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing Paperclip bridge config: $path"
  }

  Read-JsonFile -Path $path
}

function Get-PaperclipBridgeState {
  Ensure-AgentRuntimeLayout
  $path = Get-PaperclipBridgeStatePath
  if (-not (Test-Path -LiteralPath $path)) {
    return [pscustomobject]@{
      watchedIssues = [pscustomobject]@{}
    }
  }

  $state = Read-JsonFile -Path $path
  if (-not $state.PSObject.Properties['watchedIssues'] -or $null -eq $state.watchedIssues) {
    $state | Add-Member -NotePropertyName watchedIssues -NotePropertyValue ([pscustomobject]@{}) -Force
  }

  return $state
}

function Save-PaperclipBridgeState {
  param([Parameter(Mandatory = $true)]$State)

  if (-not $State.PSObject.Properties['watchedIssues'] -or $null -eq $State.watchedIssues) {
    $State | Add-Member -NotePropertyName watchedIssues -NotePropertyValue ([pscustomobject]@{}) -Force
  }

  Write-JsonFile -Path (Get-PaperclipBridgeStatePath) -InputObject $State
}

function Get-PaperclipIssueUrl {
  param(
    [Parameter(Mandatory = $true)]$Issue,
    [Parameter()][AllowNull()]$Config = $null
  )

  $bridgeConfig = if ($null -ne $Config) { $Config } else { Get-PaperclipBridgeConfig }
  $uiBaseUrl = [string]$bridgeConfig.uiBaseUrl
  $issuePrefix = [string]$bridgeConfig.companyIssuePrefix
  $identifier = [string]$Issue.identifier

  if ([string]::IsNullOrWhiteSpace($uiBaseUrl) -or [string]::IsNullOrWhiteSpace($issuePrefix) -or [string]::IsNullOrWhiteSpace($identifier)) {
    return $null
  }

  return ($uiBaseUrl.TrimEnd('/') + "/$issuePrefix/issues/$identifier")
}

function Send-TelegramBotMessage {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [Parameter()][string]$ChatId,
    [Parameter()][AllowNull()][string]$TopicId
  )

  $cfg = Get-OpenClawConfig
  $token = $cfg.channels.telegram.botToken
  if ([string]::IsNullOrWhiteSpace([string]$token)) {
    throw "OpenClaw Telegram bot token is missing."
  }

  $bridgeConfig = Get-PaperclipBridgeConfig
  $resolvedChatId = if (-not [string]::IsNullOrWhiteSpace([string]$ChatId)) { [string]$ChatId } else { [string]$bridgeConfig.defaultChatId }
  $resolvedTopicId = if (-not [string]::IsNullOrWhiteSpace([string]$TopicId)) { [string]$TopicId } else { [string]$bridgeConfig.defaultTopicId }

  if ([string]::IsNullOrWhiteSpace($resolvedChatId)) {
    throw "Telegram chat id is not configured."
  }

  $body = @{
    chat_id = $resolvedChatId
    text = $Message
  }

  if (-not [string]::IsNullOrWhiteSpace($resolvedTopicId)) {
    $body.message_thread_id = $resolvedTopicId
  }

  Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$token/sendMessage" -Body $body | Out-Null
}

function Invoke-PaperclipApi {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('GET','POST','PATCH','DELETE')][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter()]$Body
  )

  $cfg = Get-PaperclipBridgeConfig
  $baseUrl = [string]$cfg.apiBaseUrl
  if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    throw "Paperclip apiBaseUrl is missing from bridge config."
  }

  $uri = $baseUrl.TrimEnd('/') + "/" + $Path.TrimStart('/')
  $params = @{
    Method = $Method
    Uri = $uri
  }

  if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
    $params.ContentType = 'application/json'
    $params.Body = ($Body | ConvertTo-Json -Depth 20)
  }

  Invoke-RestMethod @params
}

function Get-PaperclipLatestComment {
  param([Parameter(Mandatory = $true)][string]$IssueId)

  $commentsResponse = Invoke-PaperclipApi -Method GET -Path "issues/$IssueId/comments"
  $commentItems = if ($commentsResponse -and $commentsResponse.PSObject.Properties['value']) {
    $commentsResponse.value
  } else {
    $commentsResponse
  }

  $comments = ConvertTo-NormalizedArray $commentItems
  if ($comments.Count -eq 0) {
    return $null
  }

  return $comments |
    Sort-Object {
      if ($_.PSObject.Properties['createdAt']) {
        [datetime]$_.createdAt
      } else {
        Get-Date '1900-01-01'
      }
    } |
    Select-Object -Last 1
}
function Get-TaskManifest {
  param([Parameter(Mandatory = $true)][string]$TaskId)
  Read-JsonFile -Path (Get-TaskManifestPath $TaskId)
}

function Save-TaskManifest {
  param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)]$Manifest
  )
  Write-JsonFile -Path (Get-TaskManifestPath $TaskId) -InputObject $Manifest
}

function Update-TaskManifest {
  param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][scriptblock]$Update
  )

  $manifest = Get-TaskManifest -TaskId $TaskId
  & $Update $manifest
  $manifest.updatedAt = Get-Timestamp
  Save-TaskManifest -TaskId $TaskId -Manifest $manifest
  $manifest
}

function Get-AvailableBackend {
  $config = Get-AgentRuntimeConfig
  $tmuxReady = $false
  try {
    $wslCheck = & wsl.exe sh -lc "command -v tmux >/dev/null 2>&1 && command -v pwsh >/dev/null 2>&1 && printf ok" 2>$null
    if ($LASTEXITCODE -eq 0 -and $wslCheck -match "ok") {
      $tmuxReady = $true
    }
  } catch {
    $tmuxReady = $false
  }

  if ($config.preferredBackend -eq "tmux" -and $tmuxReady) {
    return "tmux"
  }

  return $config.fallbackBackend
}

function Get-AgentPrompt {
  param([Parameter(Mandatory = $true)]$Manifest)

  $prd = Get-Content -LiteralPath $Manifest.prdPath -Raw
  $checklist = Get-Content -LiteralPath $Manifest.checklistPath -Raw
  $requiredFilesText = if ($Manifest.validation.requiredFiles.Count -gt 0) {
    ($Manifest.validation.requiredFiles | ForEach-Object { "- $_" }) -join "`n"
  } else {
    "- none"
  }

  @"
You are running a persistent coding task for Felix.

Task ID: $($Manifest.id)
Title: $($Manifest.title)
Working directory: $($Manifest.workdir)

Read this PRD and execute it fully:

$prd

Checklist JSON that must be updated in place as work is completed:

$checklist

Rules:
- Work only inside the declared working directory unless the task explicitly says otherwise.
- Update checklist.json with status=`"done`" and evidence for completed required items.
- Write a concise final summary to completion.md.
- If you finish, ensure all required checklist items are done.
- If blocked, write the blocker into completion.md and leave incomplete items as pending.
- Do not narrate intentions as completion.

Required files that must exist before the task can validate:
$requiredFilesText
"@
}

function Get-TaskLauncherScript {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $manifest = Get-TaskManifest -TaskId $TaskId
  if ($manifest.PSObject.Properties['launcherScriptPath'] -and -not [string]::IsNullOrWhiteSpace([string]$manifest.launcherScriptPath)) {
    return [string]$manifest.launcherScriptPath
  }

  return (Join-Path (Get-AgentRuntimeRoot) "scripts\Invoke-AgentLoop.ps1")
}

function Start-DetachedAgentProcess {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $scriptPath = Get-TaskLauncherScript -TaskId $TaskId
  $logDir = Get-LogsPath -TaskId $TaskId
  if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }

  $stdout = Join-Path $logDir "runner.stdout.log"
  $stderr = Join-Path $logDir "runner.stderr.log"
  $command = "& '$scriptPath' -TaskId '$TaskId'"

  $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
  $proc = Start-Process -FilePath $psExe `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) `
    -WorkingDirectory $((Get-TaskManifest -TaskId $TaskId).workdir) `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -PassThru

  return $proc
}

function Convert-WindowsPathToWslPath {
  param([Parameter(Mandatory = $true)][string]$WindowsPath)

  $normalized = $WindowsPath -replace '\\', '/'
  $drive = $normalized.Substring(0,1).ToLower()
  return "/mnt/$drive" + $normalized.Substring(2)
}

function Start-TmuxAgentProcess {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $sessionName = "felix-$TaskId"
  $loopScript = Get-TaskLauncherScript -TaskId $TaskId
  $wslLoop = Convert-WindowsPathToWslPath -WindowsPath $loopScript
  $command = "pwsh -NoProfile -File '$wslLoop' -TaskId '$TaskId'"
  $tmuxCommand = "tmux new-session -d -s '$sessionName' `"$command`""

  # Kill any stale session with the same name before creating a new one
  & wsl.exe sh -lc "tmux kill-session -t '$sessionName' 2>/dev/null || true" 2>$null
  & wsl.exe sh -lc $tmuxCommand 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to start tmux session for task $TaskId"
  }

  return @{
    SessionName = $sessionName
    ProcessId = $null
  }
}

function Get-RecentTasks {
  Ensure-AgentRuntimeLayout
  Get-ChildItem -LiteralPath (Get-TaskRoot) -Directory | Sort-Object LastWriteTime -Descending
}

function Test-DetachedProcessAlive {
  param([AllowNull()][object]$ProcessId)

  if ($null -eq $ProcessId -or [string]::IsNullOrWhiteSpace([string]$ProcessId)) {
    return $false
  }

  $taskPid = 0
  if (-not [int]::TryParse([string]$ProcessId, [ref]$taskPid)) {
    return $false
  }

  return [bool](Get-Process -Id $taskPid -ErrorAction SilentlyContinue)
}

function Test-TmuxSessionAlive {
  param([AllowNull()][string]$SessionName)

  if ([string]::IsNullOrWhiteSpace($SessionName)) {
    return $false
  }

  try {
    & wsl.exe sh -lc "tmux has-session -t '$SessionName'" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Get-ChecklistSummary {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $manifest = Get-TaskManifest -TaskId $TaskId
  $checklist = Read-JsonFile -Path $manifest.checklistPath
  $requiredItems = @($checklist | Where-Object { $_.required })
  $doneItems = @($requiredItems | Where-Object { $_.status -eq "done" })

  [pscustomobject]@{
    totalRequired = $requiredItems.Count
    completedRequired = $doneItems.Count
    pendingRequired = ($requiredItems.Count - $doneItems.Count)
    items = $checklist
  }
}

function Get-TaskLastActivity {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $manifest = Get-TaskManifest -TaskId $TaskId
  $candidates = @()

  if ($manifest.updatedAt) {
    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse([string]$manifest.updatedAt, [ref]$parsed)) {
      $candidates += $parsed.UtcDateTime
    }
  }

  if (Test-Path -LiteralPath $manifest.logDir) {
    $recentLog = Get-ChildItem -LiteralPath $manifest.logDir -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTimeUtc -Descending |
      Select-Object -First 1
    if ($recentLog) {
      $candidates += $recentLog.LastWriteTimeUtc
    }
  }

  if ($candidates.Count -eq 0) {
    return $null
  }

  return ($candidates | Sort-Object -Descending | Select-Object -First 1)
}

function Get-TaskOutputSnapshot {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $manifest = Get-TaskManifest -TaskId $TaskId
  $result = [ordered]@{
    completionHasContent = $false
    completionPreview = $null
    lastCompletionWriteUtc = $null
    checklistHasEvidence = $false
    checklistDoneCount = 0
    checklistEvidenceCount = 0
    lastChecklistWriteUtc = $null
    lastLogWriteUtc = $null
    logFileCount = 0
  }

  if (Test-Path -LiteralPath $manifest.completionPath) {
    $completionInfo = Get-Item -LiteralPath $manifest.completionPath -ErrorAction SilentlyContinue
    if ($completionInfo) {
      $result.lastCompletionWriteUtc = $completionInfo.LastWriteTimeUtc.ToString('o')
    }
    $completionContent = (Get-Content -LiteralPath $manifest.completionPath -Raw -ErrorAction SilentlyContinue)
    if (-not [string]::IsNullOrWhiteSpace($completionContent)) {
      $trimmed = $completionContent.Trim()
      if ($trimmed -and $trimmed -notmatch '^# Completion\s+Pending\.?$' -and $trimmed -ne 'Pending.') {
        $result.completionHasContent = $true
        $result.completionPreview = ($trimmed -replace '\s+', ' ').Substring(0, [Math]::Min(160, ($trimmed -replace '\s+', ' ').Length))
      }
    }
  }

  if (Test-Path -LiteralPath $manifest.checklistPath) {
    $checklistInfo = Get-Item -LiteralPath $manifest.checklistPath -ErrorAction SilentlyContinue
    if ($checklistInfo) {
      $result.lastChecklistWriteUtc = $checklistInfo.LastWriteTimeUtc.ToString('o')
    }
    $items = Read-JsonFile -Path $manifest.checklistPath
    $done = @($items | Where-Object { $_.status -eq 'done' })
    $withEvidence = @($items | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.evidence) })
    $result.checklistDoneCount = $done.Count
    $result.checklistEvidenceCount = $withEvidence.Count
    $result.checklistHasEvidence = ($withEvidence.Count -gt 0)
  }

  if (Test-Path -LiteralPath $manifest.logDir) {
    $logs = Get-ChildItem -LiteralPath $manifest.logDir -File -ErrorAction SilentlyContinue
    $result.logFileCount = @($logs).Count
    $recentLog = $logs | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($recentLog) {
      $result.lastLogWriteUtc = $recentLog.LastWriteTimeUtc.ToString('o')
    }
  }

  [pscustomobject]$result
}

function Get-TaskHealth {
  param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [int]$IdleMinutes = 15
  )

  $manifest = Get-TaskManifest -TaskId $TaskId
  $checklist = Get-ChecklistSummary -TaskId $TaskId
  $lastActivity = Get-TaskLastActivity -TaskId $TaskId
  $snapshot = Get-TaskOutputSnapshot -TaskId $TaskId
  $nowUtc = (Get-Date).ToUniversalTime()
  $idleCutoff = $nowUtc.AddMinutes(-1 * $IdleMinutes)

  $liveVerified = $false
  if ($manifest.backend -eq 'tmux') {
    $liveVerified = Test-TmuxSessionAlive -SessionName $manifest.sessionName
  } elseif ($manifest.backend -eq 'detached-pwsh') {
    $liveVerified = Test-DetachedProcessAlive -ProcessId $manifest.processId
  }

  $hasArtifactProgress = ($snapshot.completionHasContent -or $snapshot.checklistHasEvidence -or $checklist.completedRequired -gt 0)
  $hasRecentActivity = ($lastActivity -and $lastActivity -ge $idleCutoff)

  $runtimeState = 'unknown'
  switch ([string]$manifest.status) {
    'completed' { $runtimeState = 'completed' }
    'failed' { $runtimeState = 'failed' }
    default {
      if (-not $liveVerified) {
        $runtimeState = 'stalled'
      } elseif ($hasRecentActivity) {
        $runtimeState = 'running-live'
      } elseif ($hasArtifactProgress) {
        $runtimeState = 'running-idle'
      } else {
        $runtimeState = 'running-idle'
      }
    }
  }

  $stallReason = $null
  if ($runtimeState -eq 'stalled') {
    if ($manifest.backend -eq 'tmux') {
      $stallReason = 'missing-tmux-session'
    } elseif ($manifest.backend -eq 'detached-pwsh') {
      $stallReason = 'missing-process'
    } else {
      $stallReason = 'not-live'
    }
  } elseif ($runtimeState -eq 'running-idle' -and -not $hasRecentActivity) {
    $stallReason = 'idle-no-recent-output'
  }

  [pscustomobject]@{
    liveVerified = $liveVerified
    runtimeState = $runtimeState
    hasRecentActivity = $hasRecentActivity
    hasArtifactProgress = $hasArtifactProgress
    stallReason = $stallReason
    output = $snapshot
    lastActivityUtc = if ($lastActivity) { $lastActivity.ToString('o') } else { $null }
    idleMinutes = if ($lastActivity) { [Math]::Round(($nowUtc - $lastActivity).TotalMinutes, 1) } else { $null }
  }
}

function Get-TaskSummary {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $manifest = Get-TaskManifest -TaskId $TaskId
  $checklist = Get-ChecklistSummary -TaskId $TaskId
  $health = Get-TaskHealth -TaskId $TaskId

  [pscustomobject]@{
    taskId = $manifest.id
    title = $manifest.title
    status = $manifest.status
    backend = $manifest.backend
    attempt = $manifest.attempt
    maxAttempts = $manifest.maxAttempts
    completedRequired = $checklist.completedRequired
    totalRequired = $checklist.totalRequired
    pendingRequired = $checklist.pendingRequired
    processId = $manifest.processId
    sessionName = $manifest.sessionName
    updatedAt = $manifest.updatedAt
    lastActivityUtc = $health.lastActivityUtc
    workdir = $manifest.workdir
    liveVerified = $health.liveVerified
    runtimeState = $health.runtimeState
    hasRecentActivity = $health.hasRecentActivity
    hasArtifactProgress = $health.hasArtifactProgress
    stallReason = $health.stallReason
    idleMinutes = $health.idleMinutes
    completionHasContent = $health.output.completionHasContent
    completionPreview = $health.output.completionPreview
    checklistHasEvidence = $health.output.checklistHasEvidence
    checklistEvidenceCount = $health.output.checklistEvidenceCount
    lastLogWriteUtc = $health.output.lastLogWriteUtc
  }
}

function New-PaperclipDelegatedIssue {
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
  }
}

Export-ModuleMember -Function *-*




