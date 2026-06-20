#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-desktop-pet-e2e.png"
FAKE_LOG="/tmp/mimo-fake-codex.log"

cleanup() {
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"
./script/build_and_run.sh --verify
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -f "$FAKE_LOG" "$SCREENSHOT_PATH"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
"$APP_BINARY" &
APP_PID=$!

sleep 7
kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift - <<'SWIFT'
import CoreGraphics
import Foundation

let deadline = Date().addingTimeInterval(8)
while Date() < deadline {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    if let window = windows.first(where: { ($0[kCGWindowOwnerName as String] as? String ?? "") == "MimoDesktopPet" }),
       let id = window[kCGWindowNumber as String] {
        print(id)
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.25)
}
exit(1)
SWIFT
)"

screencapture -x -l "$WINDOW_ID" "$SCREENSHOT_PATH"

swift - "$SCREENSHOT_PATH" <<'SWIFT'
import AppKit
import Foundation

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    fputs("failed to load screenshot\n", stderr)
    exit(1)
}

guard bitmap.pixelsWide <= 280, bitmap.pixelsHigh <= 310 else {
    fputs("unexpected production window size \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)\n", stderr)
    exit(1)
}

let points = [
    (0, 0),
    (bitmap.pixelsWide - 1, 0),
    (0, bitmap.pixelsHigh - 1),
    (bitmap.pixelsWide - 1, bitmap.pixelsHigh - 1)
]
for (x, y) in points {
    let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1
    guard alpha <= 0.02 else {
        fputs("corner alpha is not transparent enough at \(x),\(y): \(alpha)\n", stderr)
        exit(1)
    }
}
SWIFT

grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"

echo "E2E passed: fake Codex app-server, production window, transparent corners, and thread reads verified."
