#!/usr/bin/env python3
"""Validate that every SKILL.md under plugins/*/skills/*/ matches the
agentskills.io spec (https://agentskills.io/specification).

Checks:
  - File exists at plugins/<plugin>/skills/<name>/SKILL.md
  - Has YAML frontmatter delimited by '---' lines
  - Required fields: name, description
  - name: 1-64 chars, /^[a-z0-9]+(-[a-z0-9]+)*$/, matches parent dir
  - description: 1-1024 chars
  - Optional fields, when present, satisfy their length limits
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

ROOT = Path(__file__).resolve().parent.parent
SKILLS = sorted(ROOT.glob("plugins/*/skills/*/SKILL.md"))


def parse_frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        raise ValueError("missing leading '---' frontmatter delimiter")
    end = text.find("\n---", 4)
    if end == -1:
        raise ValueError("missing closing '---' frontmatter delimiter")
    block = text[4:end]
    out: dict[str, str] = {}
    current_key: str | None = None
    for raw in block.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw.startswith(" ") and current_key is not None:
            out[current_key] += " " + raw.strip()
            continue
        if ":" not in raw:
            raise ValueError(f"frontmatter line not 'key: value': {raw!r}")
        key, _, value = raw.partition(":")
        key = key.strip()
        value = value.strip()
        out[key] = value
        current_key = key
    return out


def validate(skill_path: Path) -> list[str]:
    errs: list[str] = []
    parent_name = skill_path.parent.name
    text = skill_path.read_text(encoding="utf-8")

    try:
        fm = parse_frontmatter(text)
    except ValueError as e:
        return [f"{skill_path}: frontmatter: {e}"]

    name = fm.get("name", "")
    if not name:
        errs.append(f"{skill_path}: missing required field 'name'")
    else:
        if not (1 <= len(name) <= 64):
            errs.append(f"{skill_path}: name must be 1-64 chars (got {len(name)})")
        if not NAME_RE.match(name):
            errs.append(
                f"{skill_path}: name {name!r} must match "
                f"^[a-z0-9]+(-[a-z0-9]+)*$ (lowercase, no leading/trailing/"
                f"consecutive hyphens)"
            )
        if name != parent_name:
            errs.append(
                f"{skill_path}: name {name!r} does not match parent "
                f"directory {parent_name!r}"
            )

    description = fm.get("description", "")
    if not description:
        errs.append(f"{skill_path}: missing required field 'description'")
    elif len(description) > 1024:
        errs.append(
            f"{skill_path}: description must be <=1024 chars "
            f"(got {len(description)})"
        )

    compatibility = fm.get("compatibility", "")
    if compatibility and len(compatibility) > 500:
        errs.append(
            f"{skill_path}: compatibility must be <=500 chars "
            f"(got {len(compatibility)})"
        )

    return errs


def main() -> int:
    if not SKILLS:
        print("validate_skills: no SKILL.md files found", file=sys.stderr)
        return 1
    all_errs: list[str] = []
    for skill in SKILLS:
        errs = validate(skill)
        rel = skill.relative_to(ROOT)
        if errs:
            print(f"FAIL {rel}")
            all_errs.extend(errs)
        else:
            print(f"  OK {rel}")
    if all_errs:
        print("\n".join(all_errs), file=sys.stderr)
        return 1
    print(f"\nvalidated {len(SKILLS)} skill(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
