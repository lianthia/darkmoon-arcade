"""Generates the Darkmoon Deck textures and sounds: python tools/gen_darkmoondeck.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga
import gen_arcade as arc

W, H = 620, 462
FOLDER = "deck"
CARD_W, CARD_H = 60, 86  # on-screen card size; textures are square and get stretched to it


def table():
    """Purple felt of a fortune teller's table; 1024 wide for the wide playfield."""
    w, h = 1024, 512
    rng = np.random.default_rng(31)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    felt = ga.fbm(h, w, rng, ((64, 0.4), (16, 0.3), (4, 0.3)))
    base = np.array([0.20, 0.07, 0.26])
    rgb = base * (0.8 + 0.35 * felt)[..., None]
    spot = np.exp(-(((xx - W / 2) / 260) ** 2 + ((yy - 250) / 220) ** 2))
    rgb = rgb * (0.55 + 0.65 * spot)[..., None]
    img = arc.to_rgba(rgb)
    dr = ImageDraw.Draw(img, "RGBA")
    # A faint moon emblem in the middle of the table.
    cx, cy = W / 2, 200
    dr.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], outline=(230, 180, 90, 40), width=3)
    # Crescent: the lit side of the moon between two arcs.
    dr.arc([cx - 52, cy - 52, cx + 52, cy + 52], 60, 300, fill=(240, 200, 120, 60), width=3)
    dr.arc([cx - 30, cy - 46, cx + 46, cy + 46], 95, 265, fill=(240, 200, 120, 60), width=3)
    for i in range(24):
        a = i / 24 * math.pi * 2
        r1, r2 = 78, 88 if i % 2 == 0 else 82
        dr.line([(cx + math.cos(a) * r1, cy + math.sin(a) * r1), (cx + math.cos(a) * r2, cy + math.sin(a) * r2)], fill=(230, 180, 90, 50), width=2)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def card_canvas(draw_fn):
    """Draws at the on-screen aspect, then squeezes into a square texture."""
    s = 8
    img = Image.new("RGBA", (CARD_W * s, CARD_H * s), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img), CARD_W * s, CARD_H * s, s)
    return img.resize((128, 128), Image.LANCZOS)


def card_front():
    def draw(dr, w, h, s):
        dr.rounded_rectangle([0, 0, w - 1, h - 1], radius=6 * s, fill=(240, 226, 196, 255), outline=(120, 80, 30, 255), width=s)
        dr.rounded_rectangle([3 * s, 3 * s, w - 3 * s, h - 3 * s], radius=4 * s, outline=(196, 150, 70, 255), width=s // 2 + 1)
    img = card_canvas(draw)
    # Paper grain.
    arr = np.array(img).astype(float)
    rng = np.random.default_rng(5)
    grain = rng.normal(0, 6, arr.shape[:2])
    for c in range(3):
        arr[..., c] = np.clip(arr[..., c] + grain, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def card_back():
    def draw(dr, w, h, s):
        dr.rounded_rectangle([0, 0, w - 1, h - 1], radius=6 * s, fill=(60, 20, 80, 255), outline=(230, 180, 90, 255), width=s)
        dr.rounded_rectangle([4 * s, 4 * s, w - 4 * s, h - 4 * s], radius=4 * s, outline=(230, 180, 90, 160), width=s // 2 + 1)
        cx, cy, r = w / 2, h / 2, 14 * s
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(240, 200, 120, 255))
        dr.ellipse([cx - r + 6 * s, cy - r - 2 * s, cx + r + 6 * s, cy + r - 2 * s], fill=(60, 20, 80, 255))
        for k in range(-3, 4):
            y = cy + k * 10 * s
            dr.line([(8 * s, y), (14 * s, y)], fill=(230, 180, 90, 120), width=s // 2 + 1)
            dr.line([(w - 14 * s, y), (w - 8 * s, y)], fill=(230, 180, 90, 120), width=s // 2 + 1)
    return card_canvas(draw)


def card_glow():
    """Soft rounded halo behind selected cards."""
    def draw(dr, w, h, s):
        pad = 9 * s
        dr.rounded_rectangle([pad, pad, w - pad, h - pad], radius=8 * s, fill=(255, 255, 255, 255))
    s = 8
    img = Image.new("RGBA", (CARD_W * s, CARD_H * s), (0, 0, 0, 0))
    draw(ImageDraw.Draw(img), CARD_W * s, CARD_H * s, s)
    img = img.filter(ImageFilter.GaussianBlur(6 * s))
    return img.resize((128, 128), Image.LANCZOS)


SUIT_COLORS = {
    "beasts": (70, 165, 55),
    "elementals": (235, 110, 30),
    "portals": (140, 80, 220),
    "warlords": (200, 40, 40),
}
OUTLINE = (40, 24, 16, 255)


def suit_symbol(suit, size=64):
    """Bold, clearly different shapes per suit: paw, flame, portal and shield."""
    s = 8
    n = size * s
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    col = SUIT_COLORS[suit] + (255,)
    o = 3 * s

    def shape(points=None, ellipse=None, width=None):
        # Outline first, slightly larger, then the colored fill on top.
        if ellipse:
            x0, y0, x1, y1 = ellipse
            dr.ellipse([x0 - o, y0 - o, x1 + o, y1 + o], fill=OUTLINE)
        if points:
            dr.polygon(points, fill=OUTLINE)
            dr.line(points + [points[0]], fill=OUTLINE, width=o * 2, joint="curve")

    if suit == "beasts":
        pad = [n * 0.27, n * 0.46, n * 0.73, n * 0.86]
        toes = [[n * 0.12, n * 0.30, n * 0.30, n * 0.52], [n * 0.30, n * 0.10, n * 0.48, n * 0.36],
                [n * 0.52, n * 0.10, n * 0.70, n * 0.36], [n * 0.70, n * 0.30, n * 0.88, n * 0.52]]
        for e in [pad] + toes:
            shape(ellipse=e)
        for e in [pad] + toes:
            dr.ellipse(e, fill=col)
    elif suit == "elementals":
        def flame(scale, dy):
            # Round belly at the bottom, sides sweeping up into a curled tip.
            cx, cy, r = n / 2, n * 0.64 + dy, n * 0.26 * scale
            pts = [(cx + math.cos(t) * r, cy + math.sin(t) * r) for t in [i / 30 * math.pi for i in range(31)]]
            tip = (cx + n * 0.08 * scale, cy - n * 0.56 * scale)
            left = [(cx - r + (tip[0] - cx + r) * k ** 1.6, cy + (tip[1] - cy) * k) for k in [i / 12 for i in range(1, 12)]]
            right = [(tip[0] + (cx + r - tip[0]) * (1 - k) ** 0.8, tip[1] + (cy - tip[1]) * (1 - k)) for k in [i / 12 for i in range(1, 12)]]
            return pts + left + [tip] + right
        outer = flame(1.0, 0)
        shape(points=outer)
        dr.polygon(outer, fill=col)
        dr.polygon(flame(0.5, n * 0.1), fill=(255, 210, 90, 255))
    elif suit == "portals":
        box = [n * 0.12, n * 0.12, n * 0.88, n * 0.88]
        shape(ellipse=box)
        dr.ellipse(box, fill=col)
        dr.ellipse([n * 0.28, n * 0.28, n * 0.72, n * 0.72], fill=(60, 25, 100, 255))
        for k in range(3):
            a0 = k * 120
            dr.arc([n * 0.2, n * 0.2, n * 0.8, n * 0.8], a0, a0 + 70, fill=(220, 190, 255, 255), width=4 * s)
        dr.ellipse([n * 0.42, n * 0.42, n * 0.58, n * 0.58], fill=(230, 210, 255, 255))
    elif suit == "warlords":
        # A heater shield with a pale cross.
        pts = [(n * 0.18, n * 0.14), (n * 0.82, n * 0.14)]
        for i in range(1, 21):
            t = i / 20
            pts.append((n * 0.82 - n * 0.32 * t ** 2, n * 0.14 + n * 0.74 * t))
        for i in range(19, 0, -1):
            t = i / 20
            pts.append((n * 0.18 + n * 0.32 * t ** 2, n * 0.14 + n * 0.74 * t))
        shape(points=pts)
        dr.polygon(pts, fill=col)
        dr.rectangle([n * 0.45, n * 0.2, n * 0.55, n * 0.74], fill=(245, 220, 160, 255))
        dr.rectangle([n * 0.26, n * 0.34, n * 0.74, n * 0.44], fill=(245, 220, 160, 255))
    return img.resize((size, size), Image.LANCZOS)


def tile():
    art = table().crop((94, 60, 526, 276)).resize((512, 256), Image.LANCZOS)
    front, back = card_front(), card_back()
    colors = [(110, 210, 90), (255, 150, 60), (190, 120, 255), (255, 90, 90)]
    for i, angle in enumerate([-18, -6, 6, 18]):
        card = (front if i < 3 else back).resize((84, 120), Image.LANCZOS)
        if i < 3:
            dr = ImageDraw.Draw(card)
            dr.ellipse([30, 48, 54, 72], fill=colors[i] + (255,))
        rotated = card.rotate(-angle, expand=True, resample=Image.BICUBIC)
        art.alpha_composite(rotated, (196 + i * 46 - rotated.width // 2 + 40, 70 - abs(angle) + 10))
    return arc.tile_canvas(art)


def sounds():
    rng = np.random.default_rng(17)
    n = int(ga.RATE * 0.09)
    flick = ga.noise(0.09, rng, 0.5) * ga.env(n, 0.002, 0.025)
    ga.write_ogg(flick, "deal", 0.45, FOLDER)
    ga.write_ogg(ga.tone(1400, 0.08, 0.02, ((1, 1.0), (2.5, 0.3))), "select", 0.3, FOLDER)
    for i in range(1, 6):
        f = 523.25 * 2 ** ((i - 1) * 2 / 12)
        ga.write_ogg(ga.tone(f, 0.25, 0.07, ((1, 1.0), (3, 0.2))), f"chip{i}", 0.45, FOLDER)
    bell = ga.tone(220, 0.6, 0.25, ((1, 1.0), (2.01, 0.6), (3.98, 0.3)))
    ga.write_ogg(bell, "mult", 0.6, FOLDER)
    total = int(ga.RATE * 0.5)
    shuffle = sum(ga.place(ga.noise(0.05, rng, 0.5) * ga.env(int(ga.RATE * 0.05), 0.002, 0.015), k * 0.035, total) for k in range(12))
    ga.write_ogg(shuffle, "shuffle", 0.4, FOLDER)


def main():
    ga.save_tga(table(), "table", FOLDER)
    ga.save_tga(card_front(), "front", FOLDER)
    ga.save_tga(card_back(), "back", FOLDER)
    ga.save_tga(card_glow(), "glow", FOLDER)
    for suit in SUIT_COLORS:
        ga.save_tga(suit_symbol(suit), "suit_" + suit, FOLDER)
    ga.save_tga(tile(), "darkmoondeck", "tiles")
    sounds()
    print("Darkmoon Deck assets generated")


if __name__ == "__main__":
    main()
