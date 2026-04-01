# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Felix Playbook** is an AI Agent Orchestration & Knowledge Management System for autonomous business automation. It is not a traditional compiled application — it is a configuration and infrastructure framework combining:

- **Three-Layer Memory System** (Python): PARA knowledge graph + daily notes + tacit knowledge
- **Agent Runtime** (PowerShell): Task orchestration with retry logic, validation, and Telegram notifications
- **Integration Layer**: OpenClaw gateway → Claude/Codex CLI → task execution → Telegram ops channel

The memory root is defined in `.felix-memory-root` (resolves to `./life`). The environment variable `FELIX_MEMORY_ROOT` can override this.

## Running Commands

### Memory System (Python)
```bash
python memory_system/setup_memory.py              # Initialize ~/life PARA structure
python memory_system/create_daily_note.py         # Create today's daily note
python memory_system/create_daily_note.py --date YYYY-MM-DD
python memory_system/consolidate_memory.py        # Scan daily notes → write consolidation report
```

### Agent Runtime (PowerShell)
```powershell
# Full task lifecycle
.\automation\agent-runtime\scripts\New-AgentTask.ps1 -Title "..." -Workdir "..." -Summary "..."
.\automation\agent-runtime\scripts\Start-AgentTask.ps1 -TaskId <task-id>
.\automation\agent-runtime\scripts\Get-AgentTasks.ps1          # Dashboard
.\automation\agent-runtime\scripts\Watch-AgentTasks.ps1 -Recover  # Monitor + auto-restart

# Register background monitor as Windows Scheduled Task
.\automation\agent-runtime\scripts\Install-AgentSupervisorTask.ps1
```

### Optional QMD Semantic Search (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File memory_system/qmd_index_life.ps1
powershell -ExecutionPolicy Bypass -File memory_system/qmd_status_life.ps1
```

## Architecture

### Memory System (`memory_system/`)

All memory utilities share helpers in `common.py`:
- `resolve_life_root()` — resolves the PARA root path from env var → `.felix-memory-root` → `~/life`
- `write_text_if_missing_or_empty()` / `write_json_if_missing_or_empty()` — safe write helpers (never overwrite existing content)

The three memory layers in `life/`:
1. **PARA Knowledge Graph** (`Projects/`, `Areas/`, `Resources/`, `Archives/`) — each entity has `summary.md` + `items.json`
2. **Daily Notes** (`daily/YYYY-MM-DD.md`) — created by `create_daily_note.py`, consolidated nightly
3. **Tacit Knowledge** (`tacit/`) — hard rules: `communication_preferences.md`, `workflow_rules.md`, `security_rules.md`, `lessons_learned.md`

### Agent Runtime (`automation/agent-runtime/`)

Core module: `runtime/AgentRuntime.psm1` — defines all shared functions, path resolution, manifest I/O, backend detection, and prompt generation. All scripts import this module.

**Task lifecycle:**
```
New-AgentTask.ps1 → task.json + prd.md + checklist.json (status=pending)
        ↓
Start-AgentTask.ps1 → detect backend (tmux preferred, detached-pwsh fallback) → status=running
        ↓
Invoke-AgentLoop.ps1 (runs detached) → codex exec → Test-AgentTask.ps1 → retry up to maxAttempts
        ↓
Invoke-CompletionHook.ps1 → log event + Telegram notification → status=completed|failed
        ↓
Watch-AgentTasks.ps1 → detects stalls → auto-restarts
```

**Task folder structure** (`tasks/<YYYYMMDD-HHMMSS-slug>/`):
- `task.json` — manifest with status, attempt count, process ID, validation state
- `prd.md` — Product Requirements Document (Objective, Scope, Deliverables)
- `checklist.json` — array of `{id, title, required, status, evidence}` items
- `completion.md` — agent's written summary when done
- `done.json` — sentinel file written on successful completion
- `logs/` — `codex-attempt-N.jsonl`, `.stdout.log`, `.stderr.log`, `loop.log`

Completed/failed tasks are moved to `archive/`.

**Runtime config** (`state/runtime-config.json`):
```json
{
  "preferredBackend": "tmux",
  "fallbackBackend": "detached-pwsh",
  "telegram": { "enabled": true, "groupId": "...", "topicId": "..." }
}
```

### Data Formats

**checklist.json item:**
```json
{ "id": "prd-reviewed", "title": "PRD reviewed", "required": true, "status": "pending", "evidence": "" }
```
Valid statuses: `pending | done | blocked`

**task.json status values:** `pending | running | retrying | completed | failed`

## Key Documentation

- `How to Build an AI Bot...md` — full course walkthrough of the Felix system (OpenClaw setup, memory phases, Telegram integration, autonomous execution)
- `FELIX_STALL_PLAYBOOK.md` — debug guide when Felix appears stalled (OpenClaw health, Telegram pickup, session inspection, file timestamps)
- `automation/agent-runtime/README.md` — agent runtime reference: task lifecycle, backends, retry logic, completion hooks
- `memory_system/README.md` — memory system reference: PARA structure, daily notes, tacit knowledge, QMD integration
