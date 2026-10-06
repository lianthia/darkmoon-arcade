"""Generates the Spellbounce textures and sounds: python tools/gen_spellbounce.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga
import gen_arcade as arc

W, H = 432, 462
FOLDER = "spellbounce"

# Sky gradient (top, bottom), hill colors and decoration per background theme.
THEMES = {
    1: dict(top=(0.10, 0.04, 0.20), bottom=(0.30, 0.08, 0.30), hills=((60, 20, 70), (40, 12, 50)), deco="tents", seed=3),
    2: dict(top=(0.05, 0.08, 0.22), bottom=(0.18, 0.30, 0.34), hills=((24, 56, 40), (14, 38, 28)), deco="trees", seed=5),
    3: dict(top=(0.02, 0.10, 0.16), bottom=(0.06, 0.30, 0.34), hills=((16, 52, 60), (8, 34, 42)), deco="moon", seed=7),
    4: dict(top=(0.14, 0.05, 0.06), bottom=(0.44, 0.18, 0.08), hills=((70, 34, 20), (46, 22, 14)), deco="ruins", seed=9),
}


def background(theme):
    t = THEMES[theme]
    w = h = 512
    rng = np.random.default_rng(t["seed"])
    ys = np.clip(np.linspace(0, 1, h) / (H / h), 0, 1)[:, None, None]
    rgb = np.array(t["top"]) * (1 - ys) + np.array(t["bottom"]) * ys
    rgb = np.broadcast_to(rgb, (h, w, 3)).copy()
    mist = ga.fbm(h, w, rng, ((96, 0.5), (48, 0.3), (24, 0.2)))
    rgb *= (0.85 + 0.3 * mist)[..., None]
    img = arc.to_rgba(rgb)
    dr = ImageDraw.Draw(img, "RGBA")
    for _ in range(110):
        x, y = rng.integers(0, w), rng.integers(0, int(H * 0.6))
        r = rng.random() * 1.1 + 0.3
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(255, 245, 230, int(60 + rng.random() * 140)))
    deco = t["deco"]
    if deco == "moon":
        dr.ellipse([300, 40, 380, 120], fill=(210, 240, 245, 70))
        dr.ellipse([306, 46, 374, 114], fill=(220, 248, 250, 200))
    if deco == "tents":
        for x0, half, height in [(70, 60, 90), (360, 70, 110)]:
            base = H - 24
            dr.polygon([(x0 - half, base), (x0, base - height), (x0 + half, base)], fill=(90, 26, 70, 150))
            for k in range(-2, 3):
                dr.line([(x0, base - height), (x0 + k * half / 2.5, base)], fill=(150, 60, 110, 110), width=3)
    if deco == "ruins":
        for x0, height in [(40, 120), (90, 80), (350, 140), (400, 90)]:
            dr.rectangle([x0 - 14, H - 24 - height, x0 + 14, H - 24], fill=(60, 28, 20, 150))
            dr.rectangle([x0 - 20, H - 30 - height, x0 + 20, H - 22 - height], fill=(80, 40, 26, 160))
    for k, col in enumerate(t["hills"]):
        base = H - 40 + k * 18
        pts = [(x, base - 16 * math.sin(x / 60 + k * 1.7 + t["seed"])) for x in range(0, w + 1, 8)]
        dr.polygon(pts + [(w, h), (0, h)], fill=col + (255,))
    if deco == "trees":
        for x0 in (30, 70, 110, 330, 380, 420):
            height = int(rng.integers(60, 110))
            base = H - 30
            dr.polygon([(x0 - 18, base), (x0, base - height), (x0 + 18, base)], fill=(10, 30, 22, 230))
    # Darken the middle so the pegs stand out.
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    vignette = np.exp(-(((xx - W / 2) / 190) ** 2 + ((yy - 260) / 170) ** 2)) * 0.28
    shade = arc.to_rgba(np.zeros((h, w, 3)), vignette)
    img = Image.alpha_composite(img, shade)
    return img.filter(ImageFilter.GaussianBlur(0.7))


def peg(size=64):
    """Grey rune stone; the game tints it per peg kind."""
    n = size * ga.SS
    u, v = ga.grid(n)
    d = np.sqrt(u * u + v * v)
    r = 0.9
    dn = np.clip(d / r, 0, 1)
    nz = np.sqrt(np.clip(1 - dn * dn, 0, 1))
    light = np.array([-0.4, -0.6, 0.7])
    light /= np.linalg.norm(light)
    diffuse = np.clip(u / r * light[0] + v / r * light[1] + nz * light[2], 0, 1)
    spec = np.clip(diffuse, 0, 1) ** 24
    shade = 0.45 + 0.6 * diffuse + 0.5 * spec
    rgb = np.ones((n, n, 3)) * shade[..., None]
    img = ga.to_image(rgb, (d < r) * (1 - ga.smoothstep(0.96, 1.0, dn)), n)
    dr = ImageDraw.Draw(img)
    c = n / 2
    s = n * 0.2
    w = max(3, n // 28)
    rune = (70, 70, 80, 200)
    dr.line([(c, c - s * 1.2), (c, c + s * 1.2)], fill=rune, width=w)
    dr.line([(c, c - s * 0.4), (c + s * 0.8, c - s * 1.0)], fill=rune, width=w)
    dr.line([(c, c + s * 0.2), (c - s * 0.8, c - s * 0.4)], fill=rune, width=w)
    rim = Image.fromarray((np.dstack([np.zeros((n, n, 3)), ga.smoothstep(0.8, 0.98, dn) * (d < r) * 0.45]) * 255).astype(np.uint8), "RGBA")
    img = Image.alpha_composite(img, rim)
    return img.resize((size, size), Image.LANCZOS)


def orb(size=64):
    """White core with a soft halo; tinted with the class color in game."""
    def fn(d, u, v):
        return np.clip(np.exp(-(d / 0.42) ** 2) * 0.8 + (1 - ga.smoothstep(0.26, 0.34, d)), 0, 1)
    return ga.radial(size, fn)


def bumper(size=64):
    n = size * ga.SS
    u, v = ga.grid(n)
    d = np.sqrt(u * u + v * v)
    shade = 0.6 + 0.4 * np.clip(-v * 0.8 + 0.3, 0, 1)
    ring_mask = ga.smoothstep(0.55, 0.6, d) * (1 - ga.smoothstep(0.9, 0.95, d))
    gold = np.array([0.95, 0.74, 0.3]) * shade[..., None]
    inner = 1 - ga.smoothstep(0.55, 0.6, d)
    core = np.array([0.28, 0.14, 0.36]) * (0.7 + 0.5 * np.clip(-v, 0, 1))[..., None]
    rgb = gold * (1 - inner[..., None]) + core * inner[..., None]
    img = ga.to_image(rgb, np.clip(ring_mask + inner, 0, 1), n)
    dr = ImageDraw.Draw(img)
    c = n / 2
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rad = n * (0.2 if i % 2 == 0 else 0.09)
        pts.append((c + math.cos(a) * rad, c + math.sin(a) * rad))
    dr.polygon(pts, fill=(255, 226, 150, 255))
    return img.resize((size, size), Image.LANCZOS)


def well():
    """The moonwell at the bottom that returns a caught orb."""
    w, h = 128, 32
    n = ga.SS
    img = Image.new("RGBA", (w * n, h * n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.rounded_rectangle([2 * n, 6 * n, (w - 2) * n, (h - 2) * n], radius=12 * n, fill=(40, 22, 60, 255), outline=(235, 190, 90, 255), width=3 * n)
    dr.rounded_rectangle([10 * n, 8 * n, (w - 10) * n, 16 * n], radius=4 * n, fill=(110, 220, 255, 255))
    for k in range(5):
        x = (18 + k * 23) * n
        dr.ellipse([x - 2 * n, 20 * n, x + 2 * n, 24 * n], fill=(255, 226, 150, 255))
    return img.resize((w, h), Image.LANCZOS)


def launcher(size=128):
    """A rune circle in arcane purple and gold."""
    n = size * ga.SS
    u, v = ga.grid(n)
    d = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    outer = ga.smoothstep(0.8, 0.84, d) * (1 - ga.smoothstep(0.92, 0.96, d))
    ticks = (np.cos(ang * 12) > 0.6) * ga.smoothstep(0.66, 0.7, d) * (1 - ga.smoothstep(0.78, 0.8, d))
    inner = 1 - ga.smoothstep(0.62, 0.66, d)
    gold = np.array([0.98, 0.78, 0.32])
    purple = np.array([0.20, 0.08, 0.32])
    rgb = purple * inner[..., None] + gold * (1 - inner[..., None])
    alpha = np.clip(outer + ticks + inner * 0.85, 0, 1)
    return ga.to_image(rgb, alpha, size)


def tile():
    art = background(1).crop((0, 80, 432, 296)).resize((512, 256), Image.LANCZOS)
    peg_img = peg(40)
    colors = [(110, 160, 255), (255, 90, 70), (110, 255, 120), (255, 210, 80)]
    rng = np.random.default_rng(12)
    for row in range(4):
        for col in range(9):
            if rng.random() < 0.2:
                continue
            x = 24 + col * 54 + (27 if row % 2 else 0)
            y = 70 + row * 46
            roll = rng.random()
            kind = 0 if roll < 0.6 else 1 if roll < 0.9 else 2 if roll < 0.97 else 3
            tinted = Image.new("RGBA", peg_img.size, colors[kind] + (255,))
            stone = Image.composite(Image.alpha_composite(Image.new("RGBA", peg_img.size), Image.blend(peg_img, tinted, 0.55)), Image.new("RGBA", peg_img.size), peg_img.split()[3])
            art.alpha_composite(stone, (int(x - 20), int(y - 20)))
    glow = orb(56)
    tint = Image.new("RGBA", glow.size, (200, 140, 255, 255))
    tint.putalpha(glow.split()[3])
    for k, (x, y) in enumerate([(300, 18), (318, 30), (334, 46), (346, 64)]):
        trail = tint.copy()
        trail.putalpha(trail.split()[3].point(lambda a, k=k: int(a * (0.25 + k * 0.2))))
        art.alpha_composite(trail, (x - 28, y - 28))
    art.alpha_composite(launcher(72), (220, -20))
    return arc.tile_canvas(art)


def sounds():
    rng = np.random.default_rng(23)
    whoosh = ga.noise(0.3, rng, 0.08) * ga.env(int(ga.RATE * 0.3), 0.04, 0.12)
    ga.write_ogg(ga.mix(whoosh, ga.sweep(300, 900, 0.25) * ga.env(int(ga.RATE * 0.25), 0.01, 0.08) * 0.4), "launch", 0.5, FOLDER)
    # A rising pentatonic marimba: every further peg in a shot climbs a step.
    scale = [0, 2, 4, 7, 9]
    for i in range(12):
        semis = scale[i % 5] + 12 * (i // 5)
        f = 392.0 * 2 ** (semis / 12)
        note = ga.tone(f, 0.35, 0.09, ((1, 1.0), (4, 0.25), (10, 0.05)))
        ga.write_ogg(note, f"hit{i + 1}", 0.55, FOLDER)
    bell = ga.mix(ga.tone(1568, 0.5, 0.18, ((1, 1.0), (2.76, 0.4), (5.4, 0.2))))
    ga.write_ogg(bell, "target", 0.35, FOLDER)
    ga.write_ogg(ga.mix(ga.tone(110, 0.2, 0.05, ((1, 1.0), (2, 0.5))), ga.noise(0.05, rng, 0.4) * 0.4), "bump", 0.7, FOLDER)
    total = int(ga.RATE * 0.9)
    shimmer = sum(ga.place(ga.tone(880 * 2 ** (k / 12 * 2), 0.4, 0.12, ((1, 1.0), (2, 0.3))) * 0.6, k * 0.04, total) for k in range(10))
    ga.write_ogg(shimmer, "power", 0.6, FOLDER)
    total = int(ga.RATE * 0.6)
    catch = sum(ga.place(ga.tone(f, 0.3, 0.1), k * 0.07, total) for k, f in enumerate([784, 988, 1175, 1568]))
    ga.write_ogg(catch, "catch", 0.6, FOLDER)
    ga.write_ogg(ga.sweep(500, 140, 0.4) * ga.env(int(ga.RATE * 0.4), 0.01, 0.2), "lost", 0.4, FOLDER)
    whistle = ga.sweep(700, 1800, 0.45, curve=0.7) * ga.env(int(ga.RATE * 0.45), 0.05, 0.3) * 0.5
    ga.write_ogg(ga.mix(whistle, ga.noise(0.45, rng, 0.3) * 0.15), "rocket", 0.35, FOLDER)
    n = int(ga.RATE * 0.9)
    boom = ga.noise(0.9, rng, 0.05) * ga.env(n, 0.003, 0.15)
    crackle = np.zeros(n)
    for _ in range(40):
        start = int(rng.integers(int(ga.RATE * 0.1), n - 400))
        crackle[start:start + 300] += rng.standard_normal(300) * np.exp(-np.arange(300) / 60) * 0.6
    ga.write_ogg(ga.mix(boom, crackle), "firework", 0.6, FOLDER)
    total = int(ga.RATE * 1.4)
    fanfare = sum(ga.place(ga.tone(f, 0.6, 0.25, ((1, 1.0), (2, 0.4), (3, 0.2))), t, total)
                  for t, f in [(0, 523.25), (0.12, 659.25), (0.24, 783.99), (0.42, 1046.5), (0.42, 783.99)])
    ga.write_ogg(fanfare, "clear", 0.6, FOLDER)
    ga.write_ogg(ga.mix(ga.tone(220, 0.25, 0.1, ((1, 1.0), (1.5, 0.5))), ga.tone(330, 0.25, 0.1)), "shield", 0.5, FOLDER)


def main():
    for theme in THEMES:
        ga.save_tga(background(theme), f"background{theme}", FOLDER)
    ga.save_tga(peg(), "peg", FOLDER)
    ga.save_tga(orb(), "orb", FOLDER)
    ga.save_tga(bumper(), "bumper", FOLDER)
    ga.save_tga(well(), "well", FOLDER)
    ga.save_tga(launcher(), "launcher", FOLDER)
    ga.save_tga(tile(), "spellbounce", "tiles")
    sounds()
    print("Spellbounce assets generated")


if __name__ == "__main__":
    main()
