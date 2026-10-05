"""Generates the Goblin Slot Machine textures and sounds: python tools/gen_goblin.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga
import gen_arcade as arc

W, H = 432, 462


def background():
    w, h = 512, 512
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    u, v = xs / W, ys / H
    base = np.array([0.03, 0.12, 0.07])
    light = np.array([0.08, 0.30, 0.16])
    spot = np.exp(-(((u - 0.5) / 0.6) ** 2 + ((v - 0.45) / 0.7) ** 2))
    rgb = base + (light - base) * spot[..., None]
    rng = np.random.default_rng(23)
    weave = 0.5 + 0.5 * np.sin(xs * 1.7) * np.sin(ys * 1.7)
    rgb = rgb * (0.94 + 0.06 * weave[..., None]) + (rng.random((h, w)) - 0.5)[..., None] * 0.015
    img = arc.to_rgba(rgb)
    dr = ImageDraw.Draw(img, "RGBA")
    gold = (214, 168, 70, 150)
    dr.rectangle([8, 8, W - 9, H - 9], outline=gold, width=2)
    dr.rectangle([14, 14, W - 15, H - 15], outline=(214, 168, 70, 60), width=1)
    for x, y in ((8, 8), (W - 9, 8), (8, H - 9), (W - 9, H - 9)):
        dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(240, 196, 90, 220))
    return img


def tile():
    w, h = 512, 256
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    top, bottom = np.array([0.36, 0.05, 0.06]), np.array([0.12, 0.02, 0.03])
    rgb = top + (bottom - top) * (ys / h)[..., None]
    spot = np.exp(-(((xs - 256) / 260) ** 2 + ((ys - 60) / 160) ** 2))
    rgb = rgb + spot[..., None] * np.array([0.25, 0.08, 0.03])
    img = arc.to_rgba(rgb)
    dr = ImageDraw.Draw(img, "RGBA")
    # Machine body with three reels; the game places real item icons in the windows.
    dr.rounded_rectangle([96, 34, 416, 222], radius=26, fill=(52, 32, 18, 255), outline=(232, 186, 82, 255), width=6)
    for i in range(3):
        x = 122 + i * 92
        dr.rounded_rectangle([x, 70, x + 76, 186], radius=10, fill=(244, 236, 214, 255), outline=(120, 84, 30, 255), width=4)
    dr.rectangle([96, 120, 416, 132], fill=(232, 186, 82, 90))
    for k in range(9):
        cx = 118 + k * 35
        dr.ellipse([cx - 5, 44, cx + 5, 54], fill=(255, 226, 140, 255))
        dr.ellipse([cx - 5, 202, cx + 5, 212], fill=(255, 226, 140, 255))
    dr.line([(430, 80), (466, 80), (466, 150)], fill=(180, 180, 190, 255), width=8)
    dr.ellipse([452, 60, 482, 90], fill=(220, 40, 40, 255), outline=(120, 10, 10, 255), width=3)
    return img.filter(ImageFilter.GaussianBlur(0.5))


def sounds():
    rng = np.random.default_rng(57)
    total = int(ga.RATE * 0.6)
    spin = np.zeros(total)
    for k in range(14):
        click = ga.noise(0.015, rng, 0.5) * ga.env(int(ga.RATE * 0.015), 0.0005, 0.004)
        spin += ga.place(click * (0.6 + 0.4 * rng.random()), k * 0.04, total)
    ga.write_ogg(spin, "spin", 0.5, "goblin")
    stop = ga.mix(ga.tone(220, 0.12, 0.04, ((1, 1.0), (2.4, 0.4))), ga.noise(0.03, rng, 0.3) * 0.4)
    ga.write_ogg(stop, "stop", 0.5, "goblin")
    total = int(ga.RATE * 0.9)
    bell = ga.place(ga.tone(1760, 0.8, 0.25, ((1, 1.0), (2.76, 0.4), (5.4, 0.15))), 0.08, total)
    drawer = ga.place(ga.noise(0.12, rng, 0.2) * ga.env(int(ga.RATE * 0.12), 0.002, 0.05), 0, total)
    ga.write_ogg(bell + drawer, "register", 0.7, "goblin")
    total = int(ga.RATE * 1.4)
    sad = sum(ga.place(ga.sweep(f, f * 0.94, 0.4) * ga.env(int(ga.RATE * 0.4), 0.01, 0.3), i * 0.32, total)
              for i, f in enumerate([392, 370, 349, 330]))
    ga.write_ogg(sad, "bankrupt", 0.6, "goblin")
    ga.write_ogg(ga.tone(2093, 0.08, 0.03, ((1, 1.0), (2.7, 0.3))), "coin", 0.3, "goblin")


def main():
    ga.save_tga(background(), "background", "goblin")
    ga.save_tga(tile(), "goblinslots", "tiles")
    sounds()
    print("Goblin assets generated")


if __name__ == "__main__":
    main()
