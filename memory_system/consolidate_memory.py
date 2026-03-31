from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from common import (
    CONSOLIDATION_REPORT_TEMPLATE,
    ensure_directory,
    markdown_bullets,
    resolve_life_root,
)


HEADING_PATTERN = re.compile(r"^#\s+(?P<title>.+?)\s*$")
TODO_PATTERN = re.compile(r"^\s*-\s+\[\s\]\s+(?P<todo>.+?)\s*$")


@dataclass
class DailyNoteSummary:
    path: Path
    incomplete_todos: list[str]
    active_projects: list[str]


def extract_section(lines: list[str], title: str) -> list[str]:
    """Return the raw lines for a first-level markdown heading section."""
    capture = False
    section_lines: list[str] = []

    for line in lines:
        match = HEADING_PATTERN.match(line)
        if match:
            current_title = match.group("title").strip().lower()
            if capture and current_title != title.lower():
                break
            capture = current_title == title.lower()
            continue
        if capture:
            section_lines.append(line.rstrip())

    return section_lines


def summarize_daily_note(note_path: Path) -> DailyNoteSummary:
    """Read one daily note and collect incomplete tasks plus active projects."""
    lines = note_path.read_text(encoding="utf-8").splitlines()
    pending_lines = extract_section(lines, "Pending")
    project_lines = extract_section(lines, "Active Projects")

    incomplete_todos: list[str] = []
    for line in pending_lines:
        match = TODO_PATTERN.match(line)
        if match:
            incomplete_todos.append(f"{note_path.name}: {match.group('todo').strip()}")

    active_projects = []
    for line in project_lines:
        stripped = line.strip()
        if not stripped or stripped == "-":
            continue
        if stripped.startswith("- "):
            active_projects.append(f"{note_path.name}: {stripped[2:].strip()}")
        else:
            active_projects.append(f"{note_path.name}: {stripped}")

    return DailyNoteSummary(
        path=note_path,
        incomplete_todos=incomplete_todos,
        active_projects=active_projects,
    )


def write_report(life_root: Path, note_summaries: list[DailyNoteSummary]) -> Path:
    """Write a simple placeholder consolidation report for future expansion."""
    report_root = life_root / "Archives" / "consolidation_reports"
    ensure_directory(report_root)

    all_todos: list[str] = []
    all_projects: list[str] = []
    for summary in note_summaries:
        all_todos.extend(summary.incomplete_todos)
        all_projects.extend(summary.active_projects)

    timestamp = datetime.now()
    report_path = report_root / f"{timestamp.strftime('%Y-%m-%d')}.md"
    report_content = CONSOLIDATION_REPORT_TEMPLATE.format(
        date=timestamp.strftime("%Y-%m-%d"),
        generated_at=timestamp.isoformat(timespec="seconds"),
        life_root=life_root,
        incomplete_todos=markdown_bullets(all_todos, "No incomplete TODOs found."),
        active_projects=markdown_bullets(all_projects, "No active projects found."),
    )
    report_path.write_text(report_content, encoding="utf-8")
    return report_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scan daily notes and write a placeholder consolidation report."
    )
    parser.add_argument(
        "--root",
        help="Optional custom life root. Defaults to ~/life.",
    )
    args = parser.parse_args()

    life_root = resolve_life_root(args.root)
    daily_root = life_root / "daily"
    ensure_directory(daily_root)

    daily_notes = sorted(daily_root.glob("*.md"))
    note_summaries = [summarize_daily_note(path) for path in daily_notes]
    report_path = write_report(life_root, note_summaries)

    print(f"Scanned {len(daily_notes)} daily note(s).")
    print(f"Wrote report: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

