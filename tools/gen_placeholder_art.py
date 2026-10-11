#!/usr/bin/env python3
"""生成占位美术（按 docs/style_guide.md 第5节规格与命名规范）。

美术正在重做：正式资源到位后，按同名文件直接覆盖 art/ 下的 PNG 即可，代码无需修改。
运行：python3 tools/gen_placeholder_art.py   （需要 Pillow；中文图标用 Noto CJK 字体，找不到则只画色块）
"""
import os, glob
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
INK = (28, 30, 33, 255)          # 浓墨 #1C1E21
CINNABAR = (184, 56, 44, 255)    # 朱砂 #B8382C

def font(size):
    for p in glob.glob("/usr/share/fonts/**/NotoSansCJK*Bold*.tt*", recursive=True) + \
             glob.glob("/usr/share/fonts/**/NotoSansCJK*.tt*", recursive=True) + \
             glob.glob("C:/Windows/Fonts/msyh*.tt*"):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return None

def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)

def hex2rgba(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

# ---------- 主角 320x192，锚点(144,184) ----------
def hero():
    im = Image.new("RGBA", (320, 192), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    fx, fy = 144, 184
    d.ellipse([fx - 14, fy - 158, fx + 14, fy - 130], fill=INK)               # 头
    d.polygon([(fx - 18, fy - 128), (fx + 18, fy - 128), (fx + 30, fy - 40), (fx - 30, fy - 40)], fill=INK)  # 袍
    d.line([(fx - 10, fy - 42), (fx - 22, fy)], fill=INK, width=10)            # 腿
    d.line([(fx + 10, fy - 42), (fx + 24, fy)], fill=INK, width=10)
    d.line([(fx + 12, fy - 110), (fx + 60, fy - 96)], fill=INK, width=8)       # 手臂
    d.line([(fx + 58, fy - 98), (fx + 150, fy - 120)], fill=INK, width=4)      # 剑
    d.line([(fx - 16, fy - 116), (fx - 90, fy - 100), (fx - 120, fy - 84)], fill=CINNABAR, width=5)  # 朱砂披帛
    d.line([(fx - 8, fy - 150), (fx - 50, fy - 146)], fill=CINNABAR, width=3)   # 发带
    save(im, "characters/chr_hero_idle_01f.png")

# ---------- 普通怪 256x160（人形 192x192），锚点(128,152) ----------
ENEMIES = {
    # id: (size, eye_color, kind)
    "bamboo_imp": ((192, 192), "#FF5A3C", "humanoid"),
    "mountain_ape": ((256, 160), "#FF5A3C", "beast"),
    "marsh_wisp": ((256, 160), "#BFD3FF", "wisp"),
    "thunder_toad": ((256, 160), "#BFD3FF", "toad"),
    "cave_bat": ((256, 160), "#FF7A2E", "bat"),
    "rock_golem": ((192, 192), "#FF7A2E", "golem"),
}

def enemy(name, size, eye, kind):
    w, h = size
    im = Image.new("RGBA", size, (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    ax, ay = w // 2, h - 8
    e = hex2rgba(eye)
    if kind == "humanoid":
        d.ellipse([ax - 16, ay - 120, ax + 16, ay - 88], fill=INK)
        d.polygon([(ax - 22, ay - 88), (ax + 22, ay - 88), (ax + 26, ay - 30), (ax - 26, ay - 30)], fill=INK)
        d.line([(ax - 10, ay - 32), (ax - 18, ay)], fill=INK, width=9); d.line([(ax + 10, ay - 32), (ax + 18, ay)], fill=INK, width=9)
        d.line([(ax - 20, ay - 80), (ax - 70, ay - 60)], fill=INK, width=6)
        d.ellipse([ax - 10, ay - 110, ax - 2, ay - 102], fill=e)
    elif kind == "golem":
        d.rectangle([ax - 50, ay - 150, ax + 50, ay - 40], fill=INK)
        d.rectangle([ax - 40, ay - 40, ax - 12, ay], fill=INK); d.rectangle([ax + 12, ay - 40, ax + 40, ay], fill=INK)
        d.rectangle([ax - 85, ay - 140, ax - 50, ay - 60], fill=INK)
        d.ellipse([ax - 30, ay - 130, ax - 16, ay - 116], fill=e)
        d.line([(ax - 10, ay - 100), (ax + 20, ay - 70), (ax + 5, ay - 50)], fill=e, width=3)
    elif kind == "wisp":
        d.ellipse([ax - 40, ay - 110, ax + 40, ay - 30], fill=INK)
        d.polygon([(ax - 40, ay - 70), (ax + 40, ay - 70), (ax + 60, ay - 10), (ax, ay - 30), (ax - 20, ay)], fill=INK)
        d.ellipse([ax - 24, ay - 86, ax - 10, ay - 72], fill=e); d.ellipse([ax + 2, ay - 86, ax + 16, ay - 72], fill=e)
    elif kind == "toad":
        d.ellipse([ax - 80, ay - 80, ax + 80, ay], fill=INK)
        d.ellipse([ax - 70, ay - 100, ax - 30, ay - 60], fill=INK)
        d.ellipse([ax - 60, ay - 92, ax - 46, ay - 78], fill=e)
    elif kind == "bat":
        d.polygon([(ax, ay - 90), (ax - 110, ay - 130), (ax - 60, ay - 70), (ax, ay - 50), (ax + 60, ay - 70), (ax + 110, ay - 130)], fill=INK)
        d.ellipse([ax - 20, ay - 100, ax + 20, ay - 50], fill=INK)
        d.ellipse([ax - 14, ay - 88, ax - 4, ay - 78], fill=e)
    else:  # beast
        d.ellipse([ax - 80, ay - 100, ax + 70, ay - 30], fill=INK)
        d.ellipse([ax - 110, ay - 120, ax - 50, ay - 60], fill=INK)
        for x in (-60, -30, 20, 50):
            d.line([(ax + x, ay - 40), (ax + x - 6, ay)], fill=INK, width=12)
        d.ellipse([ax - 96, ay - 104, ax - 82, ay - 90], fill=e)
    save(im, "enemies/enm_%s_idle_01f.png" % name)

# ---------- 首领 320x320，锚点(160,308) ----------
BOSSES = {"zhumei": "#FF5A3C", "kuiniu": "#BFD3FF", "yanmo": "#FF7A2E"}

def boss(name, eye):
    im = Image.new("RGBA", (320, 320), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    ax, ay = 160, 308; e = hex2rgba(eye)
    d.ellipse([ax - 36, ay - 270, ax + 36, ay - 200], fill=INK)
    d.polygon([(ax - 60, ay - 205), (ax + 60, ay - 205), (ax + 90, ay - 60), (ax - 90, ay - 60)], fill=INK)
    d.rectangle([ax - 60, ay - 60, ax - 20, ay], fill=INK); d.rectangle([ax + 20, ay - 60, ax + 60, ay], fill=INK)
    d.line([(ax - 55, ay - 190), (ax - 140, ay - 120)], fill=INK, width=22)
    d.line([(ax - 40, ay - 260), (ax - 80, ay - 300)], fill=INK, width=8); d.line([(ax + 40, ay - 260), (ax + 80, ay - 300)], fill=INK, width=8)
    d.ellipse([ax - 26, ay - 248, ax - 8, ay - 230], fill=e); d.ellipse([ax + 4, ay - 248, ax + 22, ay - 230], fill=e)
    save(im, "bosses/boss_%s_idle_01f.png" % name)

# ---------- 背景：远景1280x720 / 中景2560x720 / 地面2560x160（地平线 y=585） ----------
MAPS = {
    "qingzhu": ("#DDE7D9", "#6E9A82", "#2E5A48", "#FBF6E4"),
    "leize": ("#2C3150", "#5D6699", "#1E2138", "#C9D6FF"),
    "xuanyan": ("#1F1614", "#4A3631", "#140E0D", "#E8692F"),
}

def bg(name, pal):
    sky, main, dark, accent = [hex2rgba(c) for c in pal]
    far = Image.new("RGBA", (1280, 720), sky); d = ImageDraw.Draw(far)
    for i in range(0, 720, 8):  # 简单竖向渐变（底部偏亮/偏点缀色）
        t = i / 720.0
        c = tuple(int(sky[k] * (1 - t * 0.35) + accent[k] * t * 0.35) for k in range(3)) + (255,)
        d.rectangle([0, i, 1280, i + 8], fill=c)
    for k, (x, hgt) in enumerate([(120, 300), (420, 360), (760, 280), (1080, 340)]):
        col = tuple(int(main[j] * 0.6 + sky[j] * 0.4) for j in range(3)) + (255,)
        d.polygon([(x - 300, 585), (x, 585 - hgt), (x + 300, 585)], fill=col)
    save(far, "bg/%s/bg_%s_far.png" % (name, name))
    mid = Image.new("RGBA", (2560, 720), (0, 0, 0, 0)); d = ImageDraw.Draw(mid)
    for x in range(-100, 2660, 320):
        d.polygon([(x - 200, 600), (x, 360 + (x * 37) % 120), (x + 200, 600)], fill=main[:3] + (200,))
    save(mid, "bg/%s/bg_%s_mid.png" % (name, name))
    gr = Image.new("RGBA", (2560, 160), dark); d = ImageDraw.Draw(gr)
    for x in range(0, 2560, 64):
        d.line([(x, 0), (x + 20, 12)], fill=main, width=3)
    save(gr, "bg/%s/bg_%s_ground.png" % (name, name))

# ---------- 技能图标 64x64 ----------
SKILLS = {
    "sk_sword_flying": ("飞", "#7FD3FF"), "sk_sword_combo": ("连", "#7FD3FF"), "sk_sword_pierce": ("破", "#7FD3FF"),
    "sk_sword_execute": ("诛", "#7FD3FF"), "sk_sword_passive": ("心", "#7FD3FF"),
    "sk_thunder_strike": ("雷", "#C9A2FF"), "sk_thunder_cloud": ("云", "#C9A2FF"), "sk_thunder_palm": ("掌", "#C9A2FF"),
    "sk_thunder_nine": ("霄", "#C9A2FF"), "sk_thunder_passive": ("引", "#C9A2FF"),
    "sk_gang_guard": ("护", "#FFD27F"), "sk_gang_quake": ("震", "#FFD27F"), "sk_gang_gale": ("罡", "#FFD27F"),
    "sk_gang_vajra": ("刚", "#FFD27F"), "sk_gang_passive": ("玄", "#FFD27F"),
}

def icon(sid, ch, color):
    im = Image.new("RGBA", (64, 64), (27, 29, 32, 255)); d = ImageDraw.Draw(im)
    c = hex2rgba(color)
    d.rounded_rectangle([3, 3, 60, 60], radius=8, outline=c, width=3)
    f = font(36)
    if f:
        d.text((32, 32), ch, font=f, fill=c, anchor="mm")
    else:
        d.ellipse([16, 16, 48, 48], fill=c)
    save(im, "ui/ui_icon_skill_%s.png" % sid.replace("sk_", ""))

# ---------- 特效 ----------
def fx():
    im = Image.new("RGBA", (96, 24), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(0, 12), (20, 6), (90, 10), (96, 12), (90, 14), (20, 18)], fill=hex2rgba("#7FE0FF"))
    d.line([(18, 12), (90, 12)], fill=(255, 255, 255, 255), width=2)
    save(im, "fx/fx_sword_blade_01f.png")
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for r in range(32, 0, -2):
        a = int(255 * (1 - r / 32.0) ** 1.5)
        d.ellipse([32 - r, 32 - r, 32 + r, 32 + r], fill=(255, 255, 255, a))
    save(im, "fx/fx_glow_01f.png")

if __name__ == "__main__":
    hero()
    for k, (s, e, kind) in ENEMIES.items():
        enemy(k, s, e, kind)
    for k, e in BOSSES.items():
        boss(k, e)
    for k, p in MAPS.items():
        bg(k, p)
    for k, (ch, c) in SKILLS.items():
        icon(k, ch, c)
    fx()
    print("placeholder art written to", os.path.normpath(ROOT))
