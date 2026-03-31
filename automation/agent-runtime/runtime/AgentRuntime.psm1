Set-StrictMode -Version Latest

function Get-AgentRuntimeRoot {
  Split-Path -Parent $PSScriptRoot
}

function Ensure-AgentRuntimeLayout {
  $root = Get-AgentRuntimeRoot
  @(
    (Join-Path $root "tasks"),
    (Join-Path $root "state"),
    (Join-Path $root "logs")
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

function Start-DetachedAgentProcess {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $scriptPath = Join-Path (Get-AgentRuntimeRoot) "scripts\Invoke-AgentLoop.ps1"
  $logDir = Get-LogsPath -TaskId $TaskId
  if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }

  $stdout = Join-Path $logDir "runner.stdout.log"
  $stderr = Join-Path $logDir "runner.stderr.log"

  $proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath, "-TaskId", $TaskId) `
    -WindowStyle Hidden `
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
  $loopScript = Join-Path (Get-AgentRuntimeRoot) "scripts\Invoke-AgentLoop.ps1"
  $wslLoop = Convert-WindowsPathToWslPath -WindowsPath $loopScript
  $command = "pwsh -NoProfile -File '$wslLoop' -TaskId '$TaskId'"
  $tmuxCommand = "tmux new-session -d -s '$sessionName' `"$command`""

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

function Get-TaskSummary {
  param([Parameter(Mandatory = $true)][string]$TaskId)

  $manifest = Get-TaskManifest -TaskId $TaskId
  $checklist = Get-ChecklistSummary -TaskId $TaskId
  $lastActivity = Get-TaskLastActivity -TaskId $TaskId

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
    lastActivityUtc = if ($lastActivity) { $lastActivity.ToString("o") } else { $null }
    workdir = $manifest.workdir
  }
}

Export-ModuleMember -Function *-*

