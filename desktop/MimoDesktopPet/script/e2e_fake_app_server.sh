#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-desktop-pet-e2e.png"
FAKE_LOG="/tmp/mimo-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-presentation-e2e.jsonl"

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
rm -f "$FAKE_LOG" "$SCREENSHOT_PATH" "$PRESENTATION_LOG"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_TEST_MODE=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift - <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let expectedLayer = Int(CGWindowLevelForKey(.screenSaverWindow))
let deadline = Date().addingTimeInterval(8)
while Date() < deadline {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    if let window = windows.first(where: { ($0[kCGWindowOwnerName as String] as? String ?? "") == "MimoDesktopPet" }),
       let id = window[kCGWindowNumber as String],
       let layer = window[kCGWindowLayer as String] as? Int {
        guard layer == expectedLayer else {
            fputs("unexpected Mimo window layer \(layer), expected screen-saver layer \(expectedLayer)\n", stderr)
            exit(1)
        }
        print(id)
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.25)
}
exit(1)
SWIFT
)"

swift - "$WINDOW_ID" <<'SWIFT'
import CoreGraphics
import Foundation

let windowNumber = CGWindowID(Int(CommandLine.arguments[1]) ?? 0)

func windowX() -> Double? {
    guard
        let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[String: Any]],
        let bounds = windows.first?[kCGWindowBounds as String] as? [String: Any],
        let x = bounds["X"] as? Double
    else {
        return nil
    }
    return x
}

var samples: [Double] = []
for _ in 0..<210 {
    if let x = windowX() {
        samples.append(x)
    }
    Thread.sleep(forTimeInterval: 1.0 / 60.0)
}

guard samples.count >= 90 else {
    fputs("too few movement samples: \(samples.count)\n", stderr)
    exit(1)
}

let deltas = zip(samples.dropFirst(), samples).map { $0 - $1 }
let movedDistance = abs((samples.last ?? 0) - (samples.first ?? 0))
let movingDeltas = deltas.map(abs).filter { $0 > 0.05 }
let largestDelta = deltas.map(abs).max() ?? 0
let deltaChanges = zip(deltas.dropFirst(), deltas).map { abs($0 - $1) }
let largestDeltaChange = deltaChanges.max() ?? 0

guard movedDistance >= 40 else {
    fputs("autonomous movement did not travel far enough: \(movedDistance)\n", stderr)
    exit(1)
}
guard movingDeltas.count >= 30 else {
    fputs("autonomous movement had too few moving samples: \(movingDeltas.count)\n", stderr)
    exit(1)
}
guard largestDelta <= 14 else {
    fputs("autonomous movement jumped too far in one sample: \(largestDelta)\n", stderr)
    exit(1)
}
guard largestDeltaChange <= 14 else {
    fputs("autonomous movement delta changed too abruptly: \(largestDeltaChange)\n", stderr)
    exit(1)
}
SWIFT

sleep 8
kill -0 "$APP_PID" >/dev/null

grep -Fq 'ご主人、「Mimo runtime QA」は作業を進めています' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」はツールで確認中です' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」は確認待ちです' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「別スレッドの確認」はレビューできます' "$PRESENTATION_LOG"

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

echo "E2E passed: fake Codex app-server, notification-driven per-thread Mimo summary bubbles, smooth autonomous movement, always-on-top production window, transparent corners, and thread reads verified."
