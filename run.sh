#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building Pomodoro..."
swift build

APP_DIR=".build/Pomodoro.app/Contents"
mkdir -p "$APP_DIR/MacOS"

cp .build/debug/Pomodoro "$APP_DIR/MacOS/Pomodoro"
cp Pomodoro/Info.plist "$APP_DIR/Info.plist"

# Ad-hoc sign so macOS trusts the app bundle
codesign --force --sign - .build/Pomodoro.app

echo "Launching Pomodoro.app..."
open .build/Pomodoro.app
