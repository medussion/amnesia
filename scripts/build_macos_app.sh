#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PYTHON_BIN=${PYTHON_BIN:-python3}
BUILD_ROOT="$ROOT/.build/amnesia-macos"
DIST_ROOT="$ROOT/dist"
APP="$DIST_ROOT/Amnesia.app"

if ! "$PYTHON_BIN" -c "import PyInstaller" >/dev/null 2>&1; then
  echo "PyInstaller is required. Install it in the build environment first." >&2
  exit 2
fi

rm -rf "$BUILD_ROOT" "$APP" "$DIST_ROOT/Amnesia-macOS.zip"
mkdir -p "$BUILD_ROOT/helper-dist" "$BUILD_ROOT/helper-work" "$BUILD_ROOT/spec" "$DIST_ROOT"

"$PYTHON_BIN" -m PyInstaller --clean --noconfirm --onefile --name amnesia-helper --paths "$ROOT/src" --distpath "$BUILD_ROOT/helper-dist" --workpath "$BUILD_ROOT/helper-work" --specpath "$BUILD_ROOT/spec" "$ROOT/scripts/amnesia_helper.py"

swift build --package-path "$ROOT" --scratch-path "$BUILD_ROOT/swift" -c release
SWIFT_BIN=$(swift build --package-path "$ROOT" --scratch-path "$BUILD_ROOT/swift" -c release --show-bin-path)

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SWIFT_BIN/Amnesia" "$APP/Contents/MacOS/Amnesia"
cp "$BUILD_ROOT/helper-dist/amnesia-helper" "$APP/Contents/Resources/amnesia-helper"
cp "$ROOT/macos/Resources/Info.plist" "$APP/Contents/Info.plist"
chmod 755 "$APP/Contents/MacOS/Amnesia" "$APP/Contents/Resources/amnesia-helper"

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST_ROOT/Amnesia-macOS.zip"
echo "$APP"
