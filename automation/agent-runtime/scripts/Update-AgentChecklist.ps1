param(
  [Parameter(Mandatory = $true)][string]$TaskId,
  [Parameter(Mandatory = $true)][string]$ChecklistItemId,
  [ValidateSet("pending","done","blocked")][string]$Status,
  [string]$Evidence = ""
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$manifest = Get-TaskManifest -TaskId $TaskId
$checklist = @(
  Read-JsonFile -Path $manifest.checklistPath
)
$item = $checklist | Where-Object { $_.id -eq $ChecklistItemId } | Select-Object -First 1
if (-not $item) {
  throw "Checklist item not found: $ChecklistItemId"
}

$item.status = $Status
$item.evidence = $Evidence
Write-JsonFile -Path $manifest.checklistPath -InputObject $checklist
Update-TaskManifest -TaskId $TaskId -Update {
  param($m)
  if ($m.PSObject.Properties.Name -notcontains 'lastChecklistUpdateAt') {
    $m | Add-Member -NotePropertyName lastChecklistUpdateAt -NotePropertyValue (Get-Timestamp) -Force
  } else {
    $m.lastChecklistUpdateAt = Get-Timestamp
  }
} | Out-Null

$checklist | ConvertTo-Json -Depth 20
