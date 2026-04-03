param(
  [string]$WorkspaceRoot = "C:\Users\Damian\.openclaw\workspace"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$sourceRoot = Join-Path $repoRoot "v4-agent-upgrade-kit\configs"
$files = @("SOUL.md", "AGENTS.md", "TOOLS.md")

if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
  throw "Workspace root not found: $WorkspaceRoot"
}

foreach ($name in $files) {
  $source = Join-Path $sourceRoot $name
  $dest = Join-Path $WorkspaceRoot $name

  if (-not (Test-Path -LiteralPath $source)) {
    throw "Source file missing: $source"
  }

  if (Test-Path -LiteralPath $dest) {
    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    Copy-Item -LiteralPath $dest -Destination ($dest + ".bak-" + $timestamp) -Force
  }

  Copy-Item -LiteralPath $source -Destination $dest -Force
}

Write-Host "Synced Felix workspace docs from repo:"
$files | ForEach-Object { Write-Host ("- " + (Join-Path $WorkspaceRoot $_)) }
