param(
  [string]$OutputPath = ""
)

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\AgentRuntime.psm1"
Import-Module $modulePath -Force

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
  $OutputPath = Join-Path $root "dashboard\index.html"
}

$tasks = foreach ($dir in Get-RecentTasks) {
  $taskId = $dir.Name
  $manifest = Get-TaskManifest -TaskId $taskId
  $checklistSummary = Get-ChecklistSummary -TaskId $taskId
  $completionText = if (Test-Path -LiteralPath $manifest.completionPath) {
    (Get-Content -LiteralPath $manifest.completionPath -Raw).Trim()
  } else {
    ""
  }

  [pscustomobject]@{
    taskId = $manifest.id
    title = $manifest.title
    status = [string]$manifest.status
    backend = [string]$manifest.backend
    sessionName = [string]$manifest.sessionName
    processId = if ($null -ne $manifest.processId) { [string]$manifest.processId } else { "" }
    attempt = [int]$manifest.attempt
    maxAttempts = [int]$manifest.maxAttempts
    completedRequired = [int]$checklistSummary.completedRequired
    totalRequired = [int]$checklistSummary.totalRequired
    pendingRequired = [int]$checklistSummary.pendingRequired
    updatedAt = [string]$manifest.updatedAt
    workdir = [string]$manifest.workdir
    taskDir = [string]$manifest.taskDir
    completionPath = [string]$manifest.completionPath
    checklistItems = @($checklistSummary.items)
    completionPreview = if ($completionText.Length -gt 220) { $completionText.Substring(0,220) + "..." } else { $completionText }
  }
}

$total = @($tasks).Count
$running = @($tasks | Where-Object { $_.status -eq 'running' }).Count
$completed = @($tasks | Where-Object { $_.status -eq 'completed' }).Count
$needsAttention = @($tasks | Where-Object { $_.status -in @('failed','retrying','pending') }).Count
$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"

function Convert-TextToHtml([string]$value) {
  if ($null -eq $value) { return "" }
  return [System.Net.WebUtility]::HtmlEncode($value)
}

$cards = foreach ($task in $tasks) {
  $statusClass = switch ($task.status) {
    'running' { 'running' }
    'completed' { 'completed' }
    'failed' { 'failed' }
    'retrying' { 'retrying' }
    'pending' { 'pending' }
    default { 'unknown' }
  }

  $checklistHtml = foreach ($item in $task.checklistItems) {
    $itemClass = switch ([string]$item.status) {
      'done' { 'done' }
      'blocked' { 'blocked' }
      default { 'pending' }
    }
    "<li class='checklist-item $itemClass'><span class='check-state'>$([System.Net.WebUtility]::HtmlEncode([string]$item.status))</span><span class='check-title'>$([System.Net.WebUtility]::HtmlEncode([string]$item.title))</span><span class='check-evidence'>$([System.Net.WebUtility]::HtmlEncode([string]$item.evidence))</span></li>"
  }

  @"
<section class='task-card $statusClass'>
  <div class='task-head'>
    <div>
      <h2>$([System.Net.WebUtility]::HtmlEncode($task.title))</h2>
      <p class='task-id'>$([System.Net.WebUtility]::HtmlEncode($task.taskId))</p>
    </div>
    <span class='pill $statusClass'>$([System.Net.WebUtility]::HtmlEncode($task.status))</span>
  </div>
  <div class='task-grid'>
    <div><span class='label'>Backend</span><span class='value'>$([System.Net.WebUtility]::HtmlEncode($task.backend))</span></div>
    <div><span class='label'>Session</span><span class='value'>$([System.Net.WebUtility]::HtmlEncode(($task.sessionName, $task.processId | Where-Object { $_ }) -join ' / '))</span></div>
    <div><span class='label'>Attempts</span><span class='value'>$($task.attempt) / $($task.maxAttempts)</span></div>
    <div><span class='label'>Checklist</span><span class='value'>$($task.completedRequired) of $($task.totalRequired) required complete</span></div>
    <div><span class='label'>Updated</span><span class='value'>$([System.Net.WebUtility]::HtmlEncode($task.updatedAt))</span></div>
    <div><span class='label'>Workdir</span><span class='value path'>$([System.Net.WebUtility]::HtmlEncode($task.workdir))</span></div>
  </div>
  <details>
    <summary>Checklist details</summary>
    <ul class='checklist'>
      $($checklistHtml -join "`n")
    </ul>
  </details>
  <details>
    <summary>Completion preview</summary>
    <pre>$([System.Net.WebUtility]::HtmlEncode($task.completionPreview))</pre>
  </details>
  <div class='paths'>
    <div><span class='label'>Task folder</span><span class='value path'>$([System.Net.WebUtility]::HtmlEncode($task.taskDir))</span></div>
    <div><span class='label'>Completion file</span><span class='value path'>$([System.Net.WebUtility]::HtmlEncode($task.completionPath))</span></div>
  </div>
</section>
"@
}

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="30">
  <title>Felix Runtime Dashboard</title>
  <style>
    :root {
      --bg: #0b1020;
      --panel: #121a33;
      --panel-2: #182342;
      --line: #2a3963;
      --text: #eef3ff;
      --muted: #9fb0d6;
      --blue: #72c5ff;
      --green: #69e5a8;
      --amber: #ffd166;
      --red: #ff7b7b;
      --violet: #b8a7ff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Segoe UI, Inter, system-ui, sans-serif;
      background: radial-gradient(circle at top, #18254b 0%, var(--bg) 48%);
      color: var(--text);
      line-height: 1.45;
    }
    .wrap {
      width: min(1200px, calc(100% - 32px));
      margin: 32px auto 48px;
    }
    .hero {
      display: grid;
      grid-template-columns: 1.4fr 1fr;
      gap: 18px;
      align-items: stretch;
      margin-bottom: 22px;
    }
    .hero-card, .stat-card, .task-card {
      background: linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
      border: 1px solid var(--line);
      border-radius: 20px;
      box-shadow: 0 22px 60px rgba(0,0,0,0.25);
    }
    .hero-card {
      padding: 24px;
    }
    h1 {
      margin: 0 0 10px;
      font-size: clamp(2rem, 4vw, 3.2rem);
      line-height: 1;
    }
    .sub {
      margin: 0;
      color: var(--muted);
      font-size: 1.05rem;
      max-width: 52rem;
    }
    .meta {
      margin-top: 16px;
      color: var(--blue);
      font-size: 0.95rem;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 16px;
    }
    .stat-card {
      padding: 18px;
    }
    .stat-label {
      display: block;
      color: var(--muted);
      font-size: 0.85rem;
      margin-bottom: 6px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }
    .stat-value {
      font-size: 2rem;
      font-weight: 700;
    }
    .grid {
      display: grid;
      gap: 18px;
    }
    .task-card {
      padding: 20px;
    }
    .task-head {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: start;
      margin-bottom: 18px;
    }
    .task-head h2 {
      margin: 0 0 6px;
      font-size: 1.3rem;
    }
    .task-id {
      margin: 0;
      color: var(--muted);
      font-family: Consolas, monospace;
      font-size: 0.92rem;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      padding: 8px 12px;
      border-radius: 999px;
      font-size: 0.84rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-weight: 700;
      border: 1px solid transparent;
    }
    .pill.running { background: rgba(114,197,255,0.15); color: var(--blue); border-color: rgba(114,197,255,0.3); }
    .pill.completed { background: rgba(105,229,168,0.15); color: var(--green); border-color: rgba(105,229,168,0.3); }
    .pill.failed { background: rgba(255,123,123,0.15); color: var(--red); border-color: rgba(255,123,123,0.3); }
    .pill.retrying, .pill.pending { background: rgba(255,209,102,0.15); color: var(--amber); border-color: rgba(255,209,102,0.3); }
    .task-grid, .paths {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 14px 18px;
      margin-bottom: 14px;
    }
    .label {
      display: block;
      color: var(--muted);
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin-bottom: 5px;
    }
    .value {
      display: block;
      font-weight: 600;
    }
    .path {
      font-family: Consolas, monospace;
      font-size: 0.88rem;
      word-break: break-all;
    }
    details {
      margin-top: 12px;
      border-top: 1px solid rgba(255,255,255,0.06);
      padding-top: 12px;
    }
    summary {
      cursor: pointer;
      color: var(--blue);
      font-weight: 600;
      margin-bottom: 10px;
    }
    .checklist {
      list-style: none;
      margin: 10px 0 0;
      padding: 0;
      display: grid;
      gap: 8px;
    }
    .checklist-item {
      display: grid;
      grid-template-columns: 90px 1fr 1fr;
      gap: 10px;
      padding: 10px 12px;
      background: rgba(255,255,255,0.03);
      border-radius: 12px;
      border: 1px solid rgba(255,255,255,0.05);
    }
    .check-state {
      text-transform: uppercase;
      font-size: 0.78rem;
      letter-spacing: 0.08em;
      color: var(--muted);
    }
    .checklist-item.done .check-state { color: var(--green); }
    .checklist-item.blocked .check-state { color: var(--red); }
    .check-title { font-weight: 600; }
    .check-evidence { color: var(--muted); }
    pre {
      white-space: pre-wrap;
      margin: 10px 0 0;
      padding: 14px;
      border-radius: 12px;
      background: rgba(0,0,0,0.25);
      border: 1px solid rgba(255,255,255,0.06);
      color: #dce6ff;
      font-family: Consolas, monospace;
      font-size: 0.88rem;
    }
    .task-card.running { border-color: rgba(114,197,255,0.25); }
    .task-card.completed { border-color: rgba(105,229,168,0.25); }
    .task-card.failed { border-color: rgba(255,123,123,0.25); }
    .task-card.pending, .task-card.retrying { border-color: rgba(255,209,102,0.25); }
    @media (max-width: 900px) {
      .hero, .task-grid, .paths, .stats { grid-template-columns: 1fr; }
      .checklist-item { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <section class="hero">
      <article class="hero-card">
        <h1>Felix Runtime Dashboard</h1>
        <p class="sub">Live local view of managed coding tasks, PRD checklist progress, backend selection, and recovery state. Refreshes every 30 seconds.</p>
        <p class="meta">Generated: $generatedAt</p>
      </article>
      <div class="stats">
        <article class="stat-card"><span class="stat-label">Total Tasks</span><span class="stat-value">$total</span></article>
        <article class="stat-card"><span class="stat-label">Running</span><span class="stat-value">$running</span></article>
        <article class="stat-card"><span class="stat-label">Completed</span><span class="stat-value">$completed</span></article>
        <article class="stat-card"><span class="stat-label">Need Attention</span><span class="stat-value">$needsAttention</span></article>
      </div>
    </section>
    <section class="grid">
      $($cards -join "`n")
    </section>
  </div>
</body>
</html>
"@

$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Set-Content -LiteralPath $OutputPath -Value $html -Encoding UTF8
Write-Output "DASHBOARD=$OutputPath"
