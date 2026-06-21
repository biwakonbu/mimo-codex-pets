#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"
./script/build_and_run.sh --verify

python3 - "$APP_BUNDLE" <<'PY'
import json
import os
import plistlib
import sys
from pathlib import Path


app_bundle = Path(sys.argv[1])
contents = app_bundle / "Contents"
plist_path = contents / "Info.plist"
binary_path = contents / "MacOS" / "MimoDesktopPet"
app_icon_path = contents / "Resources" / "AppIcon.icns"
pet_json_path = contents / "Resources" / "pets" / "mimo" / "pet.json"
spritesheet_path = contents / "Resources" / "pets" / "mimo" / "spritesheet.webp"


def fail(message: str) -> None:
    raise SystemExit(message)


if not plist_path.is_file():
    fail(f"Info.plist is missing: {plist_path}")

with plist_path.open("rb") as handle:
    info = plistlib.load(handle)

expected_values = {
    "CFBundleExecutable": "MimoDesktopPet",
    "CFBundleIdentifier": "com.biwakonbu.MimoDesktopPet",
    "CFBundleIconFile": "AppIcon",
    "CFBundleName": "MimoDesktopPet",
    "CFBundlePackageType": "APPL",
    "LSMinimumSystemVersion": "14.0",
    "NSPrincipalClass": "NSApplication",
}
for key, expected in expected_values.items():
    actual = info.get(key)
    if actual != expected:
        fail(f"Info.plist {key} expected {expected!r}, got {actual!r}")

if info.get("LSUIElement") is not True:
    fail(f"Info.plist LSUIElement must be true for the production menu-bar companion: {info.get('LSUIElement')!r}")

if not binary_path.is_file():
    fail(f"app executable is missing: {binary_path}")
if not os.access(binary_path, os.X_OK):
    fail(f"app executable is not executable: {binary_path}")
if binary_path.stat().st_size <= 0:
    fail(f"app executable is empty: {binary_path}")

if not app_icon_path.is_file() or app_icon_path.stat().st_size <= 0:
    fail(f"app icon is missing or empty: {app_icon_path}")
with app_icon_path.open("rb") as handle:
    icon_header = handle.read(4)
if icon_header != b"icns":
    fail(f"app icon is not an ICNS file: {app_icon_path}")

if not pet_json_path.is_file() or pet_json_path.stat().st_size <= 0:
    fail(f"Mimo pet.json is missing or empty: {pet_json_path}")
if not spritesheet_path.is_file() or spritesheet_path.stat().st_size <= 0:
    fail(f"Mimo spritesheet is missing or empty: {spritesheet_path}")

with pet_json_path.open("r", encoding="utf-8") as handle:
    pet = json.load(handle)

if pet.get("id") != "mimo":
    fail(f"bundled pet id expected 'mimo', got {pet.get('id')!r}")
if pet.get("displayName") != "Mimo":
    fail(f"bundled pet displayName expected 'Mimo', got {pet.get('displayName')!r}")
if pet.get("spritesheetPath") != "spritesheet.webp":
    fail(f"bundled pet spritesheetPath expected 'spritesheet.webp', got {pet.get('spritesheetPath')!r}")

with spritesheet_path.open("rb") as handle:
    header = handle.read(12)
if len(header) != 12 or header[:4] != b"RIFF" or header[8:12] != b"WEBP":
    fail("bundled spritesheet is not a WebP RIFF file")

print("App bundle contract check passed: LSUIElement production bundle and bundled Mimo resources verified.")
PY
