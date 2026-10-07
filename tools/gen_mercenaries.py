"""Generates the Mercenaries textures and sounds: python tools/gen_mercenaries.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga
import gen_arcade as arc

FOLDER = "mercs"
W, H = 840, 560
SS = 4
ROLE_COLORS = {
    "protector": (0.86, 0.2, 0.16),
    "fighter": (0.28, 0.74, 0.22),
    "caster": (0.22, 0.48, 0.96),
    "neutral": (0.62, 0.62, 0.62),
}
TOKEN_W, TOKEN_H = 128, 160
# The portrait window inside a token.
OVAL_CX, OVAL_CY, OVAL_RX, OVAL_RY = 64, 70, 44, 56


def supersampled(w, h, draw_fn, mode="RGBA"):
    img = Image.new(mode, (w * SS, h * SS), (0, 0, 0, 0) if mode == "RGBA" else 0)
    draw_fn(ImageDraw.Draw(img), SS)
    return img.resize((w, h), Image.LANCZOS)


def overlay(img, draw_fn):
    """Draws translucent shapes on a layer and blends it over `img` (drawing directly would
    overwrite the alpha channel)."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return Image.alpha_composite(img, layer)


def ellipse_mask(w, h, cx, cy, rx, ry):
    def draw(dr, s):
        dr.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=255)
    return np.asarray(supersampled(w, h, draw, "L")).astype(float) / 255


def vertical(h, w, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None] * np.ones((1, w, 1))
    return np.array(top) * (1 - t) + np.array(bottom) * t


def board():
    """Stone arena on a dark wooden table, lit from the middle; tinted per zone in game."""
    size = 1024
    rng = np.random.default_rng(11)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    grain = ga.fbm(size, size, rng, ((96, 0.45), (32, 0.3), (8, 0.25)))
    rgb = np.array([0.42, 0.37, 0.30]) * (0.75 + 0.45 * grain)[..., None]
    light = np.exp(-(((xx - W / 2) / 420) ** 2 + ((yy - H / 2) / 300) ** 2))
    rgb = rgb * (0.45 + 0.75 * light)[..., None]
    # Carved rim around the arena.
    inner = arc.rounded_rect_alpha(W, H, 40, inset=14)
    rim = np.zeros((size, size))
    rim[:H, :W] = 1 - inner
    rgb = rgb * (1 - 0.45 * rim[..., None])
    stones = [(rng.uniform(40, W - 40), rng.uniform(40, H - 40), rng.uniform(14, 34)) for _ in range(70)]

    def draw(dr):
        # A worn line splits the two sides; faint flagstones break up the floor.
        for x in range(60, W - 60, 22):
            dr.line([(x, H / 2 - 4), (x + 12, H / 2 - 4)], fill=(255, 230, 180, 30), width=2)
        for cx, cy, r in stones:
            dr.ellipse([cx - r, cy - r * 0.6, cx + r, cy + r * 0.6], outline=(0, 0, 0, 26), width=2)
    return overlay(arc.to_rgba(rgb), draw).filter(ImageFilter.GaussianBlur(0.8))


def plate_alpha():
    return arc.rounded_rect_alpha(TOKEN_W, TOKEN_H, 34, inset=4)


def token_frame(role, boss=False):
    """Stone plate with an oval window, ringed in the role's colour; bosses wear gold."""
    color = np.array(ROLE_COLORS[role])
    rng = np.random.default_rng(3)
    plate = plate_alpha()
    oval = ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY, OVAL_RX, OVAL_RY)
    ring_outer = ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY, OVAL_RX + 9, OVAL_RY + 9)
    gold_outer = ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY, OVAL_RX + 11, OVAL_RY + 11)
    grain = ga.fbm(TOKEN_H, TOKEN_W, rng, ((24, 0.5), (8, 0.3), (3, 0.2)))
    stone = vertical(TOKEN_H, TOKEN_W, (0.30, 0.27, 0.25), (0.14, 0.12, 0.11)) * (0.8 + 0.35 * grain)[..., None]
    shade = vertical(TOKEN_H, TOKEN_W, (1.25, 1.25, 1.25), (0.7, 0.7, 0.7))
    ring_rgb = color * shade
    if boss:
        ring_rgb = vertical(TOKEN_H, TOKEN_W, (1.0, 0.86, 0.42), (0.62, 0.38, 0.1))
    gold = vertical(TOKEN_H, TOKEN_W, (1.0, 0.88, 0.5), (0.55, 0.36, 0.1))
    rgb = stone.copy()
    gold_band = np.clip(gold_outer - ring_outer, 0, 1)[..., None]
    rgb = rgb * (1 - gold_band) + gold * gold_band
    ring = np.clip(ring_outer - oval, 0, 1)[..., None]
    rgb = rgb * (1 - ring) + ring_rgb * ring
    # Thin dark lip inside the window.
    lip = np.clip(oval - ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY, OVAL_RX - 2, OVAL_RY - 2), 0, 1)
    rgb = rgb * (1 - 0.6 * lip[..., None])
    alpha = np.clip(plate - oval + lip * 0.6, 0, 1)
    # Plate edge in gold.
    edge = np.clip(plate - arc.rounded_rect_alpha(TOKEN_W, TOKEN_H, 31, inset=7), 0, 1)[..., None]
    rgb = rgb * (1 - edge) + gold * edge
    img = arc.to_rgba(rgb, alpha)
    if boss:
        # A crown of spikes over the window.
        def crown(dr, s):
            for k in range(-2, 3):
                x = OVAL_CX + k * 15
                tip = 2 if k == 0 else 7 + abs(k) * 2
                dr.polygon([((x - 7) * s, 22 * s), (x * s, tip * s), ((x + 7) * s, 22 * s)], fill=(250, 210, 90, 255),
                           outline=(120, 70, 10, 255))
        img = Image.alpha_composite(img, supersampled(TOKEN_W, TOKEN_H, crown))
    return img


def token_back():
    """Fills the portrait window behind the model."""
    oval = ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY, OVAL_RX + 1, OVAL_RY + 1)
    yy, xx = np.mgrid[0:TOKEN_H, 0:TOKEN_W].astype(float)
    d = np.sqrt(((xx - OVAL_CX) / OVAL_RX) ** 2 + ((yy - OVAL_CY + 20) / OVAL_RY) ** 2)
    rgb = np.array([0.24, 0.26, 0.32]) * (1.1 - 0.6 * np.clip(d, 0, 1))[..., None]
    return arc.to_rgba(rgb, oval)


def token_glow():
    oval = ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY + 4, OVAL_RX + 16, OVAL_RY + 20)
    blurred = np.asarray(Image.fromarray((oval * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9))).astype(float) / 255
    inner = ellipse_mask(TOKEN_W, TOKEN_H, OVAL_CX, OVAL_CY, OVAL_RX + 4, OVAL_RY + 4)
    return arc.to_rgba(np.ones((TOKEN_H, TOKEN_W, 3)), np.clip(blurred * (1 - inner * 0.7) * 1.4, 0, 1))


def taunt():
    """Stone shield standing behind a taunting token."""
    def draw(dr, s):
        pts = [(10, 18), (64, 4), (118, 18), (116, 96), (64, 156), (12, 96)]
        dr.polygon([(x * s, y * s) for x, y in pts], fill=(150, 146, 140, 255), outline=(70, 66, 62, 255))
        inner = [(20, 26), (64, 14), (108, 26), (106, 92), (64, 144), (22, 92)]
        dr.line([(x * s, y * s) for x, y in inner + inner[:1]], fill=(200, 196, 188, 255), width=3 * s)
    img = supersampled(TOKEN_W, TOKEN_H, draw)
    arr = np.array(img).astype(float)
    rng = np.random.default_rng(8)
    grain = ga.fbm(TOKEN_H, TOKEN_W, rng, ((16, 0.6), (4, 0.4)))
    arr[..., :3] *= (0.75 + 0.4 * grain)[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def divine():
    """Golden bubble of a divine shield."""
    yy, xx = np.mgrid[0:TOKEN_H, 0:TOKEN_W].astype(float)
    d = np.sqrt(((xx - OVAL_CX) / (OVAL_RX + 14)) ** 2 + ((yy - OVAL_CY - 4) / (OVAL_RY + 16)) ** 2)
    alpha = np.where(d < 1, 0.18 + 0.75 * d ** 6, 0) * (1 - ga.smoothstep(0.96, 1.0, d))
    rgb = np.ones((TOKEN_H, TOKEN_W, 3)) * np.array([1.0, 0.9, 0.45])
    return arc.to_rgba(rgb, alpha)


def badge(kind):
    """Attack (gold sword coin), health (red drop), speed (pale clock gem), level (dark gem)."""
    size = 64

    def draw(dr, s):
        if kind == "health":
            pts = []
            for i in range(64):
                a = i / 64 * 2 * math.pi
                r = 26
                x, y = 32 + r * math.sin(a), 36 - r * math.cos(a) * (1.25 if math.cos(a) > 0 else 1)
                pts.append((x * s, y * s))
            dr.polygon(pts, fill=(80, 8, 8, 255))
            inner = [(32 + (x / s - 32) * 0.86) * s for x, _ in pts]
            dr.polygon([(ix, (36 + (y / s - 36) * 0.86) * s) for ix, (_, y) in zip(inner, pts)], fill=(214, 36, 30, 255))
        else:
            fill = {"attack": (238, 170, 30, 255), "speed": (232, 232, 220, 255), "level": (40, 34, 44, 255)}[kind]
            rim = {"attack": (110, 60, 10, 255), "speed": (70, 70, 90, 255), "level": (220, 170, 70, 255)}[kind]
            dr.ellipse([5 * s, 5 * s, 59 * s, 59 * s], fill=rim)
            dr.ellipse([10 * s, 10 * s, 54 * s, 54 * s], fill=fill)
            if kind == "attack":
                # A faint sword behind the number.
                dr.polygon([(30 * s, 12 * s), (34 * s, 12 * s), (35 * s, 44 * s), (32 * s, 48 * s), (29 * s, 44 * s)], fill=(250, 210, 90, 255))
                dr.rectangle([22 * s, 42 * s, 42 * s, 45 * s], fill=(250, 210, 90, 255))
            if kind == "speed":
                for k in range(12):
                    a = k / 12 * 2 * math.pi
                    dr.line([((32 + 19 * math.sin(a)) * s, (32 - 19 * math.cos(a)) * s),
                             ((32 + 22 * math.sin(a)) * s, (32 - 22 * math.cos(a)) * s)], fill=(150, 150, 170, 255), width=s)
    img = supersampled(size, size, draw)
    # Soft top light.
    arr = np.array(img).astype(float)
    yy = np.linspace(1.15, 0.8, size)[:, None]
    arr[..., :3] *= yy[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


CARD_W, CARD_H = 128, 176


def ability_card():
    """Dark card with a gold rim and a square window for the ability's icon."""
    rng = np.random.default_rng(21)
    outer = arc.rounded_rect_alpha(CARD_W, CARD_H, 12, inset=2)
    inner = arc.rounded_rect_alpha(CARD_W, CARD_H, 9, inset=6)
    grain = ga.fbm(CARD_H, CARD_W, rng, ((16, 0.6), (4, 0.4)))
    body = vertical(CARD_H, CARD_W, (0.22, 0.17, 0.24), (0.09, 0.07, 0.11)) * (0.85 + 0.3 * grain)[..., None]
    gold = vertical(CARD_H, CARD_W, (1.0, 0.86, 0.48), (0.6, 0.38, 0.1))
    ring = np.clip(outer - inner, 0, 1)[..., None]
    rgb = body * (1 - ring) + gold * ring
    def draw(dr):
        # Icon window and name banner.
        dr.rectangle([10, 86, CARD_W - 11, 104], fill=(0, 0, 0, 110))
        dr.rectangle([31, 15, 96, 80], outline=(230, 190, 100, 255), width=2)
    return overlay(arc.to_rgba(rgb, outer), draw)


def card_glow():
    outer = arc.rounded_rect_alpha(CARD_W, CARD_H, 16, inset=0)
    blurred = np.asarray(Image.fromarray((outer * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(float) / 255
    inner = arc.rounded_rect_alpha(CARD_W, CARD_H, 12, inset=8)
    return arc.to_rgba(np.ones((CARD_H, CARD_W, 3)), np.clip(blurred * (1 - inner) * 2, 0, 1))


def circle_mask():
    m = ellipse_mask(64, 64, 32, 32, 29, 29)
    return arc.to_rgba(np.ones((64, 64, 3)), m)


def node_ring():
    """Gold rim of a stop on the bounty map; the stop's icon shows through the middle."""
    outer = ellipse_mask(64, 64, 32, 32, 31, 31)
    inner = ellipse_mask(64, 64, 32, 32, 26, 26)
    ring = np.clip(outer - inner, 0, 1)
    gold = vertical(64, 64, (1.0, 0.9, 0.55), (0.55, 0.34, 0.08))
    lip = np.clip(inner - ellipse_mask(64, 64, 32, 32, 24, 24), 0, 1)
    rgb = gold * (1 - lip[..., None]) * 1.0
    return arc.to_rgba(rgb, np.clip(ring + lip * 0.8, 0, 1))


def node_glow():
    m = ellipse_mask(64, 64, 32, 32, 30, 30)
    blurred = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float) / 255
    return arc.to_rgba(np.ones((64, 64, 3)), np.clip(blurred * 1.3, 0, 1))


def map_background():
    """Weathered parchment for the bounty map."""
    size = 1024
    rng = np.random.default_rng(17)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    stains = ga.fbm(size, size, rng, ((128, 0.4), (48, 0.3), (12, 0.2), (4, 0.1)))
    rgb = np.array([0.80, 0.70, 0.52]) * (0.78 + 0.32 * stains)[..., None]
    d = np.sqrt(((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.62)) ** 2)
    rgb = rgb * (1.05 - 0.55 * np.clip(d, 0, 1) ** 2)[..., None]
    rings = []
    for _ in range(14):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        rings += [(cx, cy, 30 + k * 18 + rng.uniform(-4, 4)) for k in range(4)]

    def draw(dr):
        # Faint contour lines like an old map.
        for cx, cy, r in rings:
            dr.ellipse([cx - r * 1.4, cy - r, cx + r * 1.4, cy + r], outline=(90, 60, 30, 34), width=2)
    return overlay(arc.to_rgba(rgb), draw).filter(ImageFilter.GaussianBlur(0.7))


def role_icon(role):
    """Role gem: shield, crossed swords or a star on the role's colour."""
    c = tuple(int(v * 255) for v in ROLE_COLORS[role])

    def draw(dr, s):
        dr.ellipse([3 * s, 3 * s, 61 * s, 61 * s], fill=(30, 22, 16, 255))
        dr.ellipse([7 * s, 7 * s, 57 * s, 57 * s], fill=c + (255,))
        white = (255, 248, 230, 255)
        if role == "protector":
            dr.polygon([(20 * s, 18 * s), (44 * s, 18 * s), (44 * s, 34 * s), (32 * s, 48 * s), (20 * s, 34 * s)], fill=white)
        elif role == "fighter":
            for flip in (1, -1):
                x0 = 32 - 13 * flip
                dr.line([(x0 * s, 18 * s), ((32 + 13 * flip) * s, 46 * s)], fill=white, width=5 * s)
                dr.line([((32 - 6 * flip) * s, 38 * s), ((32 - 16 * flip) * s, 33 * s)], fill=white, width=3 * s)
        elif role == "caster":
            pts = []
            for k in range(10):
                a = k / 10 * 2 * math.pi
                r = 17 if k % 2 == 0 else 7
                pts.append(((32 + r * math.sin(a)) * s, (33 - r * math.cos(a)) * s))
            dr.polygon(pts, fill=white)
        else:
            dr.ellipse([24 * s, 24 * s, 40 * s, 40 * s], fill=white)
    return supersampled(64, 64, draw)


def tile():
    """Hub card: the arena with the three role gems; models are added in game."""
    w, h = 512, 256
    rng = np.random.default_rng(4)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    grain = ga.fbm(h, w, rng, ((48, 0.5), (16, 0.3), (4, 0.2)))
    rgb = np.array([0.45, 0.38, 0.28]) * (0.75 + 0.45 * grain)[..., None]
    light = np.exp(-(((xx - w / 2) / 260) ** 2 + ((yy - h / 2) / 150) ** 2))
    rgb = rgb * (0.35 + 0.8 * light)[..., None]
    img = arc.to_rgba(rgb)
    for i, role in enumerate(("protector", "fighter", "caster")):
        gem = role_icon(role).resize((44, 44), Image.LANCZOS)
        img.alpha_composite(gem, (w - 60 - i * 50, 14))
    return img


def sounds():
    rng = np.random.default_rng(9)
    hit = ga.mix(ga.noise(0.12, rng, 0.25) * ga.env(int(ga.RATE * 0.12), 0.002, 0.04), ga.tone(110, 0.15, 0.05) * 0.8)
    ga.write_ogg(hit, "hit", 0.6, FOLDER)
    heal = ga.mix(*[ga.place(ga.tone(f, 0.35, 0.12, ((1, 1.0), (2, 0.25))), k * 0.06, int(ga.RATE * 0.6))
                    for k, f in enumerate((660, 880, 1100))])
    ga.write_ogg(heal, "heal", 0.4, FOLDER)
    shield = ga.tone(990, 0.6, 0.3, ((1, 1.0), (2.76, 0.4), (5.4, 0.2)))
    ga.write_ogg(shield, "shield", 0.4, FOLDER)
    death = ga.sweep(220, 70, 0.5) * ga.env(int(ga.RATE * 0.5), 0.01, 0.2)
    ga.write_ogg(death, "death", 0.5, FOLDER)
    drum = ga.mix(ga.tone(70, 0.4, 0.12, ((1, 1.0), (1.5, 0.4))), ga.noise(0.08, rng, 0.4) * ga.env(int(ga.RATE * 0.08), 0.001, 0.02) * 0.6)
    ga.write_ogg(drum, "ready", 0.7, FOLDER)
    total = int(ga.RATE * 1.4)
    win = sum(ga.place(ga.tone(f, 0.6, 0.25), k * 0.14, total) for k, f in enumerate((523, 659, 784, 1046)))
    ga.write_ogg(win, "victory", 0.5, FOLDER)
    lose = sum(ga.place(ga.tone(f, 0.7, 0.3), k * 0.22, total) for k, f in enumerate((392, 330, 262)))
    ga.write_ogg(lose, "defeat", 0.5, FOLDER)
    ga.write_ogg(ga.tone(1200, 0.07, 0.02, ((1, 1.0), (2.5, 0.3))), "select", 0.3, FOLDER)


def main():
    ga.save_tga(board(), "board", FOLDER)
    for role in ROLE_COLORS:
        ga.save_tga(token_frame(role), "token_" + role, FOLDER)
        ga.save_tga(role_icon(role), "role_" + role, FOLDER)
    ga.save_tga(token_frame("neutral", boss=True), "token_boss", FOLDER)
    ga.save_tga(token_back(), "token_back", FOLDER)
    ga.save_tga(token_glow(), "token_glow", FOLDER)
    ga.save_tga(taunt(), "taunt", FOLDER)
    ga.save_tga(divine(), "divine", FOLDER)
    for kind in ("attack", "health", "speed", "level"):
        ga.save_tga(badge(kind), "badge_" + kind, FOLDER)
    ga.save_tga(ability_card(), "card", FOLDER)
    ga.save_tga(card_glow(), "card_glow", FOLDER)
    ga.save_tga(circle_mask(), "circle_mask", FOLDER)
    ga.save_tga(node_ring(), "node_ring", FOLDER)
    ga.save_tga(node_glow(), "node_glow", FOLDER)
    ga.save_tga(map_background(), "map", FOLDER)
    ga.save_tga(tile(), "mercenaries", "tiles")
    sounds()
    print("Mercenaries assets generated")


if __name__ == "__main__":
    main()
