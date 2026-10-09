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


def vignette():
    """Dark edges for backgrounds; drawn over map art to frame the scene."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(float) / (size - 1) * 2 - 1
    d = np.sqrt((xx * 0.95) ** 2 + (yy * 1.05) ** 2)
    alpha = np.clip((d - 0.45) / 0.75, 0, 1) ** 1.6 * 0.92
    return arc.to_rgba(np.zeros((size, size, 3)), alpha)


def poster():
    """A wanted poster: weathered parchment with ragged edges and two nails."""
    w, h = 256, 512
    rng = np.random.default_rng(23)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    stains = ga.fbm(h, w, rng, ((64, 0.4), (24, 0.3), (8, 0.2), (3, 0.1)))
    rgb = np.array([0.86, 0.76, 0.56]) * (0.78 + 0.32 * stains)[..., None]
    d = np.sqrt(((xx - w / 2) / (w * 0.55)) ** 2 + ((yy - h / 2) / (h * 0.55)) ** 2)
    rgb = rgb * (1.05 - 0.5 * np.clip(d, 0, 1) ** 2)[..., None]
    # Ragged outline: the edge wanders a few pixels in and out.
    edge = ga.fbm(h, w, np.random.default_rng(5), ((16, 0.6), (4, 0.4)))
    inset = 6 + 8 * edge
    inside = (xx > inset) & (xx < w - 1 - inset) & (yy > inset) & (yy < h - 1 - inset)
    alpha = inside.astype(float)
    burn = np.clip(1 - np.minimum.reduce([xx - inset, w - 1 - inset - xx, yy - inset, h - 1 - inset - yy]) / 14, 0, 1)
    rgb = rgb * (1 - 0.55 * burn[..., None])
    img = arc.to_rgba(rgb, alpha)

    def nails(dr):
        for x in (40, w - 40):
            dr.ellipse([x - 7, 14, x + 7, 28], fill=(70, 60, 50, 255))
            dr.ellipse([x - 4, 17, x + 2, 23], fill=(150, 140, 130, 255))
    return overlay(img, nails).filter(ImageFilter.GaussianBlur(0.5))


def plate():
    """Dark name plate with a gold rim."""
    w, h = 256, 64
    outer = arc.rounded_rect_alpha(w, h, 14, inset=2)
    inner = arc.rounded_rect_alpha(w, h, 11, inset=5)
    body = vertical(h, w, (0.2, 0.15, 0.12), (0.07, 0.05, 0.04))
    gold = vertical(h, w, (1.0, 0.86, 0.48), (0.6, 0.38, 0.1))
    ring = np.clip(outer - inner, 0, 1)[..., None]
    rgb = body * (1 - ring) + gold * ring
    return arc.to_rgba(rgb, outer * 0.96)


def ribbon():
    """Red title ribbon with gold trim and folded ends."""
    w, h = 512, 96

    def draw(dr, s):
        dark, red, gold = (90, 12, 10, 255), (168, 28, 22, 255), (226, 182, 86, 255)
        # Folded tails behind the band.
        dr.polygon([(0, 30 * s), (60 * s, 30 * s), (60 * s, 86 * s), (0, 86 * s), (22 * s, 58 * s)], fill=dark)
        dr.polygon([(w * s, 30 * s), ((w - 60) * s, 30 * s), ((w - 60) * s, 86 * s), (w * s, 86 * s), ((w - 22) * s, 58 * s)], fill=dark)
        dr.rectangle([40 * s, 12 * s, (w - 40) * s, 76 * s], fill=gold)
        dr.rectangle([40 * s, 16 * s, (w - 40) * s, 72 * s], fill=red)
        dr.line([(40 * s, 22 * s), ((w - 40) * s, 22 * s)], fill=(200, 60, 50, 255), width=2 * s)
    img = supersampled(w, h, draw)
    arr = np.array(img).astype(float)
    shade = np.linspace(1.15, 0.8, h)[:, None]
    arr[..., :3] *= shade[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def menu_card():
    """Large menu button of the camp: dark wood with a gold frame."""
    w, h = 512, 128
    rng = np.random.default_rng(13)
    outer = arc.rounded_rect_alpha(w, h, 18, inset=2)
    inner = arc.rounded_rect_alpha(w, h, 14, inset=7)
    grain = ga.fbm(h, w, rng, ((64, 0.2), (8, 0.5), (2, 0.3)))
    wood = vertical(h, w, (0.32, 0.2, 0.12), (0.14, 0.08, 0.05)) * (0.8 + 0.35 * grain)[..., None]
    gold = vertical(h, w, (1.0, 0.88, 0.5), (0.58, 0.36, 0.1))
    ring = np.clip(outer - inner, 0, 1)[..., None]
    return arc.to_rgba(wood * (1 - ring) + gold * ring, outer)


# Hearthstone-style pieces ---------------------------------------------------------------------------
# Role colours of the cards (face, light edge, dark edge).
CARD_COLORS = {
    "protector": ((0.62, 0.16, 0.10), (0.92, 0.42, 0.25), (0.30, 0.06, 0.04)),
    "fighter": ((0.20, 0.50, 0.16), (0.50, 0.86, 0.36), (0.08, 0.24, 0.06)),
    "caster": ((0.16, 0.30, 0.66), (0.42, 0.62, 1.00), (0.06, 0.12, 0.34)),
    "neutral": ((0.40, 0.40, 0.42), (0.70, 0.70, 0.72), (0.18, 0.18, 0.20)),
}
CW, CH = 256, 352
C_OVAL = (128, 122, 82, 102)  # cx, cy, rx, ry of the portrait window


def metal(h, w, light=(0.92, 0.92, 0.95), dark=(0.38, 0.40, 0.46)):
    """Brushed silver: a vertical gradient with fine streaks."""
    rng = np.random.default_rng(2)
    base = vertical(h, w, light, dark)
    streak = ga.fbm(h, w, rng, ((64, 0.2), (2, 0.8)))
    return base * (0.88 + 0.22 * streak)[..., None]


def soft_box(h, w, x0, y0, x1, y1, blur=2):
    m = np.zeros((h, w))
    m[y0:y1, x0:x1] = 1
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))).astype(float) / 255


def merc_card(role):
    """A mercenary card: role-coloured frame, a silver ring round an oval portrait window,
    small wings at the ring's foot and a dark plate below for level and experience."""
    face, light, dark = (np.array(c) for c in CARD_COLORS[role])
    cx, cy, rx, ry = C_OVAL
    rng = np.random.default_rng(7)
    body = arc.rounded_rect_alpha(CW, CH, 26, inset=18)
    grain = ga.fbm(CH, CW, rng, ((32, 0.5), (8, 0.3), (2, 0.2)))
    rgb = vertical(CH, CW, light, dark) * 0.55 + face * 0.45
    rgb = rgb * (0.82 + 0.3 * grain)[..., None]
    rim = np.clip(body - arc.rounded_rect_alpha(CW, CH, 22, inset=24), 0, 1)[..., None]
    rgb = rgb * (1 - rim) + metal(CH, CW) * rim
    plate = soft_box(CH, CW, 40, 250, 216, 322)[..., None]
    stone = vertical(CH, CW, (0.22, 0.22, 0.25), (0.10, 0.10, 0.12)) * (0.85 + 0.25 * grain)[..., None]
    rgb = rgb * (1 - plate) + stone * plate
    ring_out = ellipse_mask(CW, CH, cx, cy, rx + 14, ry + 14)
    ring_in = ellipse_mask(CW, CH, cx, cy, rx, ry)
    ring = np.clip(ring_out - ring_in, 0, 1)
    yy, xx = np.mgrid[0:CH, 0:CW].astype(float)
    shine = 0.75 + 0.35 * np.cos(np.arctan2(yy - cy, xx - cx) + 2.2)
    rgb = rgb * (1 - ring[..., None]) + (metal(CH, CW) * shine[..., None]) * ring[..., None]
    lip = np.clip(ellipse_mask(CW, CH, cx, cy, rx + 3, ry + 3) - ring_in, 0, 1)[..., None]
    rgb = rgb * (1 - lip) + np.array([0.95, 0.78, 0.36]) * lip
    alpha = np.clip(np.maximum(body, ring_out) - ring_in, 0, 1)
    img = arc.to_rgba(rgb, alpha)

    def wings(dr, s):
        for side in (-1, 1):
            x0 = cx + side * (rx + 4)
            x0 = cx + side * (rx + 8)
            # Three small feathers fanning out from the ring's foot.
            for k, (dx, dy) in enumerate(((22, 56), (26, 70), (20, 82))):
                pts = [(x0, cy + 52 + k * 10), (x0 + side * dx, cy + dy - 6), (x0 + side * (dx - 4), cy + dy + 4),
                       (x0 - side * 2, cy + 60 + k * 10)]
                shade = 214 - k * 30
                dr.polygon([(x * s, y * s) for x, y in pts], fill=(shade, shade + 2, shade + 10, 255), outline=(60, 62, 70, 255))
    return Image.alpha_composite(img, supersampled(CW, CH, wings))


TW_, TH_ = 192, 224
T_OVAL = (96, 100, 74, 90)


def hs_token(role):
    """Battle token: a silver oval ring with a role-coloured crescent at its foot."""
    face, light, dark = (np.array(c) for c in CARD_COLORS[role])
    cx, cy, rx, ry = T_OVAL
    window = ellipse_mask(TW_, TH_, cx, cy, rx, ry)
    ring_out = ellipse_mask(TW_, TH_, cx, cy, rx + 12, ry + 12)
    base = ellipse_mask(TW_, TH_, cx, cy + 22, rx + 14, ry + 6)
    crescent = np.clip(base - ring_out, 0, 1)
    yy, xx = np.mgrid[0:TH_, 0:TW_].astype(float)
    crescent = crescent * (yy > cy).astype(float)
    shine = 0.75 + 0.35 * np.cos(np.arctan2(yy - cy, xx - cx) + 2.2)
    rgb = metal(TH_, TW_) * shine[..., None]
    color = vertical(TH_, TW_, light, dark)
    rgb = rgb * (1 - crescent[..., None]) + color * crescent[..., None]
    lip = np.clip(ellipse_mask(TW_, TH_, cx, cy, rx + 3, ry + 3) - window, 0, 1)[..., None]
    rgb = rgb * (1 - lip) + np.array([0.95, 0.78, 0.36]) * lip
    alpha = np.clip(np.maximum(ring_out, crescent) - window, 0, 1)
    return arc.to_rgba(rgb, alpha)


def hs_token_back():
    cx, cy, rx, ry = T_OVAL
    window = ellipse_mask(TW_, TH_, cx, cy, rx + 1, ry + 1)
    yy, xx = np.mgrid[0:TH_, 0:TW_].astype(float)
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy + 24) / ry) ** 2)
    rgb = np.array([0.30, 0.32, 0.40]) * (1.15 - 0.65 * np.clip(d, 0, 1))[..., None]
    return arc.to_rgba(rgb, window)


def hs_token_glow():
    cx, cy, rx, ry = T_OVAL
    m = ellipse_mask(TW_, TH_, cx, cy, rx + 22, ry + 22)
    blurred = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(float) / 255
    inner = ellipse_mask(TW_, TH_, cx, cy, rx + 6, ry + 6)
    return arc.to_rgba(np.ones((TH_, TW_, 3)), np.clip(blurred * (1 - inner * 0.8) * 1.6, 0, 1))


def badge_shape(kind, grow):
    """Polygon of an attack shield or a health drop, `grow` pixels larger for the rim."""
    if kind == "attack":
        return [(14 - grow, 14 - grow), (82 + grow, 14 - grow), (80 + grow, 52), (48, 86 + grow), (16 - grow, 52)]
    pts = []
    for i in range(72):
        a = i / 72 * 2 * math.pi
        r = 30 + grow
        x, y = 48 + r * math.sin(a), 58 + r * math.cos(a)
        if math.cos(a) < -0.2:
            t = (-math.cos(a) - 0.2) / 0.8
            x = 48 + (x - 48) * (1 - t * 0.95)
            y = 58 - (r + 20 * t) * (-math.cos(a))
        pts.append((x, y))
    return pts


def hs_badge(kind, role):
    """Attack shield or health drop in the role's colour with a silver rim."""
    size = 96
    _, light, dark = CARD_COLORS[role]

    def mask(grow):
        def draw(dr, s):
            dr.polygon([(x * s, y * s) for x, y in badge_shape(kind, grow)], fill=255)
        return np.asarray(supersampled(size, size, draw, "L")).astype(float) / 255
    outer, inner = mask(5), mask(0)
    rgb = metal(size, size) * (1 - inner[..., None]) + vertical(size, size, light, dark) * inner[..., None]
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    highlight = np.exp(-(((xx - 36) / 18) ** 2 + ((yy - 36) / 14) ** 2)) * inner
    return arc.to_rgba(np.clip(rgb + 0.35 * highlight[..., None], 0, 1), outer)


def hs_ability_card(role):
    """Ability card: role-coloured border, a round window for the icon and a parchment field."""
    face, light, dark = (np.array(c) for c in CARD_COLORS[role])
    rng = np.random.default_rng(9)
    body = arc.rounded_rect_alpha(CW, CH, 22, inset=14)
    grain = ga.fbm(CH, CW, rng, ((32, 0.5), (8, 0.3), (2, 0.2)))
    rgb = (vertical(CH, CW, light, dark) * 0.5 + face * 0.5) * (0.84 + 0.28 * grain)[..., None]
    rim = np.clip(body - arc.rounded_rect_alpha(CW, CH, 18, inset=20), 0, 1)[..., None]
    rgb = rgb * (1 - rim) + metal(CH, CW) * rim
    field = soft_box(CH, CW, 34, 196, 222, 318)[..., None]
    paper = np.array([0.88, 0.80, 0.62]) * (0.86 + 0.2 * ga.fbm(CH, CW, rng, ((24, 0.6), (4, 0.4))))[..., None]
    rgb = rgb * (1 - field) + paper * field
    cx, cy, r = 128, 104, 66
    window = ellipse_mask(CW, CH, cx, cy, r, r)
    outer = ellipse_mask(CW, CH, cx, cy, r + 12, r + 12)
    ring = np.clip(outer - window, 0, 1)[..., None]
    rgb = rgb * (1 - ring) + vertical(CH, CW, (1.0, 0.86, 0.5), (0.55, 0.34, 0.1)) * ring
    return arc.to_rgba(rgb, np.clip(np.maximum(body, outer) - window, 0, 1))


BUTTON_FACES = {
    "button": ((240, 226, 190), (205, 172, 110)),
    "button_red": ((196, 52, 36), (98, 14, 10)),
    "button_blue": ((62, 132, 214), (18, 46, 112)),
    "button_green": ((84, 172, 64), (24, 82, 20)),
}


def hs_button(kind="button"):
    """A lacquered button: dark outline, gold rim, a face with a soft top light and a gloss band,
    and metal caps with a small gem on both ends."""
    w, h = 256, 64
    top, bottom = BUTTON_FACES[kind]
    s = SS
    face = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(face)
    d.rounded_rectangle([10 * s, 7 * s, (w - 10) * s, (h - 7) * s], radius=12 * s, fill=(34, 22, 12, 255))
    d.rounded_rectangle([12 * s, 9 * s, (w - 12) * s, (h - 9) * s], radius=10 * s, fill=(232, 190, 96, 255))
    d.rounded_rectangle([15 * s, 12 * s, (w - 15) * s, (h - 12) * s], radius=8 * s, fill=(120, 80, 30, 255))
    inner = Image.new("L", (w * s, h * s), 0)
    ImageDraw.Draw(inner).rounded_rectangle([17 * s, 14 * s, (w - 17) * s, (h - 14) * s], radius=7 * s, fill=255)
    t = np.linspace(0, 1, h * s)[:, None]
    grad = np.array(top)[None, None, :] * (1 - t[..., None]) + np.array(bottom)[None, None, :] * t[..., None]
    grad = np.broadcast_to(grad, (h * s, w * s, 3)).copy()
    # Gloss: a light band over the upper half.
    gloss = np.clip(1 - np.abs(t - 0.32) / 0.14, 0, 1)[..., None] * 0.35
    grad = grad + (255 - grad) * gloss
    fill = Image.fromarray(np.clip(grad, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    face.paste(fill, (0, 0), inner)
    d = ImageDraw.Draw(face)
    for x in (10, w - 10):
        d.ellipse([(x - 11) * s, (h / 2 - 15) * s, (x + 11) * s, (h / 2 + 15) * s], fill=(30, 26, 24, 255))
        d.ellipse([(x - 9) * s, (h / 2 - 13) * s, (x + 9) * s, (h / 2 + 13) * s], fill=(150, 150, 160, 255))
        d.ellipse([(x - 5) * s, (h / 2 - 7) * s, (x + 5) * s, (h / 2 + 7) * s], fill=(232, 190, 96, 255))
        d.ellipse([(x - 3) * s, (h / 2 - 5) * s, (x + 1) * s, (h / 2 - 1) * s], fill=(255, 245, 210, 255))
    return face.resize((w, h), Image.LANCZOS)


def swirl():
    """Blue swirling energy for the big round button; it turns in game."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    dx, dy = (xx - size / 2) / (size / 2), (yy - size / 2) / (size / 2)
    r = np.sqrt(dx * dx + dy * dy)
    a = np.arctan2(dy, dx)
    noise = ga.fbm(size, size, np.random.default_rng(3), ((32, 0.6), (8, 0.4)))
    arms = 0.5 + 0.5 * np.sin(a * 3 + r * 9 + noise * 3)
    glow = np.clip(1 - r, 0, 1)
    rgb = np.dstack([0.15 + 0.5 * arms * glow, 0.45 + 0.45 * arms * glow, 0.6 + 0.4 * glow])
    return arc.to_rgba(np.clip(rgb, 0, 1), np.clip((1 - r) * 3, 0, 1))


def dash():
    def draw(dr, s):
        dr.rounded_rectangle([2 * s, 4 * s, 30 * s, 12 * s], radius=4 * s, fill=(255, 255, 255, 255))
    return supersampled(32, 16, draw)


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


def disc_mask():
    """A circle filling its whole square; stretched over an oval it masks portraits."""
    m = ellipse_mask(128, 128, 64, 64, 63.5, 63.5)
    return arc.to_rgba(np.ones((128, 128, 3)), m)


GLOW_PAD = 32


def halo(alpha, spread=10, blur=9):
    """A soft glow around a shape and nothing inside it, with GLOW_PAD pixels of room on each side
    so it never meets the texture's edge."""
    h, w = alpha.shape
    big = np.zeros((h + 2 * GLOW_PAD, w + 2 * GLOW_PAD))
    big[GLOW_PAD:GLOW_PAD + h, GLOW_PAD:GLOW_PAD + w] = alpha
    img = Image.fromarray((big * 255).astype(np.uint8))
    grown = img.filter(ImageFilter.MaxFilter(2 * (spread // 2) + 1)).filter(ImageFilter.MaxFilter(2 * (spread // 2) + 1))
    soft = np.asarray(grown.filter(ImageFilter.GaussianBlur(blur))).astype(float) / 255
    glow = np.clip(soft * 1.5, 0, 1) * (1 - np.clip(big * 1.2, 0, 1))
    return arc.to_rgba(np.ones(glow.shape + (3,)), glow)


def card_halo():
    cx, cy, rx, ry = C_OVAL
    shape = np.asarray(merc_card("neutral").split()[3]).astype(float) / 255
    return halo(np.maximum(shape, ellipse_mask(CW, CH, cx, cy, rx + 2, ry + 2)))


def acard_halo():
    shape = np.asarray(hs_ability_card("neutral").split()[3]).astype(float) / 255
    return halo(np.maximum(shape, ellipse_mask(CW, CH, 128, 104, 68, 68)))


def token_halo():
    cx, cy, rx, ry = T_OVAL
    ring_out = ellipse_mask(TW_, TH_, cx, cy, rx + 12, ry + 12)
    base = ellipse_mask(TW_, TH_, cx, cy + 22, rx + 14, ry + 6)
    return halo(np.maximum(ring_out, base), spread=8, blur=8)


def main():
    ga.save_tga(disc_mask(), "disc_mask", FOLDER)
    ga.save_tga(card_halo(), "glow_card", FOLDER)
    ga.save_tga(acard_halo(), "glow_acard", FOLDER)
    ga.save_tga(token_halo(), "glow_token", FOLDER)
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
    ga.save_tga(vignette(), "vignette", FOLDER)
    ga.save_tga(poster(), "poster", FOLDER)
    ga.save_tga(plate(), "plate", FOLDER)
    ga.save_tga(ribbon(), "ribbon", FOLDER)
    ga.save_tga(menu_card(), "menu_card", FOLDER)
    for role in CARD_COLORS:
        ga.save_tga(merc_card(role), "card_" + role, FOLDER)
        ga.save_tga(hs_ability_card(role), "acard_" + role, FOLDER)
        ga.save_tga(hs_token(role), "otoken_" + role, FOLDER)
        for kind in ("attack", "health"):
            ga.save_tga(hs_badge(kind, role), f"hs_{kind}_{role}", FOLDER)
    for kind in BUTTON_FACES:
        ga.save_tga(hs_button(kind), kind, FOLDER)
    ga.save_tga(hs_token_back(), "otoken_back", FOLDER)
    ga.save_tga(hs_token_glow(), "otoken_glow", FOLDER)
    ga.save_tga(swirl(), "swirl", FOLDER)
    ga.save_tga(dash(), "dash", FOLDER)
    sounds()
    print("Mercenaries assets generated")


if __name__ == "__main__":
    main()
