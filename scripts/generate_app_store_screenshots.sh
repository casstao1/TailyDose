#!/bin/zsh
set -euo pipefail

ROOT="/Users/castao/Desktop/PetMed/TailyDose"
PROJECT="$ROOT/TailyDose.xcodeproj"
SCHEME="TailyDose"
DERIVED="$ROOT/.codex-screenshots-derived"
OUTDIR="$ROOT/mockups/app-store-screenshots"
DEVICE="iPhone 17"
BUNDLE_ID="com.castao.tailydose"

mkdir -p "$OUTDIR"
rm -rf "$DERIVED"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  build

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/TailyDose.app"

xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP_PATH"

for MODE in home manage share notification; do
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl spawn "$DEVICE" defaults write "$BUNDLE_ID" TAILYDOSE_SCREENSHOT_MODE "$MODE"
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
  sleep 3
  xcrun simctl io "$DEVICE" screenshot "$OUTDIR/${MODE}.png"
done

xcrun simctl spawn "$DEVICE" defaults delete "$BUNDLE_ID" TAILYDOSE_SCREENSHOT_MODE >/dev/null 2>&1 || true
