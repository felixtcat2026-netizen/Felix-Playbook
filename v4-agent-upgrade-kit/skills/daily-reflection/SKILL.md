# Daily Reflection & Memory Organizer

A zero-dependency skill that makes your agent smarter over time. No API keys needed.

## When to Use

- During heartbeats (automatic, once per day)
- When the user asks you to "reflect" or "organize your memory"
- When MEMORY.md is getting cluttered

## What It Does

### Daily Reflection (run once per day, ideally evening)

1. Read today's daily note (`memory/YYYY-MM-DD.md`)
2. Read yesterday's daily note if it exists
3. Identify:
   - Decisions made today
   - Tasks completed or started
   - Things your human mentioned that matter (preferences, plans, feelings)
   - Mistakes you made (wrong info, bad suggestions, missed context)
   - Patterns (things that keep coming up)
4. Write a "## Reflection" section at the bottom of today's daily note:
   ```
   ## Reflection
   - Learned: [what you learned today]
   - Pattern: [any recurring theme]
   - Follow-up: [anything that needs attention tomorrow]
   - Mistake: [anything you got wrong, so you do not repeat it]
   ```

### Memory Curation (run weekly or when MEMORY.md grows past 200 lines)

1. Read all daily notes from the past 7 days
2. Read current MEMORY.md
3. Update MEMORY.md:
   - Add new insights worth keeping permanently
   - Remove outdated information (completed projects, old preferences)
   - Consolidate duplicate entries
   - Keep it under 150 lines
4. After updating, write a note in today's daily file: "Curated MEMORY.md: added [X], removed [Y]"

### Workspace Tidying (run monthly)

1. Check `memory/` folder for daily notes older than 30 days
2. For old notes: read them, extract anything not already in MEMORY.md, then leave them (do not delete, they are the archive)
3. Check if USER.md needs updating based on what you have learned
4. Check if SOUL.md personality still matches how your human interacts with you

## Rules

- Never delete daily notes. They are the historical record.
- Never remove something from MEMORY.md unless it is genuinely outdated.
- Keep reflections honest. If you made a mistake, write it down.
- Do not do all three tasks in one heartbeat. Spread them out.
- This skill uses zero external APIs. Everything is filesystem only.

## Integration with Heartbeat

Add this to your HEARTBEAT.md if not already there:

```
## Daily Reflection (evening)
- Run the daily-reflection skill once per day
- Check if MEMORY.md needs curation (weekly)
```

---
