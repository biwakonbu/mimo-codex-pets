#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
FIXTURE_PATH = ROOT_DIR / "script" / "title_sanitizer_fixtures.json"
SMOKE_PATH = ROOT_DIR / "script" / "live_app_server_smoke.py"


def load_smoke_module():
    spec = importlib.util.spec_from_file_location("live_app_server_smoke", SMOKE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load {SMOKE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    smoke = load_smoke_module()
    with FIXTURE_PATH.open("r", encoding="utf-8") as handle:
        fixtures = json.load(handle)

    for fixture in fixtures:
        candidates = fixture["candidates"]
        actual_16 = smoke.compact_title(candidates, limit=16)
        actual_12 = smoke.compact_title(candidates, limit=12)
        expected_16 = fixture["expectedLimit16"]
        expected_12 = fixture["expectedLimit12"]

        if actual_16 != expected_16:
            raise SystemExit(
                f"{fixture['name']}: expected limit16={expected_16!r}, got {actual_16!r}"
            )
        if actual_12 != expected_12:
            raise SystemExit(
                f"{fixture['name']}: expected limit12={expected_12!r}, got {actual_12!r}"
            )

    print(f"Title sanitizer parity fixtures passed: {len(fixtures)} cases.")


if __name__ == "__main__":
    main()
