#!/bin/sh
# Kisayol: sh tools/sim/run.sh [simulator argumanlari]
cd "$(dirname "$0")/../.." || exit 1
"D:/YATAY ZEKA/araclar/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tools/sim/balance_sim.gd -- "$@"
