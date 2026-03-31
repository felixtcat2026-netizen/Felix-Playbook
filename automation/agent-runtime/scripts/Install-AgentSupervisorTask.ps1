param(
  [string]$TaskName = "Felix Agent Supervisor"
)

$watchScript = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\Watch-AgentTasks.ps1"
$action = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$watchScript`" -Recover"

schtasks /Create /TN $TaskName /SC ONLOGON /TR $action /F | Out-Null
schtasks /Create /TN "$TaskName (15m)" /SC MINUTE /MO 15 /TR $action /F | Out-Null

Write-Output "SUPERVISOR_TASKS_CREATED=$TaskName"
Write-Output "SCRIPT=$watchScript"
