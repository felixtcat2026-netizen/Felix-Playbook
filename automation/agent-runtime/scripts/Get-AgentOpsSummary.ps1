param(
  [int]$Top = 10
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'runtime\AgentRuntime.psm1'
Import-Module $modulePath -Force

$tasks = Get-RecentTasks | ForEach-Object { Get-TaskSummary -TaskId $_.Name }
$config = Get-AgentRuntimeConfig

$total = @($tasks).Count
$running = @($tasks | Where-Object { $_.status -eq 'running' }).Count
$completed = @($tasks | Where-Object { $_.status -eq 'completed' }).Count
$attention = @($tasks | Where-Object { $_.status -in @('failed', 'needs-attention', 'retrying', 'pending') }).Count

$lines = @(
  'Ops summary',
  '- OpenClaw internal heartbeat: 30m (main)',
  '- Felix heartbeat worker cron: every 1h (hourly-heartbeat-worker)',
  "- Preferred runtime backend: $($config.preferredBackend)",
  "- Fallback runtime backend: $($config.fallbackBackend)",
  "- Total tasks: $total",
  "- Running: $running",
  "- Completed: $completed",
  "- Needs attention: $attention"
)

$topTasks = @(
  $tasks |
    Sort-Object @{ Expression = { $_.updatedAt }; Descending = $true } |
    Select-Object -First $Top
)

if ($topTasks.Count -gt 0) {
  $lines += ''
  $lines += 'Recent tasks'
  foreach ($task in $topTasks) {
    $details = @(
      "- $($task.taskId)",
      "status=$($task.status)",
      "backend=$($task.backend)"
    )

    if ($task.sessionName) {
      $details += "session=$($task.sessionName)"
    } elseif ($task.processId) {
      $details += "pid=$($task.processId)"
    }

    $details += "checklist=$($task.completedRequired)/$($task.totalRequired)"
    $lines += ($details -join ' | ')
  }
}

($lines -join "`n")
