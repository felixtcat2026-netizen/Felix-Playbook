# Free Agent Upgrade Kit v4
**Built by The Agent Crew** | theagentcrew.org

Turn your OpenClaw agent from a chatbot into a real assistant.

Your agent already works. It answers questions, runs commands, does what you ask. But it forgets everything between sessions. It has no personality. It never checks in on you. It just waits.

This kit changes that.

## What You Get

**Config files** that actually work:
- A personality system that makes your agent feel like YOUR assistant, not a generic chatbot
- A memory protocol so your agent remembers yesterday, last week, and last month
- Proactive heartbeats so your agent checks in, follows up, and catches things before you ask
- Clear operating rules so your agent knows when to speak and when to stay quiet

**Daily Reflection skill:**
- Your agent reviews its own day, identifies patterns, logs mistakes, and gets smarter over time
- Weekly memory curation keeps long-term memory clean and useful
- Zero API keys needed. Pure filesystem.

**Morning Briefing + Evening Reflection (optional):**
- Wake up to a quick summary: weather, pending tasks, anything from yesterday that needs attention
- Evening reflection: your agent reviews the day and prepares handoff notes for tomorrow
- Your agent asks if you want these during setup — nothing runs without your consent
- Timezone-aware scheduling, including half-hour offset timezones

**The Awakening:**
- On first run after install, your agent greets you with the upgrade experience
- Quick personality quiz (2-4 questions) tailors the setup to YOUR preferences
- Your agent does its first proactive action right there to prove it works

## Install

```bash
bash install.sh
```

That is it. The script:
1. Detects your OpenClaw workspace
2. Backs up your existing config files and skills (nothing is lost)
3. Preserves files that already have real content (won't overwrite your custom configs)
4. Installs the upgraded configs and skill
5. Next time you chat with your agent, the upgrade kicks in

## What is in the Box

```
configs/
  SOUL.md          - Personality and communication style
  AGENTS.md        - Operating rules and memory protocol
  HEARTBEAT.md     - Proactive behavior checklist
  USER.md          - Template for your info (filled during setup)
  IDENTITY.md      - Template for agent identity (filled during setup)
  TOOLS.md         - Local environment notes
  MEMORY.md        - Long-term memory template
  BOOTSTRAP.md     - One-time upgrade experience (auto-deletes)

skills/
  daily-reflection/ - Self-reflection and memory organization skill

install.sh         - One-command installer
```

## After Install

Your agent will:
- Greet you and ask a few quick questions to personalize the setup
- Start remembering things between sessions
- Offer to check in on you during the day (or stay quiet, your choice)
- Reflect on its own performance and improve over time

## Rollback

Changed your mind? Your original files are in `tac-backup-YYYYMMDD-HHMMSS/` in your workspace.
See `RESTORE.md` inside the backup folder for step-by-step rollback instructions.

## Uninstall

```bash
# 1. Restore your original files from backup
cp tac-backup-YYYYMMDD-HHMMSS/*.md ~/.openclaw/workspace/
cp -r tac-backup-YYYYMMDD-HHMMSS/skills/* ~/.openclaw/workspace/skills/ 2>/dev/null

# 2. Remove crons (if you set them up)
openclaw cron remove --name tac-morning-briefing
openclaw cron remove --name tac-evening-reflection

# 3. Remove skill and install marker
rm -rf ~/.openclaw/workspace/skills/daily-reflection
rm ~/.openclaw/workspace/.tac-installed
```

## Want More?

This is the free starter kit. The Agent Crew builds tools for people who run AI agents seriously.

Visit [theagentcrew.org](https://theagentcrew.org) for more.

---

_Built by The Agent Crew | Version 4.0_
