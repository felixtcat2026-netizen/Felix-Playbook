from __future__ import annotations

import argparse
from pathlib import Path

from common import (
    COMMUNICATION_PREFERENCES,
    ITEMS_TEMPLATE,
    LESSONS_LEARNED,
    SECURITY_RULES,
    SUMMARY_TEMPLATE,
    WORKFLOW_RULES,
    detect_platform,
    ensure_directory,
    resolve_life_root,
    write_json_if_missing_or_empty,
    write_text_if_missing_or_empty,
)


PARA_FOLDERS = ["Projects", "Areas", "Resources", "Archives"]
ENTITY_SEED_FOLDERS = [
    ("Projects", "Inbox"),
    ("Areas", "People"),
    ("Resources", "Companies"),
]


def create_base_structure(life_root: Path) -> list[str]:
    """Create the base directory tree for the memory system."""
    created_paths: list[str] = []

    for relative in ["", *PARA_FOLDERS, "daily", "tacit"]:
        directory = life_root / relative if relative else life_root
        ensure_directory(directory)
        created_paths.append(str(directory))

    for parent, child in ENTITY_SEED_FOLDERS:
        directory = life_root / parent / child
        ensure_directory(directory)
        created_paths.append(str(directory))

    return created_paths


def seed_tacit_knowledge(life_root: Path) -> list[tuple[str, str]]:
    """Create starter tacit knowledge files while preserving existing content."""
    tacit_root = life_root / "tacit"
    results = [
        (
            str(tacit_root / "communication_preferences.md"),
            write_text_if_missing_or_empty(
                tacit_root / "communication_preferences.md",
                COMMUNICATION_PREFERENCES,
            ),
        ),
        (
            str(tacit_root / "workflow_rules.md"),
            write_text_if_missing_or_empty(
                tacit_root / "workflow_rules.md",
                WORKFLOW_RULES,
            ),
        ),
        (
            str(tacit_root / "security_rules.md"),
            write_text_if_missing_or_empty(
                tacit_root / "security_rules.md",
                SECURITY_RULES,
            ),
        ),
        (
            str(tacit_root / "lessons_learned.md"),
            write_text_if_missing_or_empty(
                tacit_root / "lessons_learned.md",
                LESSONS_LEARNED,
            ),
        ),
    ]
    return results


def seed_entity_examples(life_root: Path) -> list[tuple[str, str]]:
    """
    Create starter entity files in a few safe seed folders.

    These folders make the structure immediately usable without assuming specific
    real entities. Durable entities can be added later by copying the templates.
    """
    results: list[tuple[str, str]] = []

    for parent, child in ENTITY_SEED_FOLDERS:
        entity_root = life_root / parent / child
        summary_path = entity_root / "summary.md"
        items_path = entity_root / "items.json"

        results.append((str(summary_path), write_text_if_missing_or_empty(summary_path, SUMMARY_TEMPLATE)))
        results.append((str(items_path), write_json_if_missing_or_empty(items_path, ITEMS_TEMPLATE)))

    return results


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create the Phase 2 Felix memory system safely in ~/life."
    )
    parser.add_argument(
        "--root",
        help="Optional custom life root. Defaults to ~/life.",
    )
    args = parser.parse_args()

    platform_info = detect_platform()
    life_root = resolve_life_root(args.root)

    create_base_structure(life_root)
    tacit_results = seed_tacit_knowledge(life_root)
    entity_results = seed_entity_examples(life_root)

    print(f"Platform: {platform_info.system_name}")
    print(f"Home directory: {platform_info.home_directory}")
    print(f"Life root: {life_root}")
    print("")
    print("Seeded files:")
    for path, status in [*tacit_results, *entity_results]:
        print(f"- {status}: {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

