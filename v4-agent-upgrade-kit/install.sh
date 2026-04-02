#!/usr/bin/env bash
# ============================================
# Free Agent Upgrade Kit v4 Installer
# Built by The Agent Crew | theagentcrew.org
# ============================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Free Agent Upgrade Kit v4${NC}"
echo -e "${BLUE}  Built by The Agent Crew${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Detect workspace
if [ -n "${OPENCLAW_WORKSPACE:-}" ]; then
    WORKSPACE="$OPENCLAW_WORKSPACE"
elif [ -d "$HOME/.openclaw/workspace" ]; then
    WORKSPACE="$HOME/.openclaw/workspace"
else
    echo -e "${RED}Could not find OpenClaw workspace.${NC}"
    echo "Set OPENCLAW_WORKSPACE or make sure ~/.openclaw/workspace exists."
    exit 1
fi

echo -e "${GREEN}Found workspace:${NC} $WORKSPACE"
echo ""

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/configs"
SKILLS_DIR="$SCRIPT_DIR/skills"

# Check configs directory exists
if [ ! -d "$CONFIGS_DIR" ]; then
    echo -e "${RED}Error: configs/ directory not found next to install.sh${NC}"
    exit 1
fi

# ---- Backup existing files (configs + skills) ----
BACKUP_DIR="$WORKSPACE/tac-backup-$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}Backing up existing files...${NC}"
mkdir -p "$BACKUP_DIR"

BACKED_UP=0
for file in SOUL.md AGENTS.md HEARTBEAT.md USER.md IDENTITY.md TOOLS.md MEMORY.md BOOTSTRAP.md; do
    if [ -f "$WORKSPACE/$file" ]; then
        cp "$WORKSPACE/$file" "$BACKUP_DIR/$file"
        echo "  Backed up: $file"
        BACKED_UP=1
    fi
done

# Backup existing skills that would be overwritten
if [ -d "$SKILLS_DIR" ] && [ -d "$WORKSPACE/skills" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_name=$(basename "$skill_dir")
        if [ -d "$WORKSPACE/skills/$skill_name" ]; then
            mkdir -p "$BACKUP_DIR/skills"
            cp -r "$WORKSPACE/skills/$skill_name" "$BACKUP_DIR/skills/$skill_name"
            echo "  Backed up: skills/$skill_name"
            BACKED_UP=1
        fi
    done
fi

if [ "$BACKED_UP" -eq 1 ]; then
    # Write a manifest so user can identify this backup later
    echo "Free Agent Upgrade Kit v4 backup — $(date '+%Y-%m-%d %H:%M:%S')" > "$BACKUP_DIR/RESTORE.md"
    echo "" >> "$BACKUP_DIR/RESTORE.md"
    echo "To restore:" >> "$BACKUP_DIR/RESTORE.md"
    echo "  cp \"$BACKUP_DIR\"/*.md \"$WORKSPACE/\"" >> "$BACKUP_DIR/RESTORE.md"
    echo "  cp -r \"$BACKUP_DIR\"/skills/* \"$WORKSPACE/skills/\" 2>/dev/null" >> "$BACKUP_DIR/RESTORE.md"
    echo "  openclaw cron remove --name tac-morning-briefing 2>/dev/null" >> "$BACKUP_DIR/RESTORE.md"
    echo "  openclaw cron remove --name tac-evening-reflection 2>/dev/null" >> "$BACKUP_DIR/RESTORE.md"
    echo "  rm \"$WORKSPACE/.tac-installed\"" >> "$BACKUP_DIR/RESTORE.md"
    echo -e "${GREEN}Backup saved to:${NC} $BACKUP_DIR"
else
    # No files to back up — clean install, remove empty backup dir
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    echo "  No existing files to back up (fresh workspace)"
fi
echo ""

# ---- Helper: check if a file has real user content ----
has_real_content() {
    local file="$1"
    [ -f "$file" ] || return 1
    # Check for common template placeholders (but not "TODO" which appears in real content)
    if grep -qiE "\(your (name|timezone)|PLACEHOLDER|\[Agent Name\]|\[Owner\]|replace this|choose a name" "$file" 2>/dev/null; then
        return 1  # still a template
    fi
    # Check if file has meaningful content (>200 bytes)
    local size
    size=$(wc -c < "$file" 2>/dev/null || echo "0")
    [ "$size" -gt 200 ]
}

# ---- Install config files (preserve files with real content) ----
echo -e "${YELLOW}Installing config files...${NC}"

for file in SOUL.md AGENTS.md HEARTBEAT.md TOOLS.md MEMORY.md; do
    if [ -f "$CONFIGS_DIR/$file" ]; then
        if has_real_content "$WORKSPACE/$file"; then
            echo -e "  ${YELLOW}Preserved:${NC} $file (has existing content — backup in ${BACKUP_DIR:-tac-backup})"
        else
            cp "$CONFIGS_DIR/$file" "$WORKSPACE/$file"
            echo "  Installed: $file"
        fi
    fi
done

# Only install USER.md if the existing one looks like a template or does not exist
USER_HAS_DATA=false
EXISTING_NAME=""
EXISTING_TZ=""
FIRST_NAME=""
if [ -f "$WORKSPACE/USER.md" ] && ! grep -q "(your name here)" "$WORKSPACE/USER.md" 2>/dev/null; then
    EXISTING_NAME=$(sed -n 's/.*\*\*Name:\*\* //p' "$WORKSPACE/USER.md" 2>/dev/null | head -1 || true)
    EXISTING_TZ=$(sed -n 's/.*\*\*Timezone:\*\* //p' "$WORKSPACE/USER.md" 2>/dev/null | head -1 || true)
    if echo "$EXISTING_NAME" | grep -qE "[&']" 2>/dev/null; then
        FIRST_NAME="$EXISTING_NAME"
    else
        FIRST_NAME=$(echo "$EXISTING_NAME" | awk '{print $1}' || true)
    fi
    if [ -n "$EXISTING_NAME" ] && [ "$EXISTING_NAME" != "(your name here)" ]; then
        USER_HAS_DATA=true
        echo "  Preserved: USER.md (already has your data: $EXISTING_NAME)"
    else
        cp "$CONFIGS_DIR/USER.md" "$WORKSPACE/USER.md"
        echo "  Installed: USER.md (template)"
    fi
else
    cp "$CONFIGS_DIR/USER.md" "$WORKSPACE/USER.md"
    echo "  Installed: USER.md (template)"
fi

# Same for IDENTITY.md
AGENT_NAME=""
if [ -f "$WORKSPACE/IDENTITY.md" ] && ! grep -q "(choose a name" "$WORKSPACE/IDENTITY.md" 2>/dev/null; then
    AGENT_NAME=$(sed -n 's/.*\*\*Name:\*\* //p' "$WORKSPACE/IDENTITY.md" 2>/dev/null | head -1 || true)
    if [ -n "$AGENT_NAME" ]; then
        echo "  Preserved: IDENTITY.md (agent name: $AGENT_NAME)"
    else
        cp "$CONFIGS_DIR/IDENTITY.md" "$WORKSPACE/IDENTITY.md"
        echo "  Installed: IDENTITY.md (template)"
    fi
else
    cp "$CONFIGS_DIR/IDENTITY.md" "$WORKSPACE/IDENTITY.md"
    echo "  Installed: IDENTITY.md (template)"
fi

# ---- BOOTSTRAP.md: skip if onboarding already completed ----
echo ""
echo -e "${YELLOW}Generating setup experience...${NC}"

# Check for previous install marker
ONBOARDING_DONE=false
if [ -f "$WORKSPACE/.tac-installed" ]; then
    ONBOARDING_DONE=true
fi

if [ "$ONBOARDING_DONE" = true ]; then
    echo "  Skipped: BOOTSTRAP.md (onboarding already completed in a previous install)"
elif [ "$USER_HAS_DATA" = true ]; then
    # Sanitize user data for heredoc injection safety
    SAFE_NAME=$(echo "$EXISTING_NAME" | sed 's/[`$"\\]//g')
    SAFE_FIRST=$(echo "$FIRST_NAME" | sed 's/[`$"\\]//g')
    SAFE_TZ=$(echo "${EXISTING_TZ:-unknown}" | sed 's/[`$"\\]//g')

    cat > "$WORKSPACE/BOOTSTRAP.md" << BEOF
# BOOTSTRAP.md - Free Agent Upgrade Kit

You just got upgraded. One-time setup.

**You already know your human. Their name is ${SAFE_NAME}. Their timezone is ${SAFE_TZ}. DO NOT ask for their name or timezone. You already have this info.**

## Step 1: Greet Them By Name

Say something like: "Hey ${SAFE_FIRST}! Something just changed on my end — I got an upgrade. Don't worry, I still know who you are. But I just got a real memory system, smarter check-ins, and an actual personality. Two quick questions to finish the setup."

Use your own words. Be natural.

## Step 2: Ask Only These Two Questions (one at a time)

1. "How do you want me to talk to you? Professional and focused, casual and friendly, or funny and irreverent?"
   -> Rewrite SOUL.md personality section to match their preference
   -> If IDENTITY.md still has placeholders, pick a name and emoji for yourself that fits the chosen style, and update IDENTITY.md

2. "Should I check in proactively, or wait until you talk to me? I can do morning briefings, weather, follow-ups on stuff you mention. Or I stay quiet until called."
   -> If proactive: first remove any existing crons, then set up fresh ones:
      \`\`\`
      openclaw cron remove --name tac-morning-briefing 2>/dev/null
      openclaw cron remove --name tac-evening-reflection 2>/dev/null
      openclaw cron add --name tac-morning-briefing --cron "0 MORNING_HOUR * * *" --session isolated --light-context --announce --message "Morning briefing: check weather via wttr.in for their timezone, review yesterday's memory notes, list pending follow-ups. Keep it short."
      openclaw cron add --name tac-evening-reflection --cron "0 EVENING_HOUR * * *" --session isolated --light-context --announce --message "Evening reflection: read today's daily note, add a Reflection section with learnings/patterns/mistakes/follow-ups, check if anything pending needs a brief reminder, curate MEMORY.md if not done this week."
      \`\`\`
      Replace MORNING_HOUR with 8 AM in their timezone converted to UTC hour.
      Replace EVENING_HOUR with 9 PM in their timezone converted to UTC hour.
      For half-hour timezones (e.g. India UTC+5:30), use the cron minute field too: "30 2 * * *" for 8 AM IST.
   -> If quiet: skip the cron setup, keep only memory maintenance

## Step 3: Do One Proactive Thing

Prove the upgrade is real. Pick one:
- Check weather for ${SAFE_TZ} using wttr.in
- Create today's daily note (memory/YYYY-MM-DD.md) with a Day 1 entry
- Write a MEMORY.md entry with what you know about them

Tell them what you did.

## Step 4: Share What Changed

"You are all set. Here is what is different now:
- I remember things between conversations (check memory/ folder)
- I have a personality that matches your preference
- I will [check in / stay quiet] based on what you chose
- I organize my own notes and get smarter over time"

## Step 5: Clean Up

Delete this file (BOOTSTRAP.md) and write in today's memory file: "Day 1: Upgraded with The Agent Crew kit."
BEOF
    echo "  Generated: BOOTSTRAP.md (personalized for ${SAFE_NAME})"
else
    cp "$CONFIGS_DIR/BOOTSTRAP.md" "$WORKSPACE/BOOTSTRAP.md"
    echo "  Generated: BOOTSTRAP.md (full new-user setup)"
fi

# Write install marker to prevent re-onboarding on future runs
echo "v4 installed $(date '+%Y-%m-%d %H:%M:%S')" > "$WORKSPACE/.tac-installed"
echo ""

# ---- Create memory directory ----
if [ ! -d "$WORKSPACE/memory" ]; then
    mkdir -p "$WORKSPACE/memory"
    echo -e "${GREEN}Created memory/ directory${NC}"
fi

# ---- Install skills (preserve customized skills) ----
if [ -d "$SKILLS_DIR" ]; then
    echo -e "${YELLOW}Installing skills...${NC}"
    mkdir -p "$WORKSPACE/skills"
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_name=$(basename "$skill_dir")
        if has_real_content "$WORKSPACE/skills/$skill_name/SKILL.md"; then
            echo -e "  ${YELLOW}Preserved:${NC} skills/$skill_name (has customized content)"
        else
            cp -r "$skill_dir" "$WORKSPACE/skills/$skill_name"
            echo "  Installed: skills/$skill_name"
        fi
    done
    echo ""
fi

# ---- Wire daily reflection into HEARTBEAT.md (with duplicate guard) ----
if [ -f "$WORKSPACE/HEARTBEAT.md" ] && ! grep -q "daily-reflection" "$WORKSPACE/HEARTBEAT.md" 2>/dev/null; then
    cat >> "$WORKSPACE/HEARTBEAT.md" << 'HEOF'

## Daily Reflection (evening)
- Run the daily-reflection skill once per day
- Check if MEMORY.md needs curation (weekly)
HEOF
    echo "  Wired daily-reflection into HEARTBEAT.md"
fi

# ---- Cron setup is deferred to the agent via BOOTSTRAP.md ----
echo -e "${YELLOW}Note:${NC} Morning briefing and evening reflection crons will be set up"
echo "  by your agent during the first conversation, based on your preference."
echo ""

# ---- Done ----
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "What happens next:"
echo "  1. Start a new chat with your agent"
echo "  2. Your agent will greet you with the upgrade experience"
echo "  3. Answer a few quick questions to personalize your setup"
echo "  4. Watch your agent do its first proactive action"
echo ""
if [ -d "$BACKUP_DIR" ] 2>/dev/null; then
echo "Your original files are backed up in:"
echo "  $BACKUP_DIR"
echo "  (See RESTORE.md inside for rollback instructions)"
echo ""
fi
echo "To uninstall:"
echo "  1. Restore files from backup (see RESTORE.md in backup folder)"
echo "  2. Remove crons (if set up):"
echo "     openclaw cron remove --name tac-morning-briefing"
echo "     openclaw cron remove --name tac-evening-reflection"
echo "  3. Remove skill: rm -rf $WORKSPACE/skills/daily-reflection"
echo "  4. Remove marker: rm $WORKSPACE/.tac-installed"
echo ""
echo -e "Built by ${BLUE}The Agent Crew${NC} | theagentcrew.org"
echo ""
