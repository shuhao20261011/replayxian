#!/usr/bin/env bash
# 无头运行全部自动化测试（需要 PATH 中有 Godot 4.7.2，或设置 GODOT=路径）
set -e
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . res://tests/test_runner.tscn
