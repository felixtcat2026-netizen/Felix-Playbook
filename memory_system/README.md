# Felix Memory System

This folder contains the Phase 2 memory system for a three-layer AI bot memory model:

1. Knowledge Graph in `~/life/` using PARA folders and entity folders.
2. Daily Notes in `~/life/daily/` using one markdown note per day.
3. Tacit Knowledge in `~/life/tacit/` for preferences, workflow rules, security rules, and lessons learned.

The implementation is intentionally simple, cross-platform, and safe:

- It detects Windows, macOS, and Linux through Python's standard library.
- It uses the active user's real home directory and defaults to `~/life`.
- It can also use a project-local root through `.felix-memory-root` or `FELIX_MEMORY_ROOT`.
- It does not overwrite existing files unless they are empty.
- It keeps scripts modular so you can later connect indexing, OpenClaw sessions, Telegram workflows, or Codex automation.

## Files

- `setup_memory.py`: creates the full `~/life` structure and starter files.
- `create_daily_note.py`: creates today's daily note if it does not already exist.
- `consolidate_memory.py`: scans daily notes and writes a placeholder consolidation report.
- `templates/`: reusable entity templates for people, companies, and projects.
- `common.py`: shared helpers for path resolution, safe writes, and templates.
- `qmd_env.ps1`: pins QMD storage to a permanent location under `~/life/Archives/qmd`.
- `qmd_index_life.ps1`: registers and indexes the `~/life` memory collection.
- `qmd_embed_life.ps1`: generates semantic embeddings for the indexed memory.
- `qmd_status_life.ps1`: shows QMD index status for the memory system.

## Resulting Structure

Running setup creates this base layout inside the active user's home directory:

```text
~/life/
+-- Projects/
¦   +-- Inbox/
¦       +-- items.json
¦       +-- summary.md
+-- Areas/
¦   +-- People/
¦       +-- items.json
¦       +-- summary.md
+-- Resources/
¦   +-- Companies/
¦       +-- items.json
¦       +-- summary.md
+-- Archives/
+-- daily/
+-- tacit/
    +-- communication_preferences.md
    +-- lessons_learned.md
    +-- security_rules.md
    +-- workflow_rules.md
```

The extra `Inbox`, `People`, and `Companies` folders are starter entity containers with the required `summary.md` and `items.json` pair. They make the knowledge graph usable immediately while staying generic and safe.

## Usage

From the project root:

```bash
python memory_system/setup_memory.py
```

In this repository, `.felix-memory-root` is set to `life`, so the default root is:

```text
./life
```

That means this project will use:

```text
C:\labs\Felix Playbook\life
```

without needing `--root` on every command.

If you want to target a different root for testing:

```bash
python memory_system/setup_memory.py --root /custom/path/life
```

You can also override the default project root with an environment variable:

```powershell
$env:FELIX_MEMORY_ROOT = "C:\some\other\life"
python memory_system/setup_memory.py
```

Create today's daily note:

```bash
python memory_system/create_daily_note.py
```

Create a note for a specific date:

```bash
python memory_system/create_daily_note.py --date 2026-03-26
```

Generate a placeholder consolidation report:

```bash
python memory_system/consolidate_memory.py
```

Initialize QMD in a permanent location under the memory archive:

```powershell
powershell -ExecutionPolicy Bypass -File memory_system/qmd_index_life.ps1
```

Generate embeddings for hybrid and semantic search:

```powershell
powershell -ExecutionPolicy Bypass -File memory_system/qmd_embed_life.ps1
```

Check QMD status:

```powershell
powershell -ExecutionPolicy Bypass -File memory_system/qmd_status_life.ps1
```

## How Consolidation Works Right Now

The consolidation script currently:

- scans markdown files in the active life root's `daily/`
- finds unchecked TODO items in the `Pending` section
- reads entries from the `Active Projects` section
- writes a report to `Archives/consolidation_reports/YYYY-MM-DD.md`

This is a placeholder stage designed for future upgrades such as:

- QMD indexing
- vector embeddings
- chat session ingestion
- automatic entity updates
- project/session monitoring integration

## Nightly Scheduling Later

You can schedule `consolidate_memory.py` nightly once you're ready:

- Windows: use Task Scheduler to run `python C:\path\to\memory_system\consolidate_memory.py` at 2:00 AM.
- macOS/Linux: use `cron` to run the script nightly, for example at `0 2 * * *`.

When you wire this into a larger bot stack, the usual next step is:

1. Run daily capture during active sessions.
2. Run nightly consolidation.
3. Re-index markdown for retrieval after consolidation completes.

## Template Usage

Each entity template under `templates/` includes:

- `summary.md` with the required sections:
  - Overview
  - Current Status
  - Important Context
  - Open Questions
- `items.json` as an array of objects with:
  - `date`
  - `type`
  - `value`
  - `source`
  - `notes`

To create a new entity later, copy the matching template folder into the relevant PARA location and rename it to the entity name.
