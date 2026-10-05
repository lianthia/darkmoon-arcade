"""Generates the Jewels of Uldum textures and sounds: python tools/gen_uldum.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga
import gen_arcade as arc

W, H = 432, 462


def background():
    w, h = 512, 512
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    t = np.clip(ys / H, 0, 1)[..., None]
    top = np.array([0.07, 0.05, 0.16])
    mid = np.array([0.32, 0.14, 0.24])
    horizon = np.array([0.95, 0.55, 0.25])
    rgb = np.where(t < 0.62, top + (mid - top) * (t / 0.62), mid + (horizon - mid) * np.clip((t - 0.62) / 0.38, 0, 1) ** 1.4)
    img = arc.to_rgba(rgb)
    dr = ImageDraw.Draw(img, "RGBA")
    rng = np.random.default_rng(17)
    for _ in range(90):
        x, y = rng.integers(0, w), rng.integers(0, int(H * 0.55))
        r = rng.random() * 1.2 + 0.3
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(255, 240, 210, int(90 + rng.random() * 150)))
    dr.ellipse([340, 50, 392, 102], fill=(250, 236, 205, 235))
    dr.ellipse([352, 44, 404, 96], fill=(30, 18, 52, 255))
    base = H - 30
    for x0, half, height, col in [(80, 120, 150, (70, 40, 46, 255)), (300, 90, 112, (86, 50, 52, 255)), (430, 60, 74, (98, 58, 56, 255))]:
        dr.polygon([(x0 - half, base), (x0, base - height), (x0 + half, base)], fill=col)
        dr.line([(x0, base - height), (x0 + half, base)], fill=(140, 84, 62, 255), width=2)
    for k, col in enumerate([(122, 72, 48, 255), (150, 92, 56, 255)]):
        pts = [(x, base - 6 + k * 14 - 10 * math.sin(x / 70 + k * 2)) for x in range(0, w + 1, 8)]
        dr.polygon(pts + [(w, h), (0, h)], fill=col)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def prism():
    size = 128
    n = size * ga.SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx = cy = n / 2
    pts = [(cx + math.cos(math.pi / 2 + i * math.pi / 3) * n * 0.42, cy + math.sin(math.pi / 2 + i * math.pi / 3) * n * 0.42) for i in range(6)]
    colors = [(255, 110, 110), (255, 220, 110), (130, 240, 140), (110, 200, 255), (170, 130, 255), (255, 140, 230)]
    for i in range(6):
        dr.polygon([(cx, cy), pts[i], pts[(i + 1) % 6]], fill=colors[i] + (255,))
    dr.polygon(pts, outline=(255, 255, 255, 255), width=n // 40)
    inner = [(cx + (x - cx) * 0.45, cy + (y - cy) * 0.45) for x, y in pts]
    dr.polygon(inner, fill=(255, 255, 255, 200))
    glow = img.filter(ImageFilter.GaussianBlur(n // 40))
    out = Image.alpha_composite(glow, img)
    return out.resize((size, size), Image.LANCZOS)


def board_cell():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([3, 3, size - 4, size - 4], radius=10, fill=(255, 255, 255, 255))
    return img.filter(ImageFilter.GaussianBlur(1))


def tile():
    art = background().crop((0, 120, 512, 376)).resize((512, 256), Image.LANCZOS)
    panel = Image.new("RGBA", (300, 200), (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle([0, 0, 299, 199], radius=14, fill=(14, 8, 24, 170), outline=(219, 168, 77, 230), width=3)
    art.alpha_composite(panel, (190, 28))
    return art


def sounds():
    rng = np.random.default_rng(41)
    n = int(ga.RATE * 0.12)
    swap = ga.noise(0.12, rng, 0.12) * ga.env(n, 0.01, 0.04) * np.sin(np.linspace(0, math.pi, n))
    ga.write_ogg(swap, "swap", 0.4, "uldum")
    base = 523.25
    for i in range(1, 7):
        f = base * 2 ** ((i - 1) * 2 / 12)
        total = int(ga.RATE * 0.5)
        chime = ga.place(ga.tone(f, 0.45, 0.16, ((1, 1.0), (2, 0.4), (3, 0.15), (4.2, 0.08))), 0, total)
        chime += ga.place(ga.tone(f * 1.5, 0.35, 0.12, ((1, 0.5),)), 0.03, total)
        ga.write_ogg(chime, f"match{i}", 0.6, "uldum")
    ga.write_ogg(ga.mix(ga.tone(140, 0.14, 0.05, ((1, 1.0), (2, 0.3))), ga.noise(0.03, rng, 0.3) * 0.3), "invalid", 0.5, "uldum")
    total = int(ga.RATE * 0.8)
    special = sum(ga.place(ga.tone(1046.5 * 2 ** (k / 12 * 3), 0.3, 0.1, ((1, 1.0),)) * 0.6, k * 0.05, total) for k in range(6))
    ga.write_ogg(special, "special", 0.6, "uldum")


def main():
    ga.save_tga(background(), "background", "uldum")
    ga.save_tga(prism(), "prism", "uldum")
    ga.save_tga(board_cell(), "cell", "uldum")
    ga.save_tga(tile(), "jewelsofuldum", "tiles")
    sounds()
    print("Uldum assets generated")


if __name__ == "__main__":
    main()
