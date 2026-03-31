param(
  [Parameter(Mandatory = $true)][string[]]$TaskIds
)

$results = foreach ($taskId in $TaskIds) {
  & (Join-Path $PSScriptRoot "Start-AgentTask.ps1") -TaskId $taskId
}

$results
