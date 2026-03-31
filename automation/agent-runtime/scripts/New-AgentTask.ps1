param(
  [Parameter(Mandatory = $true)][string]$Title,
  [Parameter(Mandatory = $true)][string]$Workdir,
  [string]$Summary = "",
  [string[]]$RequiredFiles = @(),
  [int]$MaxAttempts = 3,
  [string]$Model = "gpt-5.4"
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

Ensure-AgentRuntimeLayout

$slug = ($Title.ToLower() -replace "[^a-z0-9]+", "-").Trim("-")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$taskId = "$timestamp-$slug"
$taskDir = Get-TaskPath -TaskId $taskId
$logsDir = Get-LogsPath -TaskId $taskId

New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

$prdTemplate = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\prd-template.md"
$checklistTemplate = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\checklist.template.json"

$prdPath = Get-PRDPath -TaskId $taskId
$checklistPath = Get-ChecklistPath -TaskId $taskId
$completionPath = Get-CompletionPath -TaskId $taskId

$prdContent = Get-Content -LiteralPath $prdTemplate -Raw
if ($Summary) {
  $prdContent = $prdContent -replace "Describe the outcome in one paragraph\.", $Summary
}
Set-Content -LiteralPath $prdPath -Value $prdContent
Copy-Item -LiteralPath $checklistTemplate -Destination $checklistPath -Force
Set-Content -LiteralPath $completionPath -Value "# Completion`n`nPending."

$manifest = [ordered]@{
  id = $taskId
  title = $Title
  createdAt = Get-Timestamp
  updatedAt = Get-Timestamp
  recoveredAt = $null
  lastChecklistUpdateAt = $null
  workdir = $Workdir
  status = "pending"
  backend = Get-AvailableBackend
  model = $Model
  maxAttempts = $MaxAttempts
  attempt = 0
  summary = $Summary
  prdPath = $prdPath
  checklistPath = $checklistPath
  completionPath = $completionPath
  taskDir = $taskDir
  logDir = $logsDir
  processId = $null
  sessionName = $null
  lastMessagePath = (Join-Path $logsDir "last-message.txt")
  completionHooks = @("log", "telegram")
  validation = @{
    requiredFiles = $RequiredFiles
  }
}

Save-TaskManifest -TaskId $taskId -Manifest $manifest

Write-Output "TASK_ID=$taskId"
Write-Output "TASK_DIR=$taskDir"
Write-Output "PRD=$prdPath"
Write-Output "CHECKLIST=$checklistPath"
