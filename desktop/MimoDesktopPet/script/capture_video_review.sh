#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
CAPTURE_SECONDS="${MIMO_VIDEO_REVIEW_SECONDS:-12}"
FRAME_INTERVAL="${MIMO_VIDEO_REVIEW_FRAME_INTERVAL:-0.08}"
VIDEO_FPS="${MIMO_VIDEO_REVIEW_FPS:-8}"
MAX_STEP_LIMIT="${MIMO_VIDEO_REVIEW_MAX_STEP_LIMIT:-14}"
OUTPUT_DIR="${MIMO_VIDEO_REVIEW_OUTPUT_DIR:-}"

usage() {
  cat >&2 <<'USAGE'
usage: ./script/capture_video_review.sh [--seconds N] [--frame-interval N] [--fps N] [--max-step N] [--output-dir DIR]

Captures a public-safe fake app-server Mimo review bundle under /tmp by default:
- mimo-window-content.mp4
- mimo-window-contact-sheet.jpg
- window-samples.csv
- presentation.jsonl
- review-summary.txt

Environment overrides:
  MIMO_VIDEO_REVIEW_SECONDS
  MIMO_VIDEO_REVIEW_FRAME_INTERVAL
  MIMO_VIDEO_REVIEW_FPS
  MIMO_VIDEO_REVIEW_MAX_STEP_LIMIT
  MIMO_VIDEO_REVIEW_OUTPUT_DIR
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seconds)
      CAPTURE_SECONDS="${2:?--seconds requires a value}"
      shift 2
      ;;
    --frame-interval)
      FRAME_INTERVAL="${2:?--frame-interval requires a value}"
      shift 2
      ;;
    --fps)
      VIDEO_FPS="${2:?--fps requires a value}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?--output-dir requires a value}"
      shift 2
      ;;
    --max-step)
      MAX_STEP_LIMIT="${2:?--max-step requires a value}"
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "required command not found: $name" >&2
    exit 1
  fi
}

require_command ffmpeg
require_command screencapture
require_command swift

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="/tmp/mimo-video-review-$(date +%Y%m%d-%H%M%S)"
fi

FRAMES_DIR="$OUTPUT_DIR/frames"
PRESENTATION_LOG="$OUTPUT_DIR/presentation.jsonl"
WINDOW_SAMPLES="$OUTPUT_DIR/window-samples.csv"
SUMMARY_PATH="$OUTPUT_DIR/review-summary.txt"
VIDEO_PATH="$OUTPUT_DIR/mimo-window-content.mp4"
CONTACT_SHEET="$OUTPUT_DIR/mimo-window-contact-sheet.jpg"

cleanup() {
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

mkdir -p "$FRAMES_DIR"
rm -f "$FRAMES_DIR"/frame_*.png \
  "$PRESENTATION_LOG" \
  "$WINDOW_SAMPLES" \
  "$SUMMARY_PATH" \
  "$VIDEO_PATH" \
  "$CONTACT_SHEET" \
  "$OUTPUT_DIR/app.stdout.log" \
  "$OUTPUT_DIR/app.stderr.log"

cd "$ROOT_DIR"
./script/build_and_run.sh --verify >/tmp/mimo-video-review-build.log
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_TEST_MODE=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_CODEX_DIALOGUE_ENABLED=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="${MIMO_VIDEO_REVIEW_WINDOW_ORIGIN:-160,160}" \
"$APP_BINARY" >"$OUTPUT_DIR/app.stdout.log" 2>"$OUTPUT_DIR/app.stderr.log" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null
sleep "${MIMO_VIDEO_REVIEW_LAUNCH_SETTLE_SECONDS:-0.6}"

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 520 --max-height 560)"

python3 - "$CAPTURE_SECONDS" "$FRAME_INTERVAL" "$VIDEO_FPS" "$MAX_STEP_LIMIT" <<'PY'
import sys

for label, raw in zip(("seconds", "frame interval", "fps", "max step"), sys.argv[1:]):
    try:
        value = float(raw)
    except ValueError:
        raise SystemExit(f"{label} must be numeric: {raw!r}")
    if value <= 0:
        raise SystemExit(f"{label} must be positive: {raw!r}")
PY

swift - "$WINDOW_ID" "$WINDOW_SAMPLES" "$CAPTURE_SECONDS" <<'SWIFT' &
import CoreGraphics
import Foundation

let windowNumber = CGWindowID(Int(CommandLine.arguments[1]) ?? 0)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let duration = Double(CommandLine.arguments[3]) ?? 12
let sampleRate = 60.0
let sampleCount = max(1, Int((duration * sampleRate).rounded()))
let start = Date.timeIntervalSinceReferenceDate
var rows = ["t,x,y,w,h"]

for _ in 0..<sampleCount {
    let now = Date.timeIntervalSinceReferenceDate
    if let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[String: Any]],
       let bounds = windows.first?[kCGWindowBounds as String] as? [String: Any],
       let x = bounds["X"] as? Double,
       let y = bounds["Y"] as? Double,
       let width = bounds["Width"] as? Double,
       let height = bounds["Height"] as? Double {
        rows.append(String(format: "%.4f,%.2f,%.2f,%.2f,%.2f", now - start, x, y, width, height))
    }
    Thread.sleep(forTimeInterval: 1.0 / sampleRate)
}

try rows.joined(separator: "\n").write(to: output, atomically: true, encoding: .utf8)
SWIFT
SAMPLE_PID=$!

FRAME_COUNT="$(python3 - "$CAPTURE_SECONDS" "$FRAME_INTERVAL" <<'PY'
import math
import sys

seconds = float(sys.argv[1])
interval = float(sys.argv[2])
print(max(1, int(math.ceil(seconds / interval))))
PY
)"

for ((index = 0; index < FRAME_COUNT; index += 1)); do
  printf -v frame_name 'frame_%04d.png' "$index"
  screencapture -x -o -l "$WINDOW_ID" "$FRAMES_DIR/$frame_name" || true
  sleep "$FRAME_INTERVAL"
done

wait "$SAMPLE_PID"

ffmpeg -hide_banner -loglevel error -y \
  -framerate "$VIDEO_FPS" \
  -pattern_type glob \
  -i "$FRAMES_DIR/frame_*.png" \
  -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
  -pix_fmt yuv420p \
  "$VIDEO_PATH"

ffmpeg -hide_banner -loglevel error -y \
  -i "$VIDEO_PATH" \
  -vf "fps=0.8,scale=240:-1,tile=5x3" \
  -frames:v 1 \
  "$CONTACT_SHEET"

python3 - "$WINDOW_SAMPLES" "$PRESENTATION_LOG" "$FRAMES_DIR" "$OUTPUT_DIR" "$MAX_STEP_LIMIT" <<'PY'
import csv
import glob
import json
import math
import os
import sys
from collections import Counter

samples_path, presentation_path, frames_dir, output_dir, max_step_limit_raw = sys.argv[1:]
max_step_limit = float(max_step_limit_raw)
rows = []
with open(samples_path, newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        rows.append({key: float(value) for key, value in row.items()})

deltas = [
    math.hypot(current["x"] - previous["x"], current["y"] - previous["y"])
    for previous, current in zip(rows, rows[1:])
]
frame_count = len(glob.glob(frames_dir + "/frame_*.png"))
presentation_rows = 0
animation_counts = Counter()
bubble_role_counts = Counter()
bubble_tone_counts = Counter()
max_bubble_count = 0
if os.path.exists(presentation_path):
    with open(presentation_path, encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            presentation_rows += 1
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            animation = row.get("animation")
            if isinstance(animation, str) and animation:
                animation_counts[animation] += 1
            bubbles = row.get("bubbleTexts")
            if isinstance(bubbles, list):
                max_bubble_count = max(max_bubble_count, len(bubbles))
            roles = row.get("bubbleRoles")
            if isinstance(roles, list):
                bubble_role_counts.update(str(role) for role in roles)
            tones = row.get("bubbleTones")
            if isinstance(tones, list):
                bubble_tone_counts.update(str(tone) for tone in tones)

large_steps = sum(1 for delta in deltas if delta > max_step_limit)
review_warnings = []
if max_bubble_count < 3:
    review_warnings.append("multi-bubble sample was not observed")
for expected_animation in ("running-right", "waiting", "review"):
    if animation_counts[expected_animation] == 0:
        review_warnings.append(f"animation sample missing: {expected_animation}")
for expected_tone in ("active", "waiting", "review", "failed"):
    if bubble_tone_counts[expected_tone] == 0:
        review_warnings.append(f"bubble tone missing: {expected_tone}")
if sum(1 for delta in deltas if delta > 0.05) < 24:
    review_warnings.append("autonomous movement sample was too sparse")
if large_steps > 0:
    review_warnings.append("movement jump exceeded max step limit")
design_pass_recommended = bool(review_warnings)
summary = (
    f"capture_dir={output_dir}\n"
    f"video={output_dir}/mimo-window-content.mp4\n"
    f"contact_sheet={output_dir}/mimo-window-contact-sheet.jpg\n"
    f"frames={frame_count}\n"
    f"coord_samples={len(rows)}\n"
    f"travel={sum(deltas):.2f}px\n"
    f"max_step={(max(deltas) if deltas else 0):.2f}px\n"
    f"max_step_limit={max_step_limit:.2f}px\n"
    f"large_steps={large_steps}\n"
    f"presentation_rows={presentation_rows}\n"
    f"max_bubble_count={max_bubble_count}\n"
    f"animation_counts={dict(sorted(animation_counts.items()))}\n"
    f"bubble_role_counts={dict(sorted(bubble_role_counts.items()))}\n"
    f"bubble_tone_counts={dict(sorted(bubble_tone_counts.items()))}\n"
    f"review_warnings={review_warnings}\n"
    f"design_pass_recommended={str(design_pass_recommended).lower()}\n"
)

with open(os.path.join(output_dir, "review-summary.txt"), "w", encoding="utf-8") as handle:
    handle.write(summary)

print(summary, end="")

if frame_count <= 0:
    raise SystemExit("video review captured no frames")
if len(rows) < 90:
    raise SystemExit(f"video review captured too few coordinate samples: {len(rows)}")
if presentation_rows <= 0:
    raise SystemExit("video review captured no presentation log rows")
if large_steps > 0:
    raise SystemExit(f"video review found {large_steps} movement steps over {max_step_limit:.2f}px")
PY
