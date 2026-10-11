#!/usr/bin/env python3
"""生成内嵌中文字体子集 art/fonts/NotoSansSC-Regular-subset.otf（Web 导出没有系统字体，必须内嵌）。
字符集 = 项目内全部文本（design/data、data、scripts、scenes）+ GB2312 一级常用字 3755 个 + ASCII + 中文标点。
用法：python3 tools/subset_font.py <NotoSansSC-Regular.otf 源文件>
源文件：https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf（SIL OFL 1.1）"""
import glob, os, sys
from fontTools import subset
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1]
chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("　、。，．：；？！“”‘’（）《》〈〉【】「」『』—…·～￥％＋－×÷＝＜＞／０１２３４５６７８９")
for hi in range(0xB0, 0xD8):            # GB2312 一级汉字
    for lo in range(0xA1, 0xFF):
        try:
            chars.add(bytes([hi, lo]).decode("gb2312"))
        except UnicodeDecodeError:
            pass
for pat in ("design/data/*.csv", "data/*.csv", "scripts/**/*.gd", "scenes/**/*.tscn"):
    for p in glob.glob(os.path.join(ROOT, pat), recursive=True):
        chars |= set(open(p, encoding="utf-8").read())
chars = {c for c in chars if c.isprintable() or c == "\u3000"}
opts = subset.Options(); opts.layout_features = ["*"]; opts.name_IDs = ["*"]; opts.notdef_outline = True
font = subset.load_font(src, opts)
sub = subset.Subsetter(opts); sub.populate(text="".join(sorted(chars))); sub.subset(font)
out = os.path.join(ROOT, "art", "fonts", "NotoSansSC-Regular-subset.otf")
subset.save_font(font, out, opts)
print("%d chars → %s (%.2f MB)" % (len(chars), out, os.path.getsize(out) / 1e6))
