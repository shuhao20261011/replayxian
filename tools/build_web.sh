#!/usr/bin/env bash
# Web 构建（阶段5 起所有阶段都用这个脚本）：
#  1) 写 build_info.json（阶段 + 短提交号 + 是否有未提交改动 + 构建时间），打进 .pck，HUD 左上角显示版本小字；
#  2) 无头导出 Web（预设 "Web"，无线程版）；
#  3) tools/web_cachebust.py：资源改名 index.<提交号>.*、改写 index.html 引用（缓存破坏）；
#  4) 可选 --pages <gh-pages 目录> <子目录>：拷到版本页 <子目录>/（先清空），并把首页里 href="<子目录>/..." 的链接改成带 ?v=<提交号>。
#  5) 可选 --zip <zip 路径>：把导出目录打成 zip。
# 用法：tools/build_web.sh <阶段标签，如 5> [--out build/web] [--pages ../wt-gh-pages stage5] [--zip ../builds/x.zip]
# 只做本地构建，不推送。build_info.json 已 gitignore，构建后删除（编辑器 / 测试里显示“开发版”）。
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
STAGE="${1:?用法：tools/build_web.sh <阶段标签> [--out DIR] [--pages DIR SUB] [--zip PATH]}"; shift
OUT=build/web; PAGES=""; SUB=""; ZIP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2;;
    --pages) PAGES="$2"; SUB="$3"; shift 3;;
    --zip) ZIP="$2"; shift 2;;
    *) echo "未知参数 $1" >&2; exit 2;;
  esac
done
COMMIT="$(git rev-parse --short=7 HEAD)"
DIRTY=false
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then DIRTY=true; fi
VER="$COMMIT"; $DIRTY && VER="${COMMIT}-dirty"
cleanup() { rm -f build_info.json; }
trap cleanup EXIT
printf '{"stage": "%s", "commit": "%s", "dirty": %s, "built_at": "%s"}\n' "$STAGE" "$COMMIT" "$DIRTY" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build_info.json
rm -rf "$OUT"; mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
python3 tools/web_cachebust.py "$OUT" "$VER" "stage$STAGE"
if [ -n "$PAGES" ]; then
  rm -rf "${PAGES:?}/$SUB"; mkdir -p "$PAGES/$SUB"
  cp -r "$OUT"/. "$PAGES/$SUB"/
  python3 - "$PAGES/index.html" "$SUB" "$VER" <<'PY'
import re, sys
p, sub, v = sys.argv[1:4]
s = open(p, encoding="utf-8").read()
s2, n = re.subn(r'href="%s/(\?v=[^"]*)?"' % re.escape(sub), 'href="%s/?v=%s"' % (sub, v), s)
open(p, "w", encoding="utf-8").write(s2)
print("pages index: %d link(s) -> %s/?v=%s" % (n, sub, v) if n else "WARNING: 首页没有 href=\"%s/\" 的链接，请先加卡片" % sub)
PY
fi
if [ -n "$ZIP" ]; then
  python3 -c "import shutil,sys,os; b=sys.argv[1]; b=b[:-4] if b.endswith('.zip') else b; os.makedirs(os.path.dirname(os.path.abspath(b)), exist_ok=True); print(shutil.make_archive(b, 'zip', sys.argv[2]))" "$ZIP" "$OUT"
fi
echo "web build: stage$STAGE @ $VER -> $OUT"
