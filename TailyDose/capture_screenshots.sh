#!/usr/bin/env bash
# capture_screenshots.sh
#
# Build TailyDose for the iOS Simulator and capture App Store screenshots
# for AppStoreScreenshotMode scenes (home, manage, share, notification, paywall).
#
# Output: PNGs saved to ./Screenshots/ (override with --output).
# Default device: iPhone 16 Pro Max (6.9", 1290x2796 — required App Store size).
#
# Prerequisites:
#   - macOS with Xcode 16+ installed (`xcode-select -p` must succeed)
#   - The iPhone 16 Pro Max simulator runtime installed
#     (Xcode > Settings > Platforms, or Window > Devices and Simulators)
#   - Run from within the repo (auto-detects TailyDose.xcodeproj)
#
# Usage:
#   ./capture_screenshots.sh
#   ./capture_screenshots.sh --project ../TailyDose.xcodeproj --scheme TailyDose
#   ./capture_screenshots.sh --device "iPhone 16 Pro Max" --output ./Screenshots
#   ./capture_screenshots.sh --modes home,manage        # subset

set -euo pipefail

# ------------------------------ defaults ------------------------------

DEVICE_NAME="iPhone 16 Pro Max"
SCHEME="TailyDose"
CONFIG="Debug"
MODES="home,manage,share,notification,paywall"
PROJECT=""
OUTPUT_DIR=""
LAUNCH_DELAY="4"
KEEP_BUILD="0"

# ------------------------------ arg parsing ------------------------------

print_usage() {
    sed -n '1,25p' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)      PROJECT="$2"; shift 2 ;;
        --scheme)       SCHEME="$2"; shift 2 ;;
        --config)       CONFIG="$2"; shift 2 ;;
        --device)       DEVICE_NAME="$2"; shift 2 ;;
        --modes)        MODES="$2"; shift 2 ;;
        --output)       OUTPUT_DIR="$2"; shift 2 ;;
        --launch-delay) LAUNCH_DELAY="$2"; shift 2 ;;
        --keep-build)   KEEP_BUILD="1"; shift 1 ;;
        -h|--help)      print_usage; exit 0 ;;
        *) echo "unknown flag: $1" >&2; print_usage; exit 2 ;;
    esac
done

# ------------------------------ helpers ------------------------------

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild not found. Install Xcode and run 'xcode-select --install'."
command -v xcrun      >/dev/null 2>&1 || fail "xcrun not found."
command -v plutil     >/dev/null 2>&1 || fail "plutil not found (macOS only script)."

# ------------------------------ locate project ------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_project() {
    local dir candidate
    for dir in "$SCRIPT_DIR" "$SCRIPT_DIR/.." "$PWD" "$PWD/.."; do
        [[ -d "$dir" ]] || continue
        for candidate in "$dir"/*.xcodeproj; do
            [[ -d "$candidate" ]] || continue
            printf '%s\n' "$candidate"
            return 0
        done
    done
    return 1
}

if [[ -z "$PROJECT" ]]; then
    PROJECT="$(find_project)" || fail "could not find a .xcodeproj near $SCRIPT_DIR — pass --project"
fi
[[ -d "$PROJECT" ]] || fail "project not found: $PROJECT"
log "Project: $PROJECT"

# ------------------------------ output dir ------------------------------

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/Screenshots"
fi
mkdir -p "$OUTPUT_DIR"
log "Output:  $OUTPUT_DIR"

# ------------------------------ resolve simulator ------------------------------

log "Looking up simulator '$DEVICE_NAME'..."

# Pick the newest available device matching the name. Piping simctl JSON to python
# keeps us dependency-free (python3 ships with macOS).
DEVICE_UDID="$(xcrun simctl list --json devices available | /usr/bin/python3 -c '
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
best = None
for runtime, devices in data["devices"].items():
    for d in devices:
        if d["name"] == name and d.get("isAvailable", True):
            if best is None or runtime > best[0]:
                best = (runtime, d["udid"])
print(best[1] if best else "")
' "$DEVICE_NAME")"

if [[ -z "$DEVICE_UDID" ]]; then
    log "No simulator named '$DEVICE_NAME' found — creating one..."
    RUNTIME="$(xcrun simctl list --json runtimes | /usr/bin/python3 -c '
import json, sys
rs = json.load(sys.stdin)["runtimes"]
rs = [r for r in rs if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")]
print(sorted(rs, key=lambda r: r["version"])[-1]["identifier"] if rs else "")
')"
    [[ -n "$RUNTIME" ]] || fail "no iOS simulator runtime installed — open Xcode > Settings > Platforms and install iOS 18+."

    # Look up the exact device type identifier instead of guessing — Apple sometimes
    # uses odd casing (e.g. "3rd-generation") that a naive hyphenation would miss.
    DEVICE_TYPE="$(xcrun simctl list --json devicetypes | /usr/bin/python3 -c '
import json, sys
name = sys.argv[1]
types = json.load(sys.stdin)["devicetypes"]
hit = next((t["identifier"] for t in types if t["name"] == name), "")
print(hit)
' "$DEVICE_NAME")"
    [[ -n "$DEVICE_TYPE" ]] || fail "device type for '$DEVICE_NAME' not found — check 'xcrun simctl list devicetypes'"

    DEVICE_UDID="$(xcrun simctl create "TailyDose Screenshot — $DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")"
fi
log "Simulator UDID: $DEVICE_UDID"

# Boot (ignore error if already booted).
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true

# Give the simulator a chance to come up.
xcrun simctl bootstatus "$DEVICE_UDID" -b >/dev/null 2>&1 || true

# Surface the Simulator.app so the user can watch (nice for debugging; harmless if headless).
open -a Simulator 2>/dev/null || true

# ------------------------------ build ------------------------------

BUILD_DIR="$SCRIPT_DIR/.screenshot-build"
log "Building $SCHEME ($CONFIG) into $BUILD_DIR..."

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
    -derivedDataPath "$BUILD_DIR" \
    -quiet \
    build \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

APP_PATH="$(find "$BUILD_DIR/Build/Products/$CONFIG-iphonesimulator" -maxdepth 1 -name "*.app" -type d | head -n 1)"
[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || fail "could not locate built .app under $BUILD_DIR"
log "Built:   $APP_PATH"

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")"
[[ -n "$BUNDLE_ID" ]] || fail "could not read CFBundleIdentifier from $APP_PATH/Info.plist"
log "Bundle:  $BUNDLE_ID"

# ------------------------------ install ------------------------------

log "Installing app on simulator..."
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

# ------------------------------ capture each mode ------------------------------

IFS=',' read -r -a MODE_LIST <<< "$MODES"

for mode in "${MODE_LIST[@]}"; do
    mode="$(echo "$mode" | tr -d '[:space:]')"
    [[ -n "$mode" ]] || continue
    case "$mode" in
        home|manage|share|notification|paywall) ;;
        *) warn "skipping unknown mode: $mode"; continue ;;
    esac

    log "Mode: $mode"
    xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true

    # Launch with the screenshot mode passed BOTH as an env var (SIMCTL_CHILD_*) and as
    # a launch argument. AppStoreScreenshotMode.current reads either form, so this is
    # resilient to any Xcode version quirks.
    SIMCTL_CHILD_TAILYDOSE_SCREENSHOT_MODE="$mode" \
        xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" "TAILYDOSE_SCREENSHOT_MODE=$mode" >/dev/null

    # Give SwiftUI + SwiftData a moment to render the seeded data.
    sleep "$LAUNCH_DELAY"

    OUT="$OUTPUT_DIR/tailydose_${mode}_6.9in.png"
    xcrun simctl io "$DEVICE_UDID" screenshot --type=png "$OUT"
    log "Saved:   $OUT"
done

# ------------------------------ cleanup ------------------------------

xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true

if [[ "$KEEP_BUILD" == "0" ]]; then
    rm -rf "$BUILD_DIR"
    log "Cleaned build artifacts."
fi

log "Done. Screenshots live in: $OUTPUT_DIR"
ls -1 "$OUTPUT_DIR"
