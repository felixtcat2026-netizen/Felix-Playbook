param()

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$tasks = foreach ($dir in Get-RecentTasks) {
  Get-TaskSummary -TaskId $dir.Name
}

$tasks | ConvertTo-Json -Depth 20
