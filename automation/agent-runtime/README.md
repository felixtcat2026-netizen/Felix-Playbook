# Agent Runtime

This runtime gives Felix a practical orchestration layer for longer-running coding work on this
Windows machine.

It is designed around six core capabilities:

- persistent task state that survives reboots
- Codex CLI orchestration
- Ralph-style retry loops that restart failed tasks
- completion hooks for notifications and logging
- parallel coding agents
- PRD plus checklist task tracking

## What You Get

This setup now gives you the patterns you asked for:

- Persistent tmux sessions when WSL + tmux are available
- Windows detached-session fallback that survives chat interruptions today
- Ralph retry loops via `Invoke-AgentLoop.ps1`
- PRD-based tasks with checklist validation via `prd.md` + `checklist.json`
- Parallel launches with `Start-AgentBatch.ps1`
- Completion hooks that write `done.json`, append to `logs/completion-events.jsonl`, and optionally notify Telegram
- Recovery loop via `Watch-AgentTasks.ps1` for missing or stale workers
- Task dashboard via `Get-AgentTasks.ps1`

## How It Works

Each task lives in `tasks/<task-id>/` with:

- `task.json`: task manifest and runtime state
- `prd.md`: implementation brief
- `checklist.json`: validation checklist
- `completion.md`: final completion summary written by the agent
- `done.json`: completion sentinel written by hooks
- `logs/`: Codex JSONL, stdout, stderr, and runner logs

The runtime launches a detached Codex job per task, monitors it, validates completion, retries if
needed, and fires completion hooks when work is actually done.

## Backends

The runtime now prefers and uses `tmux` on this machine because WSL + tmux + `pwsh` are installed and verified working.`r`n`r`nThe detached PowerShell backend remains available only as a fallback if tmux is unavailable or broken.

## Main Scripts

- `scripts/New-AgentTask.ps1`
  Create a new PRD-driven task folder.
- `scripts/Start-AgentTask.ps1`
  Launch one detached task runner.
- `scripts/Start-AgentBatch.ps1`
  Launch multiple tasks in parallel.
- `scripts/Invoke-AgentLoop.ps1`
  Ralph loop: run Codex, validate, retry, complete.
- `scripts/Test-AgentTask.ps1`
  Validate checklist items and required files.
- `scripts/Update-AgentChecklist.ps1`
  Mark checklist items done/blocked with evidence.
- `scripts/Get-AgentTasks.ps1`
  Show task status, attempts, activity, and checklist progress.
- `scripts/Watch-AgentTasks.ps1`
  Monitor and auto-restart stalled or interrupted tasks.
- `scripts/Invoke-CompletionHook.ps1`
  Record completion and notify via Telegram/custom hook/log files.
- `scripts/Install-AgentSupervisorTask.ps1`
  Register a Windows Scheduled Task that keeps the watcher running on logon and every 15 minutes.

## Quick Start

Create a task:

```powershell
.\automation\agent-runtime\scripts\New-AgentTask.ps1 `
  -Title "Implement onboarding page polish" `
  -Workdir "C:\labs\Felix Playbook" `
  -Summary "Upgrade the onboarding page based on the PRD."
```

Start it:

```powershell
.\automation\agent-runtime\scripts\Start-AgentTask.ps1 -TaskId <task-id>
```

Check status:

```powershell
.\automation\agent-runtime\scripts\Get-AgentTasks.ps1
```

Run the monitor/recovery loop:

```powershell
.\automation\agent-runtime\scripts\Watch-AgentTasks.ps1 -Recover
```

Install the supervisor task:

```powershell
.\automation\agent-runtime\scripts\Install-AgentSupervisorTask.ps1
```

## Notification Default

If the local OpenClaw Telegram config is present, completion hooks will try to notify:

- group: `Headquarters` (`-1003834402915`)
- topic: `#Ops` (`86`)

You can override that later in `state/runtime-config.json`.

Lifecycle notices now post to Telegram `#Ops` for:

- task started
- task restarted
- task failed
- task completed
- task needs attention

You can also send a compact runtime summary to Telegram on demand:

```powershell
.\automation\agent-runtime\scripts\Send-AgentOpsSummary.ps1
```

Or print the same summary locally:

```powershell
.\automation\agent-runtime\scripts\Get-AgentOpsSummary.ps1
```




## Heartbeat Cadence

There are currently two different heartbeat-style cadences in this setup:

- OpenClaw internal runtime heartbeat: 30m (main) from openclaw status --deep
- Felix hourly heartbeat worker cron: every 1h via hourly-heartbeat-worker

When reporting ops status, treat these as separate signals rather than collapsing them into one cadence line.


