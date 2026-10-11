#!/usr/bin/env python3
"""Web 导出缓存破坏（阶段5）：把导出目录里 index.* 资源（.js/.wasm/.pck/音频 worklet/图标/启动图）改名为 index.<版本>.*，
并改写 index.html 里的全部引用（<script src>、图标、启动图、GODOT_CONFIG.executable 与 fileSizes）。
Godot 加载器按 executable 推出 .wasm/.pck/worklet 的文件名，所以每次构建的请求 URL 都带版本，GitHub Pages 约 10 分钟的缓存不会再拿到旧文件。
index.html 本身不改名（入口地址不变）；版本索引页链接另带 ?v=<版本>（见 tools/build_web.sh --pages）。
用法：tools/web_cachebust.py <导出目录> <版本> [阶段标签]   —— 只处理未加版本的导出（重复执行会报错退出）。
"""
import json, os, re, sys, datetime

def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__); return 2
    d, v = sys.argv[1], sys.argv[2]
    stage = sys.argv[3] if len(sys.argv) > 3 else ""
    if not re.fullmatch(r"[0-9A-Za-z_-]+", v):
        print("bad version", v); return 2
    html_p = os.path.join(d, "index.html")
    html = open(html_p, encoding="utf-8").read()
    if '"executable":"index"' not in html:
        print("index.html 不是未加版本的 Godot 导出（executable 已改过？）"); return 1
    files = sorted(f for f in os.listdir(d) if f.startswith("index.") and f != "index.html")
    renamed = {}
    for f in files:
        nf = "index." + v + f[len("index"):]
        os.rename(os.path.join(d, f), os.path.join(d, nf))
        renamed[f] = nf
    html = html.replace('"executable":"index"', '"executable":"index.%s"' % v)
    for f in sorted(renamed, key=len, reverse=True):
        html = re.sub(r'(["\'])%s\1' % re.escape(f), lambda m: m.group(1) + renamed[f] + m.group(1), html)
    left = re.findall(r'["\']index\.(?!%s)[^"\']*["\']' % re.escape(v), html)
    if left:
        print("仍有未加版本的引用：", left); return 1
    html = html.replace("<head>", '<head>\n<meta name="build-version" content="%s%s">' % ((stage + "@") if stage else "", v), 1)
    open(html_p, "w", encoding="utf-8").write(html)
    json.dump({"stage": stage, "commit": v, "built_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
               "files": sorted(renamed.values())}, open(os.path.join(d, "version.json"), "w"), ensure_ascii=False, indent=1)
    print("cache-busted %d files -> index.%s.*" % (len(renamed), v))
    return 0

if __name__ == "__main__":
    sys.exit(main())
