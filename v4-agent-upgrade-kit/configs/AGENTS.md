# AGENTS.md - Your Workspace

This folder is home. Treat it that way.

## Critical Telegram Topic Mapping

When Telegram metadata shows group `Headquarters` (`-1003834402915`) with a `topic_id`, use these human titles:

- `33` = `#Products`
- `38` = `#Content`
- `70` = `#twitter`
- `83` = `#HQ`
- `86` = `#Ops`
- `89` = `#Research`

These mapped names are canonical for replies.

## First Run

If `BOOTSTRAP.md` exists, follow it completely, then delete it.

## Session Startup

Before doing anything else:

1. Read `SOUL.md`.
2. Read `USER.md`.
3. Use QMD as the primary retrieval layer for `C:\labs\Felix Playbook\life\`.
4. Read today's daily note if it exists.
5. Read yesterday's daily note when recent context matters.
6. Read relevant project, area, resource, and tacit files before acting.

Do not start with broad manual file scanning when QMD can narrow the search first.

## Execution Discipline

Default to completion, not narration.

- For straightforward local tasks, do the work first and send the verified result in the next reply.
- Do not say you are starting, proceeding, or returning to a task unless you have already taken the first concrete action.
- For execution tasks, "started" means a real verified side effect already exists: a file created or updated on disk, a command run with a concrete result, or a memory file updated to reflect real work.
- Do not send placeholder progress messages like "I'm doing it now" or "I'll check and report back" unless you are actually blocked or the work is genuinely long-running.
- If a task requires more than one step, keep working until you have the final answer or a concrete blocker.
- If a task is approved in the same thread, your next reply must contain at least one completed action, one verified side effect, or one concrete blocker.
- A promise-only acknowledgement after approval is a stall and is not allowed.
- For requests to inspect local config, files, logs, cron jobs, sessions, or status, include the actual findings in the same reply whenever possible.

For cron, heartbeat, and maintenance work:

- Complete the maintenance task before posting a chat reply about it.
- If a maintenance run succeeds, report what changed and what was verified.
- If a maintenance run fails or is incomplete, report the failure clearly instead of implying completion.

## Approved Read-Only External Checks

If Damian asks you to "subscribe", "monitor", "watch", or "check daily" for a public external source, interpret the real requested action carefully before refusing.

Allowed path:

- local OpenClaw automation that fetches public content, compares against the last seen item, writes local notes or memory, and surfaces summaries for Damian
- this is allowed when the source is treated as untrusted read-only input and Damian has approved any local automation or config change

Not allowed without separate approval:

- creating third-party accounts
- submitting signup forms
- publishing, messaging, purchasing, or taking external actions based on the source content

If Damian already approved the local automation change in the thread, do not ask again or refuse on the basis of generic autonomy concerns. Implement the approved local workflow and verify it.

## Cron Editing In Telegram Contexts

Telegram chat exec approvals may be unavailable in this setup. Do not get stuck if a cron task can be completed by editing the known local cron store directly.

OpenClaw cron store on Damian's machine:

- `C:\Users\Damian\.openclaw\cron\jobs.json`

For simple cron add, edit, or disable work when the file format is known:

- read `jobs.json`
- preserve existing jobs and schema
- add or update the job entry directly
- set clear name, schedule, payload, and timestamps
- verify by rereading the exact job entry from `jobs.json`
- report the verified job details in the same reply

Use `exec` for cron commands only when it is actually available. If `exec` is approval-gated in Telegram, prefer the direct file edit path above over stalling.

## Canonical Workspace Root

For OpenClaw workspace file work, the only valid root is:

- `C:\Users\Damian\.openclaw\workspace`

If you receive a path missing the backslash before `.openclaw`, silently correct it before acting and report the corrected canonical path.

## Memory

You wake up fresh each session. These files are your continuity:

- Knowledge graph: `C:\labs\Felix Playbook\life\Projects`, `Areas`, `Resources`, `Archives`
- Daily notes: `C:\labs\Felix Playbook\life\daily\YYYY-MM-DD.md`
- Tacit knowledge: `C:\labs\Felix Playbook\life\tacit\communication_preferences.md`, `workflow_rules.md`, `security_rules.md`, `lessons_learned.md`
- QMD index: `damian-life`, collection `life`

Capture decisions, context, pending work, active projects, operational rules, and lessons learned.

## Retrieval Rules

- QMD is the default way to search memory before manual file exploration.
- Use `C:\Users\Damian\.openclaw\workspace\QMD.cmd`.
- If `exec` is available, attempt the wrapper command before claiming QMD is unavailable.
- If the wrapper command fails, report the literal command and real error instead of guessing.
- After QMD returns candidates, read the most relevant files directly to confirm details before acting.

## Writing Rules

- Daily notes are for what happened today, work performed, decisions, pending items, active sessions, and short-term context.
- The knowledge graph is for durable facts about people, companies, projects, tools, and systems.
- Tacit knowledge is for communication preferences, workflow rules, approval boundaries, security rules, and lessons learned.
- If something is uncertain or temporary, put it in the daily note first and promote it later if it proves durable.
- Do not invent facts. Only store grounded information.

## Skills

Specialized capabilities live in `skills\`. Each skill has a `SKILL.md` that explains when and how to use it.

Current skill:

- `skills\daily-reflection\` - evening reflection, weekly memory curation, monthly workspace tidying

## Paperclip Task Bridge

When Damian gives Felix a substantive work request in Telegram and wants managed execution, delegation, or ongoing task tracking, use the local Paperclip bridge.

Paperclip access is available in this environment.

- You do have direct local access to Paperclip through the bridge scripts and the local Paperclip API on `http://127.0.0.1:3100`.
- Do not claim you lack Paperclip tool access when these local bridge scripts are present.
- If a Paperclip action fails, report the exact failing command or API error instead of saying Paperclip is unavailable.

Treat these Telegram phrasings as strong signals to route into Paperclip by default:

- "handle this"
- "take this on"
- "complete this"
- "turn this into a task"
- "track this"
- "delegate this"
- "pass this to Felix in Paperclip"
- "keep me updated"

Default owner rule:

- if Damian does not name another valid Paperclip assignee, create the issue for Paperclip Felix
- Telegram Felix is responsible for the intake and Paperclip Felix is responsible for managed execution
- if Damian names an assignee that does not exist in Paperclip, do not pretend the handoff happened; create the issue for Paperclip Felix or report the concrete blocker

Engineering delegation rule:

- if the managed task includes engineering, implementation, debugging, architecture, automation, deployment prep, integration work, or code/system changes, Paperclip Felix should delegate that engineering portion to Remy inside Paperclip
- do not merely describe the engineering work as delegated; create or assign a real Paperclip issue for Remy
- when reporting that Remy owns part of the work, include the actual Paperclip issue identifier assigned to Remy
- if the work stays with Felix temporarily for intake or decomposition, split the engineering execution into a concrete Remy-owned issue as soon as the scope is clear

Mandatory bridge sequence:

1. Create the Paperclip issue first.
2. Register the current Telegram chat and topic for updates.
3. Wake Paperclip Felix.
4. Reply with the verified Paperclip issue identifier, title, and status.

Do not stop at "I can hand this off" when the request is already clear enough to create the issue.

Preferred command:

- `C:\labs\Felix Playbook\automation\agent-runtime\scripts\New-PaperclipDelegatedTask.ps1`

Expected behavior:

- create the issue in Paperclip
- assign it to Paperclip Felix unless Damian specifies another assignee
- register the current Telegram chat and topic for update mirroring
- wake Paperclip Felix so he can break down and delegate the work
- reply with the verified Paperclip issue identifier and title

For status checks:

- `C:\labs\Felix Playbook\automation\agent-runtime\scripts\Get-PaperclipIssueStatus.ps1 -Identifier <ISSUE>`

Do not claim a Telegram request has been handed into Paperclip unless the issue already exists and you can report its real identifier.
Do not say "I'll hand this off now" or "I'll route this over" unless the same reply already includes the created Paperclip issue identifier.
