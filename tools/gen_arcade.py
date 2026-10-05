"""Generates the arcade hub, game tiles and Flappy Griffin assets: python tools/gen_arcade.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga

W, H, GROUND = 432, 462, 46


def to_rgba(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 1)
    if alpha is None:
        alpha = np.ones(rgb.shape[:2])
    return Image.fromarray((np.dstack([rgb, np.clip(alpha, 0, 1)]) * 255).astype(np.uint8), "RGBA")


def sky():
    h, w = 512, 512
    yy = np.linspace(0, 1, h)[:, None, None] * np.ones((1, w, 1))
    top = np.array([0.24, 0.45, 0.78])
    mid = np.array([0.55, 0.74, 0.93])
    low = np.array([0.98, 0.86, 0.66])
    t = np.clip(yy / (H / h), 0, 1)
    rgb = np.where(t < 0.6, top + (mid - top) * (t / 0.6), mid + (low - mid) * ((t - 0.6) / 0.4))
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    sun = np.exp(-(((xs - 330) / 70) ** 2 + ((ys - 300) / 70) ** 2))
    rgb = rgb + sun[..., None] * np.array([0.35, 0.28, 0.12])
    return to_rgba(rgb)


def clouds():
    w, h = 512, 256
    rng = np.random.default_rng(21)
    img = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for _ in range(9):
        cx, cy = rng.integers(0, w * 2), rng.integers(60, h * 2 - 120)
        for _ in range(7):
            r = rng.integers(28, 70)
            ox, oy = rng.integers(-90, 90), rng.integers(-18, 22)
            for dx in (-w * 2, 0, w * 2):  # wrap horizontally so the texture tiles
                dr.ellipse([cx + ox - r + dx, cy + oy - r, cx + ox + r + dx, cy + oy + r * 0.8], fill=(255, 255, 255, 150))
    img = img.filter(ImageFilter.GaussianBlur(10))
    return img.resize((w, h), Image.LANCZOS)


def mountains():
    w, h = 512, 256
    rng = np.random.default_rng(8)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for layer, (col, base, amp, freq) in enumerate([
        ((122, 140, 170, 255), 120, 70, 3),
        ((86, 112, 120, 255), 160, 55, 5),
    ]):
        phases = rng.random(4) * 6
        pts = []
        for x in range(0, w + 1, 4):
            t = x / w * 2 * math.pi
            y = base - amp * (0.55 * math.sin(freq * t + phases[0]) + 0.3 * math.sin(2 * freq * t + phases[1])
                              + 0.15 * abs(math.sin(5 * freq * t + phases[2])))
            pts.append((x, y))
        dr.polygon(pts + [(w, h), (0, h)], fill=col)
        if layer == 0:
            # snow caps on the far range
            for x, y in pts[::6]:
                if y < base - amp * 0.55:
                    dr.polygon([(x - 10, y + 12), (x, y - 1), (x + 10, y + 12)], fill=(236, 240, 248, 230))
    return img.filter(ImageFilter.GaussianBlur(0.8))


def ground_lip():
    w, h = 512, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    rng = np.random.default_rng(4)
    dr.rectangle([0, 24, w, 36], fill=(58, 92, 34, 255))
    dr.rectangle([0, 34, w, 40], fill=(40, 62, 24, 200))
    for x in range(0, w, 3):
        hgt = rng.integers(6, 18)
        col = (70 + rng.integers(0, 40), 120 + rng.integers(0, 50), 40, 255)
        for dx in (0, w):
            dr.line([(x + dx - w, 26), (x + dx - w + rng.integers(-3, 4), 26 - hgt)], fill=col, width=2)
            dr.line([(x, 26), (x + rng.integers(-3, 4), 26 - hgt)], fill=col, width=2)
    return img


def pillar_shade():
    w, h = 64, 64
    xs = np.linspace(-1, 1, w)[None, :]
    shade = 0.55 + 0.6 * np.sqrt(np.clip(1 - (xs + 0.25) ** 2, 0, 1))
    shade = np.clip(shade, 0, 1) * np.ones((h, 1))
    edge = np.clip((1 - np.abs(xs)) * 12, 0, 1)
    shade = shade * (0.25 + 0.75 * edge)
    return to_rgba(np.dstack([shade] * 3))


def pillar_cap():
    w, h = 128, 32
    n = 4
    img = Image.new("RGBA", (w * n, h * n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    s = n
    dr.rounded_rectangle([2 * s, 4 * s, (w - 2) * s, (h - 4) * s], radius=4 * s, fill=(112, 104, 96, 255), outline=(40, 34, 30, 255), width=2 * s)
    dr.rectangle([4 * s, 6 * s, (w - 4) * s, 11 * s], fill=(150, 142, 132, 255))
    dr.rectangle([2 * s, (h - 11) * s, (w - 2) * s, (h - 7) * s], fill=(214, 168, 64, 255))
    dr.rectangle([2 * s, (h - 7) * s, (w - 2) * s, (h - 5) * s], fill=(120, 84, 30, 255))
    for i in range(8):
        x = (10 + i * 15) * s
        dr.ellipse([x - 2 * s, (h - 10) * s, x + 2 * s, (h - 6) * s], fill=(255, 226, 140, 255))
    return img.resize((w, h), Image.LANCZOS)


def medal(colors):
    size = 128
    n = size * ga.SS
    u, v = ga.grid(n)
    d = np.sqrt(u * u + v * v)
    base, light, dark = (np.array(c) / 255 for c in colors)
    ring = (d > 0.78) & (d < 0.95)
    face = d <= 0.78
    shade = 0.6 + 0.4 * np.clip(-(u + v) * 0.7 + 0.4, 0, 1)
    rgb = np.where(face[..., None], base * shade[..., None], 0)
    rgb = np.where(ring[..., None], (light * 0.7 + base * 0.3) * shade[..., None], rgb)
    alpha = (d < 0.95).astype(float) * (1 - ga.smoothstep(0.93, 0.95, d))
    img = to_rgba(rgb, alpha)
    dr = ImageDraw.Draw(img)
    cx = cy = n / 2
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = n * (0.3 if i % 2 == 0 else 0.13)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    dr.polygon(pts, fill=tuple(int(c * 255) for c in light) + (255,), outline=tuple(int(c * 255) for c in dark) + (255,), width=n // 60)
    dr.ellipse([n * 0.05, n * 0.05, n * 0.95, n * 0.95], outline=tuple(int(c * 255) for c in dark) + (255,), width=n // 50)
    return img.resize((size, size), Image.LANCZOS)


def hub_background():
    w, h = 512, 512
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    stripe = (np.floor((xs + ys * 0.0) / 36) % 2)
    top = np.array([0.16, 0.07, 0.25])
    bottom = np.array([0.05, 0.02, 0.09])
    t = np.clip(ys / H, 0, 1)[..., None]
    rgb = top * (1 - t) + bottom * t
    rgb = rgb * (0.88 + 0.12 * stripe[..., None])
    cx, cy = W / 2, 150
    glow = np.exp(-(((xs - cx) / 200) ** 2 + ((ys - cy) / 140) ** 2))
    rgb = rgb + glow[..., None] * np.array([0.22, 0.10, 0.28])
    vignette = np.clip(1 - (((xs - W / 2) / W) ** 2 + ((ys - H / 2) / H) ** 2) * 1.6, 0.35, 1)
    rgb = rgb * vignette[..., None]
    img = to_rgba(rgb)
    dr = ImageDraw.Draw(img)
    rng = np.random.default_rng(13)
    for _ in range(70):
        x, y = rng.integers(0, W), rng.integers(0, H)
        r = rng.random() * 1.4 + 0.4
        a = int(80 + rng.random() * 140)
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(255, 230, 170, a))
    return img


def tile_canvas(art):
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 255))
    canvas.paste(art.resize((256, 128), Image.LANCZOS), (0, 0))
    return canvas


def murloc_tile():
    media = ga.MEDIA / "murlocblast"
    art = Image.new("RGBA", (512, 256))
    bg = Image.open(media / "background.tga").crop((0, 40, 432, 256)).resize((512, 256), Image.LANCZOS)
    art.alpha_composite(bg)
    rh = 40 * math.sqrt(3) / 2
    rows = ["RRYYBBGGPPRRB", "RYYBBKGGPPRR", "OOBBWWRRYYGGB", "OBB..RRY..GG"]
    letters = {"R": 1, "Y": 2, "G": 3, "B": 4, "P": 5, "O": 6, "W": 7, "K": 8}
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == ".":
                continue
            bubble = Image.open(media / f"bubble{letters[ch]}.tga").resize((40, 40), Image.LANCZOS)
            art.alpha_composite(bubble, (int(c * 40 + (20 if r % 2 else 0) - 4), int(r * rh)))
    launcher = Image.open(media / "launcher.tga").resize((96, 96), Image.LANCZOS)
    art.alpha_composite(launcher, (208, 168))
    art.alpha_composite(Image.open(media / "bubble10.tga").resize((44, 44), Image.LANCZOS), (234, 194))
    return tile_canvas(art)


def flappy_tile():
    art = sky().crop((0, 60, 512, 316)).copy()
    art.alpha_composite(clouds().crop((0, 0, 512, 160)), (0, 0))
    art.alpha_composite(mountains().resize((512, 200)), (0, 40))
    rng = np.random.default_rng(2)
    stone = ga.fbm(256, 70, rng)
    rock = to_rgba(np.dstack([0.46 + 0.35 * stone, 0.42 + 0.33 * stone, 0.38 + 0.3 * stone]))
    shade = pillar_shade().resize((70, 256))
    cap = pillar_cap().resize((84, 22))
    for x, gap_y in ((300, 120), (440, 90)):
        for top, bottom, flip in ((-10, gap_y - 46, True), (gap_y + 46, 230, False)):
            seg = rock.crop((0, 0, 70, max(1, bottom - top))).copy()
            seg = Image.fromarray((np.asarray(seg).astype(float) * np.asarray(shade.crop((0, 0, 70, seg.height))).astype(float) / 255).astype(np.uint8), "RGBA")
            seg.putalpha(255)
            art.alpha_composite(seg, (x - 35, top))
            capped = cap.transpose(Image.FLIP_TOP_BOTTOM) if flip else cap
            art.alpha_composite(capped, (x - 42, (bottom - 20) if flip else top - 2))
    ground = Image.new("RGBA", (512, 34), (64, 106, 38, 255))
    art.alpha_composite(ground, (0, 222))
    art.alpha_composite(ground_lip(), (0, 196))
    return tile_canvas(art)


def sounds():
    rng = np.random.default_rng(31)
    n = int(ga.RATE * 0.16)
    flap = ga.noise(0.16, rng, 0.06) * ga.env(n, 0.01, 0.05)
    flap = flap * np.sin(np.linspace(0, math.pi, n)) ** 0.5
    ga.write_ogg(flap, "flap", 0.45, "flappy")
    ga.write_ogg(ga.tone(1318.5, 0.18, 0.06, ((1, 1.0), (2, 0.25))), "point", 0.35, "flappy")
    hn = int(ga.RATE * 0.35)
    hit = ga.mix(ga.noise(0.35, rng, 0.04) * ga.env(hn, 0.002, 0.08), ga.sweep(160, 50, 0.35) * ga.env(hn, 0.002, 0.12))
    ga.write_ogg(hit, "hit", 0.85, "flappy")
    total = int(ga.RATE * 1.0)
    notes = [659.25, 783.99, 987.77, 1318.5]
    medal_sound = sum(ga.place(ga.tone(f, 0.5, 0.2), i * 0.08, total) for i, f in enumerate(notes))
    ga.write_ogg(medal_sound, "medal", 0.65, "flappy")


def main():
    ga.save_tga(sky(), "sky", "flappy")
    ga.save_tga(clouds(), "clouds", "flappy")
    ga.save_tga(mountains(), "mountains", "flappy")
    ga.save_tga(ground_lip(), "ground_lip", "flappy")
    ga.save_tga(pillar_shade(), "pillar_shade", "flappy")
    ga.save_tga(pillar_cap(), "pillar_cap", "flappy")
    ga.save_tga(medal(((176, 112, 62), (226, 160, 100), (90, 50, 20))), "medal_bronze", "flappy")
    ga.save_tga(medal(((170, 176, 190), (236, 240, 248), (80, 84, 96))), "medal_silver", "flappy")
    ga.save_tga(medal(((222, 170, 40), (255, 228, 120), (110, 74, 10))), "medal_gold", "flappy")
    sounds()
    ga.save_tga(hub_background(), "hub_background", "")
    ga.save_tga(murloc_tile(), "murlocblast", "tiles")
    ga.save_tga(flappy_tile(), "flappygriffin", "tiles")
    print("Arcade assets generated in", ga.MEDIA)


if __name__ == "__main__":
    main()
