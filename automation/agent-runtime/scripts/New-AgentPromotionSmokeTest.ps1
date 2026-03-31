param(
  [string]$Title = 'promotion smoke test',
  [string]$Workdir = 'C:\labs\Felix Playbook',
  [string]$Summary = 'Verify detached fallback can be promoted back into tmux by the watcher.'
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'runtime\AgentRuntime.psm1'
Import-Module $modulePath -Force

$taskOutput = & (Join-Path $PSScriptRoot 'New-AgentTask.ps1') -Title $Title -Workdir $Workdir -Summary $Summary
$taskId = (($taskOutput | Where-Object { $_ -like 'TASK_ID=*' }) -replace '^TASK_ID=', '')
if (-not $taskId) {
  throw 'Failed to create smoke test task.'
}

$smokeScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Invoke-AgentSmokeWorker.ps1'
$manifest = Update-TaskManifest -TaskId $taskId -Update {
  param($m)
  if ($m.PSObject.Properties['launcherScriptPath']) {
    $m.launcherScriptPath = $smokeScript
  } else {
    $m | Add-Member -NotePropertyName launcherScriptPath -NotePropertyValue $smokeScript -Force
  }
}

$proc = Start-DetachedAgentProcess -TaskId $taskId
$manifest = Update-TaskManifest -TaskId $taskId -Update {
  param($m)
  $m.backend = 'detached-pwsh'
  $m.processId = $proc.Id
  $m.sessionName = $null
  $m.status = 'running'
}

Write-Output "TASK_ID=$taskId"
Write-Output "BACKEND=detached-pwsh"
Write-Output "PID=$($proc.Id)"
Write-Output "PROMOTION_READY=run .\automation\agent-runtime\scripts\Watch-AgentTasks.ps1 -Recover once tmux is healthy"
