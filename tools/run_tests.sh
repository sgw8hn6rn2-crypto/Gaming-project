#!/usr/bin/env bash
# Runs all unit tests headless. Exit code is non-zero on any failure.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=".godot-bin/godot"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s res://tests/run_tests.gd
