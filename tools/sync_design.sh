#!/usr/bin/env bash
# 从策划目录重新同步 design/（覆盖），然后：
#  1) 把 tools/local_constants.csv 中策划表尚未包含的前端开关行追加到 design/data/constants.csv
#  2) 为所有 CSV 重建 Godot 的 .import（importer="keep"，导出时原样打包）
# 用法：tools/sync_design.sh [策划目录，默认 /workspace/xxhbgj/design]
set -euo pipefail
SRC="${1:-/workspace/xxhbgj/design}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DST="$ROOT/design"
[ -d "$SRC/data" ] || { echo "missing $SRC/data" >&2; exit 1; }
rm -rf "$DST"
mkdir -p "$DST"
cp -r "$SRC"/. "$DST"/
find "$DST" -name '__pycache__' -prune -exec rm -rf {} +
CONST="$DST/data/constants.csv"
[ -n "$(tail -c1 "$CONST")" ] && echo >> "$CONST"
tail -n +2 "$ROOT/tools/local_constants.csv" | while IFS= read -r line; do
  [ -z "$line" ] && continue
  key="${line%%,*}"
  if ! cut -d, -f1 "$CONST" | grep -qx "$key"; then
    echo "$line" >> "$CONST"
    echo "appended local constant: $key"
  fi
done
find "$DST" -name '*.csv' | while read -r f; do
  printf '[remap]\n\nimporter="keep"\n' > "$f.import"
done
echo "design synced from $SRC"
