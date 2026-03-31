param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

function Set-ManifestValue {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)][string]$Name,
    $Value
  )

  if ($Manifest.PSObject.Properties[$Name]) {
    $Manifest.$Name = $Value
  } else {
    $Manifest | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
  }
}

$manifest = Get-TaskManifest -TaskId $TaskId
$runnerLog = Join-Path $manifest.logDir "loop.log"

for ($attempt = $manifest.attempt + 1; $attempt -le $manifest.maxAttempts; $attempt++) {
  $manifest = Update-TaskManifest -TaskId $TaskId -Update {
    param($m)
    $timestamp = Get-Timestamp
    $m.attempt = $attempt
    $m.status = "running"
    if ($m.PSObject.Properties['lastAttemptAt']) {
      $m.lastAttemptAt = $timestamp
    } else {
      $m | Add-Member -NotePropertyName lastAttemptAt -NotePropertyValue $timestamp -Force
    }
  }

  "[$(Get-Timestamp)] attempt=$attempt starting" | Add-Content -LiteralPath $runnerLog

  $prompt = Get-AgentPrompt -Manifest $manifest
  $jsonLog = Join-Path $manifest.logDir ("codex-attempt-{0:D2}.jsonl" -f $attempt)
  $stdoutLog = Join-Path $manifest.logDir ("codex-attempt-{0:D2}.stdout.log" -f $attempt)
  $stderrLog = Join-Path $manifest.logDir ("codex-attempt-{0:D2}.stderr.log" -f $attempt)

  try {
    $prompt | & codex exec `
      --json `
      --skip-git-repo-check `
      -C $manifest.workdir `
      -m $manifest.model `
      -o $manifest.lastMessagePath `
      - | Tee-Object -FilePath $jsonLog | Out-File -LiteralPath $stdoutLog

    $codexExit = $LASTEXITCODE
  } catch {
    $_ | Out-String | Set-Content -LiteralPath $stderrLog
    $codexExit = 1
  }

  $validationJson = & (Join-Path $PSScriptRoot "Test-AgentTask.ps1") -TaskId $TaskId
  $validation = $validationJson | ConvertFrom-Json

  if ($codexExit -eq 0 -and $validation.valid) {
    $manifest = Update-TaskManifest -TaskId $TaskId -Update {
      param($m)
      $timestamp = Get-Timestamp
      $m.status = "completed"
      if ($m.PSObject.Properties['completedAt']) {
        $m.completedAt = $timestamp
      } else {
        $m | Add-Member -NotePropertyName completedAt -NotePropertyValue $timestamp -Force
      }
    }
    "[$(Get-Timestamp)] attempt=$attempt completed" | Add-Content -LiteralPath $runnerLog
    & (Join-Path $PSScriptRoot "Invoke-CompletionHook.ps1") -TaskId $TaskId | Out-Null
    exit 0
  }

  $manifest = Update-TaskManifest -TaskId $TaskId -Update {
    param($m)
    $m.status = "retrying"
    if ($m.PSObject.Properties['lastValidation']) {
      $m.lastValidation = $validation
    } else {
      $m | Add-Member -NotePropertyName lastValidation -NotePropertyValue $validation -Force
    }
  }

  "[$(Get-Timestamp)] attempt=$attempt failed validation or codex exit ($codexExit)" | Add-Content -LiteralPath $runnerLog
  Start-Sleep -Seconds ([Math]::Min(30, 5 * $attempt))
}

$manifest = Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  $timestamp = Get-Timestamp
  $m.status = "failed"
  if ($m.PSObject.Properties['failedAt']) {
    $m.failedAt = $timestamp
  } else {
    $m | Add-Member -NotePropertyName failedAt -NotePropertyValue $timestamp -Force
  }
}

"[$(Get-Timestamp)] task failed after max attempts" | Add-Content -LiteralPath $runnerLog
& (Join-Path $PSScriptRoot 'Send-AgentOpsNotice.ps1') -TaskId $TaskId -Event failed -Reason 'max-attempts-exceeded' -Extra "Attempts: $($manifest.maxAttempts)" | Out-Null
exit 1
