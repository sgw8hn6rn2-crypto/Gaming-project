#!/usr/bin/env bash
# Downloads the Godot 4.6.1 Linux binary used for headless tests.
set -euo pipefail
cd "$(dirname "$0")/.."
VER="4.6.1"
DEST=".godot-bin"
if [ -x "$DEST/godot" ]; then exit 0; fi
mkdir -p "$DEST"
URL="https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_linux.x86_64.zip"
curl -fsSL "$URL" -o "$DEST/godot.zip"
unzip -q -o "$DEST/godot.zip" -d "$DEST"
mv "$DEST/Godot_v${VER}-stable_linux.x86_64" "$DEST/godot"
rm "$DEST/godot.zip"
chmod +x "$DEST/godot"
