param(
  [string]$TaskName = 'Felix-Paperclip-Bridge-Watcher',
  [int]$EveryMinutes = 2
)

$watchScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Watch-PaperclipBridge.ps1'
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $watchScript + '" -Once'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$repeatTrigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn

try {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop | Out-Null
} catch {
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $repeatTrigger) -Description 'Watches Paperclip issues and mirrors updates back to Telegram.' -Force | Out-Null

Write-Output "PAPERCLIP_BRIDGE_TASKS_CREATED=$TaskName"
Write-Output "SCRIPT=$watchScript"
Write-Output "ARGUMENTS=$arguments"
