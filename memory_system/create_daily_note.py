from __future__ import annotations

import argparse
from datetime import date

from common import (
    build_daily_note_content,
    ensure_directory,
    resolve_life_root,
    today_local,
    write_text_if_missing_or_empty,
)


def parse_note_date(raw_value: str | None) -> date:
    """Parse an explicit note date or fall back to today's local date."""
    if not raw_value:
        return today_local()
    return date.fromisoformat(raw_value)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create today's daily note for the Felix memory system."
    )
    parser.add_argument(
        "--date",
        help="Optional date in YYYY-MM-DD format. Defaults to today.",
    )
    parser.add_argument(
        "--root",
        help="Optional custom life root. Defaults to ~/life.",
    )
    args = parser.parse_args()

    note_date = parse_note_date(args.date)
    life_root = resolve_life_root(args.root)
    daily_root = life_root / "daily"
    ensure_directory(daily_root)

    note_path = daily_root / f"{note_date.isoformat()}.md"
    status = write_text_if_missing_or_empty(note_path, build_daily_note_content(note_date))

    print(f"{status}: {note_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

