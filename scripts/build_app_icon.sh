#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE=${1:-"$ROOT/macos/Resources/AppIcon.png"}
OUTPUT=${2:-"$ROOT/macos/Resources/Amnesia.icns"}
ICONSET=$(mktemp -d "${TMPDIR:-/tmp}/amnesia-iconset.XXXXXX")/Amnesia.iconset

cleanup() {
  rm -rf "$(dirname "$ICONSET")"
}
trap cleanup EXIT INT TERM

mkdir -p "$ICONSET"

render() {
  size=$1
  name=$2
  sips --resampleHeightWidth "$size" "$size" "$SOURCE" --out "$ICONSET/$name" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

mkdir -p "$(dirname "$OUTPUT")"
python3 "$ROOT/scripts/pack_icns.py" "$ICONSET" "$OUTPUT"
echo "$OUTPUT"
