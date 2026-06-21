#!/usr/bin/env python3
"""Ensure the canonical QA gate cannot silently miss production E2E scripts."""

from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
QA_ALL = SCRIPT_DIR / "qa_all.sh"


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    qa_text = QA_ALL.read_text(encoding="utf-8")
    e2e_scripts = sorted(path.name for path in SCRIPT_DIR.glob("e2e_*.sh"))
    if not e2e_scripts:
        fail("no e2e_*.sh scripts were found")

    missing_syntax_checks = [
        name
        for name in e2e_scripts
        if f"desktop/MimoDesktopPet/script/{name}" not in qa_text
    ]
    missing_execution_steps = [
        name
        for name in e2e_scripts
        if f"./script/{name}" not in qa_text
    ]

    messages = []
    if missing_syntax_checks:
        messages.append(
            "missing from qa_all.sh shell syntax checks: "
            + ", ".join(missing_syntax_checks)
        )
    if missing_execution_steps:
        messages.append(
            "missing from qa_all.sh execution steps: "
            + ", ".join(missing_execution_steps)
        )
    if messages:
        fail("\n".join(messages))

    print(f"QA coverage check passed: {len(e2e_scripts)} production E2E scripts are covered.")


if __name__ == "__main__":
    main()
