param(
  [Parameter(Mandatory = $true)][string]$TaskId
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$manifest = Get-TaskManifest -TaskId $TaskId
$checklist = Read-JsonFile -Path $manifest.checklistPath
$missingChecklist = @()

foreach ($item in $checklist) {
  if ($item.required -and $item.status -ne "done") {
    $missingChecklist += $item.title
  }
}

$missingFiles = @()
foreach ($path in $manifest.validation.requiredFiles) {
  if (-not (Test-Path -LiteralPath $path)) {
    $missingFiles += $path
  }
}

$completionExists = Test-Path -LiteralPath $manifest.completionPath
$completionContent = if ($completionExists) { Get-Content -LiteralPath $manifest.completionPath -Raw } else { "" }

$isValid = ($missingChecklist.Count -eq 0 -and $missingFiles.Count -eq 0 -and $completionContent -notmatch "Pending\.")

$result = [ordered]@{
  taskId = $TaskId
  valid = $isValid
  missingChecklist = $missingChecklist
  missingFiles = $missingFiles
  completionPath = $manifest.completionPath
}

$result | ConvertTo-Json -Depth 20
if ($isValid) { exit 0 } else { exit 1 }
