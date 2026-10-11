#!/usr/bin/env bash
# 字体子集化（Web 包体）：从 art/final/fonts 原版取字，按项目内实际用到的字符（表格、脚本、场景 + ASCII + 常用中文标点）
# 生成同名子集到 art/fonts/（Theme 按路径引用，不改名）。改表新增文字后重跑本脚本。字体均为 SIL OFL 1.1，无保留字体名。
set -e
cd "$(dirname "$0")/.."
SRC="${FONT_SRC:-../art/final/fonts}"
CH=/tmp/xxhbgj_charset.txt
python3 - "$CH" <<'PY'
import sys, glob
s = set(chr(c) for c in range(0x20, 0x7F))
s |= set("，。、；：？！“”‘’（）【】《》〈〉…—–·　０１２３４５６７８９％＋－×÷／～「」『』")
for pat in ["design/**/*.csv", "data/*.csv", "scripts/**/*.gd", "scenes/**/*.tscn", "design/**/*.md"]:
    for f in glob.glob(pat, recursive=True):
        s |= set(open(f, encoding="utf-8", errors="ignore").read())
s = {c for c in s if c >= " " and c not in "\x7f"}
open(sys.argv[1], "w", encoding="utf-8").write("".join(sorted(s)))
print(len(s), "chars")
PY
# 正文字体（Noto Serif SC）另加 GB2312 一级常用字 3755 个：策划改表加字不必立刻重跑；书法体只取项目实际用字
python3 - "$CH" /tmp/xxhbgj_charset_body.txt <<'PY'
import sys
s = set(open(sys.argv[1], encoding="utf-8").read())
for hi in range(0xB0, 0xD8):
    for lo in range(0xA1, 0xFF):
        try:
            s.add(bytes([hi, lo]).decode("gb2312"))
        except UnicodeDecodeError:
            pass
open(sys.argv[2], "w", encoding="utf-8").write("".join(sorted(s)))
PY
for f in NotoSerifSC-Regular.otf NotoSerifSC-Bold.otf; do
  pyftsubset "$SRC/$f" --text-file=/tmp/xxhbgj_charset_body.txt --output-file="art/fonts/$f" --layout-features='*' --no-hinting --desubroutinize
done
for f in MaShanZheng-Regular.ttf ZhiMangXing-Regular.ttf; do
  pyftsubset "$SRC/$f" --text-file="$CH" --output-file="art/fonts/$f" --layout-features='*' --no-hinting --desubroutinize
done
ls -la art/fonts
