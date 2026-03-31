param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$manifest = Get-TaskManifest -TaskId $TaskId
$runnerLog = Join-Path $manifest.logDir "loop.log"

for ($attempt = $manifest.attempt + 1; $attempt -le $manifest.maxAttempts; $attempt++) {
  $manifest = Update-TaskManifest -TaskId $TaskId -Update {
    param($m)
    $m.attempt = $attempt
    $m.status = "running"
    $m.lastAttemptAt = Get-Timestamp
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
      $m.status = "completed"
      $m.completedAt = Get-Timestamp
    }
    "[$(Get-Timestamp)] attempt=$attempt completed" | Add-Content -LiteralPath $runnerLog
    & (Join-Path $PSScriptRoot "Invoke-CompletionHook.ps1") -TaskId $TaskId | Out-Null
    exit 0
  }

  $manifest = Update-TaskManifest -TaskId $TaskId -Update {
    param($m)
    $m.status = "retrying"
    $m.lastValidation = $validation
  }

  "[$(Get-Timestamp)] attempt=$attempt failed validation or codex exit ($codexExit)" | Add-Content -LiteralPath $runnerLog
  Start-Sleep -Seconds ([Math]::Min(30, 5 * $attempt))
}

$manifest = Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  $m.status = "failed"
  $m.failedAt = Get-Timestamp
}

"[$(Get-Timestamp)] task failed after max attempts" | Add-Content -LiteralPath $runnerLog
exit 1
