# TOOLS.md - Local Notes

Skills define how tools work. This file is for environment-specific details.

## QMD

Use this exact wrapper for memory retrieval:

- `C:\Users\Damian\.openclaw\workspace\QMD.cmd`

Examples:

- `C:\Users\Damian\.openclaw\workspace\QMD.cmd status --index damian-life`
- `C:\Users\Damian\.openclaw\workspace\QMD.cmd search "pending" -c life --index damian-life`
- `C:\Users\Damian\.openclaw\workspace\QMD.cmd vsearch "active projects" -c life --index damian-life`
- `C:\Users\Damian\.openclaw\workspace\QMD.cmd get qmd://life/daily/2026-03-26.md --index damian-life`

Notes:

- default index: `damian-life`
- default collection: `life`
- use QMD for retrieval first, then read the returned files directly to confirm details

## OpenClaw Cron Store

For this machine, persistent OpenClaw cron definitions live here:

- `C:\Users\Damian\.openclaw\cron\jobs.json`

Practical rule:

- if Telegram `exec` approvals are unavailable but the cron schema is already known, prefer editing `jobs.json` directly over stalling on `openclaw cron add`
- after editing, reread the exact job entry and report the verified name, schedule, payload message, and enabled state
- preserve `version`, existing jobs, and unrelated state fields when modifying the file

Current schedule examples already in the file:

- `nightly-consolidation-worker`
- `hourly-heartbeat-worker`
- `evening-reflection`

## OpenClaw Runtime Recovery

Local runtime hooks on this machine:

- scheduled task: `OpenClaw Gateway`
- CLI: `C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd`

Useful commands:

- `schtasks /Query /TN "OpenClaw Gateway" /FO LIST`
- `C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd gateway status`
- `C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd status --deep`
- `C:\Users\Damian\AppData\Roaming\npm\openclaw.cmd gateway restart`
- `schtasks /Run /TN "OpenClaw Gateway"`

Heartbeat rule:

- if the local OpenClaw runtime appears crashed or unhealthy, restart it automatically, verify it, then report the result

## Paperclip Bridge

For this machine, Telegram-to-Paperclip task handoff is implemented with these scripts:

- `C:\labs\Felix Playbook\automation\agent-runtime\scripts\New-PaperclipDelegatedTask.ps1`
- `C:\labs\Felix Playbook\automation\agent-runtime\scripts\Get-PaperclipIssueStatus.ps1`
- `C:\labs\Felix Playbook\automation\agent-runtime\scripts\Watch-PaperclipBridge.ps1`
- `C:\labs\Felix Playbook\automation\agent-runtime\scripts\Install-PaperclipBridgeWatcherTask.ps1`

Bridge config lives here:

- `C:\labs\Felix Playbook\automation\agent-runtime\state\paperclip-bridge.config.json`

Practical rule:

- when a Telegram request should become a managed Paperclip task, create it with `New-PaperclipDelegatedTask.ps1`, pass the current Telegram chat and topic when available, and report the real Paperclip issue identifier
- if Damian asks for task status, prefer `Get-PaperclipIssueStatus.ps1` over guessing from memory

Preferred creation shape:

- `powershell -File "C:\labs\Felix Playbook\automation\agent-runtime\scripts\New-PaperclipDelegatedTask.ps1" -Title "<short title>" -Description "<grounded task summary>" -ChatId "<current telegram chat id>" -TopicId "<current telegram topic id>"`

Routing rule:

- if the request came from Telegram and should be tracked or delegated, include the live chat and topic instead of falling back to the bridge defaults
- only rely on bridge defaults when the live Telegram ids are genuinely unavailable
