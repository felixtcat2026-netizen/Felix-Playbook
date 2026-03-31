param()

$root = Split-Path -Parent $PSScriptRoot
$generate = Join-Path $PSScriptRoot 'Generate-AgentDashboard.ps1'
$dashboard = Join-Path $root 'dashboard\index.html'

& $generate | Out-Null
Write-Output $dashboard
