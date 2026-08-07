#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_BASE64="$ROOT_DIR/App/Resources/AppIconSource.base64"
ASSET_ROOT="$ROOT_DIR/App/Resources/Assets.xcassets"
APP_ICON_DIR="$ASSET_ROOT/AppIcon.appiconset"
LAUNCH_LOGO_DIR="$ASSET_ROOT/LaunchLogo.imageset"
TEMP_DIR="$(mktemp -d)"
SOURCE_IMAGE="$TEMP_DIR/source.jpg"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_ICON_DIR" "$LAUNCH_LOGO_DIR"

python3 - "$SOURCE_BASE64" "$SOURCE_IMAGE" <<'PY'
import base64
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
destination.write_bytes(base64.b64decode(source.read_text().strip(), validate=True))
PY

resize() {
  local size="$1"
  local destination="$2"
  /usr/bin/sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$destination" >/dev/null
}

resize 40 "$APP_ICON_DIR/AppIcon-20@2x.png"
resize 60 "$APP_ICON_DIR/AppIcon-20@3x.png"
resize 58 "$APP_ICON_DIR/AppIcon-29@2x.png"
resize 87 "$APP_ICON_DIR/AppIcon-29@3x.png"
resize 80 "$APP_ICON_DIR/AppIcon-40@2x.png"
resize 120 "$APP_ICON_DIR/AppIcon-40@3x.png"
resize 120 "$APP_ICON_DIR/AppIcon-60@2x.png"
resize 180 "$APP_ICON_DIR/AppIcon-60@3x.png"
resize 20 "$APP_ICON_DIR/AppIcon-20.png"
resize 40 "$APP_ICON_DIR/AppIcon-20@2x-ipad.png"
resize 29 "$APP_ICON_DIR/AppIcon-29.png"
resize 58 "$APP_ICON_DIR/AppIcon-29@2x-ipad.png"
resize 40 "$APP_ICON_DIR/AppIcon-40.png"
resize 80 "$APP_ICON_DIR/AppIcon-40@2x-ipad.png"
resize 76 "$APP_ICON_DIR/AppIcon-76.png"
resize 152 "$APP_ICON_DIR/AppIcon-76@2x.png"
resize 167 "$APP_ICON_DIR/AppIcon-83.5@2x.png"
resize 1024 "$APP_ICON_DIR/AppIcon-1024.png"

resize 400 "$LAUNCH_LOGO_DIR/LaunchLogo.png"
resize 800 "$LAUNCH_LOGO_DIR/LaunchLogo@2x.png"
resize 1200 "$LAUNCH_LOGO_DIR/LaunchLogo@3x.png"

for expected in \
  "$APP_ICON_DIR/AppIcon-1024.png" \
  "$APP_ICON_DIR/AppIcon-60@3x.png" \
  "$LAUNCH_LOGO_DIR/LaunchLogo@3x.png"; do
  test -s "$expected"
done

echo "Generated Vertex2 app icons and launch logo from AppIconSource.base64"
