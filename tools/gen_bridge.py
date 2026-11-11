"""Textures of Goblin Bridge Architect (media/bridge): beams, joints, water, grid, sky gradient, the
crane and the goal flag, and the launcher tile. Rock and ground come from the client's tilesets.
If art/gba_logo.png exists (the logo, any size, white or transparent background), it becomes
media/bridge/logo.tga and the launcher tile shows it.

    python tools/gen_bridge.py
"""
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "DarkmoonArcade" / "media" / "bridge"
RNG = np.random.default_rng(11)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.tga")


def arr_img(a):
    return Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), "RGBA")


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def beam(name, base, kind):
    """A beam seen from the side, 128 x 32, drawn along x (stretched over the beam's length)."""
    w, h = 128, 32
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    v = (ys + 0.5) / h * 2 - 1  # -1 top .. 1 bottom
    col = np.ones((h, w, 3)) * np.array(base)
    alpha = np.ones((h, w))
    if kind == "wood":
        grain = 0.85 + 0.15 * np.sin(xs * 0.35 + 3 * np.sin(ys * 0.6)) + 0.06 * RNG.standard_normal((h, w))
        col *= grain[..., None]
        alpha = 1 - smooth(np.abs(v), 0.62, 0.72)
        rim = smooth(np.abs(v), 0.45, 0.62)
        col *= (1 - 0.45 * rim)[..., None]
    elif kind == "road":
        # Planks across, a dark joint every few pixels, a lighter top surface.
        joints = (np.abs(((xs + 2) % 16) - 8) > 6.8)
        grain = 0.85 + 0.1 * np.sin(ys * 1.7 + xs * 0.08) + 0.05 * RNG.standard_normal((h, w))
        col *= grain[..., None]
        col *= np.where(joints, 0.55, 1)[..., None]
        top = smooth(-v, 0.5, 0.7)
        col = col * (1 - 0.2 * top[..., None]) + top[..., None] * np.array([0.25, 0.2, 0.14])
        alpha = 1 - smooth(np.abs(v), 0.78, 0.9)
        col *= (1 - 0.4 * smooth(np.abs(v), 0.55, 0.78))[..., None]
    elif kind == "steel":
        # An I-girder: bright flanges, a darker web with rivets.
        flange = smooth(np.abs(v), 0.38, 0.45)
        col *= (0.7 + 0.45 * flange)[..., None]
        rivet = ((np.abs((xs % 16) - 8) < 1.6) & (np.abs(v) < 0.18))
        col = np.where(rivet[..., None], col * 1.35, col)
        alpha = 1 - smooth(np.abs(v), 0.6, 0.7)
        col *= (1 - 0.35 * smooth(np.abs(v), 0.52, 0.6))[..., None]
        shine = np.exp(-((v + 0.48) / 0.05) ** 2)
        col += shine[..., None] * 0.25
    elif kind == "rope":
        twist = 0.75 + 0.25 * np.sin((xs + ys * 1.3) * 0.9)
        col *= twist[..., None]
        alpha = 1 - smooth(np.abs(v), 0.35, 0.5)
    img = np.dstack([np.clip(col, 0, 1), np.clip(alpha, 0, 1)])
    save(arr_img(img), name)


def disc(name, size, fill, ring, dot=None):
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    u = (xs + 0.5) / size * 2 - 1
    v = (ys + 0.5) / size * 2 - 1
    r = np.sqrt(u * u + v * v)
    col = np.ones((size, size, 3)) * np.array(fill)
    light = 1 + 0.35 * (-u - v) * 0.5
    col *= light[..., None]
    edge = smooth(r, 0.62, 0.8)
    col = col * (1 - edge[..., None]) + edge[..., None] * np.array(ring)
    if dot:
        d = 1 - smooth(r, 0.18, 0.28)
        col = col * (1 - d[..., None]) + d[..., None] * np.array(dot)
    alpha = 1 - smooth(r, 0.86, 0.98)
    save(arr_img(np.dstack([np.clip(col, 0, 1), alpha])), name)


def water():
    """Ripples, tiling sideways (white-ish, tinted in game)."""
    w, h = 128, 64
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    a = 0.5 + 0.5 * np.sin(xs / w * 2 * np.pi * 3 + np.sin(ys * 0.3) * 1.5)
    lines = np.clip((a - 0.85) * 6, 0, 1) * (0.4 + 0.6 * (1 - ys / h))
    col = np.ones((h, w, 3))
    save(arr_img(np.dstack([col, lines * 0.55])), "ripples")


def gradient():
    """Opaque at the bottom, clear at the top (sky horizon, rock shading)."""
    h = 256
    a = np.linspace(0, 1, h)[:, None] * np.ones((h, 8))
    col = np.ones((h, 8, 3))
    save(arr_img(np.dstack([col, a ** 1.4])), "gradient")


def grid():
    """One faint dot per metre: 20 x 20 px, tiled. Saved at 32 x 32 with the dot in a corner so it
    can repeat (the game scales one repeat to 20 px)."""
    s = 32
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float64)
    d = np.minimum(np.minimum(xs, s - xs), 99) ** 2 + np.minimum(np.minimum(ys, s - ys), 99) ** 2
    a = np.exp(-d / 3.0)
    save(arr_img(np.dstack([np.ones((s, s, 3)), a])), "grid")


def splinter():
    img = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 4), (5, 1), (15, 3), (14, 5), (4, 7)], fill=(255, 255, 255, 255))
    save(img, "splinter")


def crane():
    """A goblin crane: a timber mast with a jib, the hook at the jib's tip (anchor point at the
    image's top-right corner region). 128 x 256."""
    w, h = 128, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wood, dark, iron = (150, 98, 52, 255), (80, 50, 26, 255), (90, 92, 98, 255)
    # Mast and braces.
    d.rectangle([20, 20, 34, h], fill=wood, outline=dark)
    for y in range(40, h, 36):
        d.line([(20, y), (34, y + 30)], fill=dark, width=3)
    # Jib out to the right.
    d.polygon([(20, 14), (118, 18), (118, 26), (34, 34)], fill=wood, outline=dark)
    d.line([(27, 0), (116, 20)], fill=dark, width=2)
    d.rectangle([22, 0, 32, 16], fill=iron)
    # The hook block.
    d.rectangle([110, 22, 124, 34], fill=iron, outline=(40, 40, 44, 255))
    save(img, "crane")


def flag():
    """The goal: a pole with a goblin-green flag. 64 x 96, the pole's foot at the bottom left."""
    img = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 8, 95], fill=(110, 80, 50, 255))
    d.polygon([(8, 6), (58, 16), (8, 30)], fill=(90, 190, 60, 255), outline=(30, 80, 20, 255))
    d.ellipse([22, 12, 32, 22], fill=(255, 215, 80, 255))
    save(img, "flag")


def logo():
    src = ROOT / "art" / "gba_logo.png"
    if not src.exists():
        return None
    img = Image.open(src).convert("RGBA")
    a = np.asarray(img).astype(np.float64) / 255
    # A white background becomes transparent (soft, so the outline stays clean).
    if a[..., 3].min() > 0.99:
        white = np.min(a[..., :3], axis=-1)
        alpha = 1 - smooth(white, 0.9, 0.985)
        a[..., 3] = alpha
    img = arr_img(a)
    box = img.getbbox()
    img = img.crop(box)
    # Power-of-two canvas, 1024 x 512, logo fitted.
    canvas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
    scale = min(1000 / img.width, 500 / img.height)
    img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    canvas.paste(img, ((1024 - img.width) // 2, (512 - img.height) // 2), img)
    save(canvas, "logo")
    return canvas


def tile(logo_img):
    """The launcher tile (512 x 256): a sunset gorge with a truss bridge, the logo over it."""
    w, h = 512, 256
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    t = ys / h
    sky = np.array([0.98, 0.72, 0.42]) * (1 - t[..., None]) ** 0.5 + np.array([0.35, 0.45, 0.75]) * (1 - (1 - t[..., None]) ** 0.5)
    sky = sky[::-1]
    img = Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    d.polygon([(0, 150), (60, 120), (130, 140), (210, 105), (300, 135), (380, 110), (460, 130), (512, 115), (512, 256), (0, 256)],
              fill=(150, 100, 70, 255))
    d.rectangle([0, 205, 512, 256], fill=(40, 90, 110, 255))
    d.polygon([(0, 170), (150, 170), (160, 256), (0, 256)], fill=(120, 72, 44, 255))
    d.polygon([(362, 170), (512, 170), (512, 256), (352, 256)], fill=(120, 72, 44, 255))
    road, wood = (90, 60, 34, 255), (205, 150, 85, 255)
    d.line([(150, 170), (362, 170)], fill=road, width=6)
    xs_ = [150 + i * 53 for i in range(5)]
    for x in xs_[1:-1]:
        d.line([(x, 170), (x, 140)], fill=wood, width=3)
    d.line([(xs_[1], 140), (xs_[3], 140)], fill=wood, width=3)
    d.line([(150, 170), (xs_[1], 140)], fill=wood, width=3)
    d.line([(362, 170), (xs_[3], 140)], fill=wood, width=3)
    d.line([(xs_[1], 140), (xs_[2], 170)], fill=wood, width=3)
    d.line([(xs_[3], 140), (xs_[2], 170)], fill=wood, width=3)
    img = img.filter(ImageFilter.SMOOTH)
    if logo_img is not None:
        lg = logo_img.resize((420, 210), Image.LANCZOS)
        img.alpha_composite(lg, ((w - 420) // 2, 6))
    vig = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vig).rectangle([0, 0, w, h], fill=0)
    (ROOT / "DarkmoonArcade" / "media" / "tiles").mkdir(parents=True, exist_ok=True)
    img.save(ROOT / "DarkmoonArcade" / "media" / "tiles" / "bridgearchitect.tga")


def star():
    """A five-pointed star (white with a dark rim; tinted gold or grey in game). 64 x 64."""
    import math
    s = 256
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(10):
        r = 118 if i % 2 == 0 else 50
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((s / 2 + r * math.cos(a), s / 2 + 8 + r * math.sin(a)))
    d.polygon(pts, fill=(60, 40, 10, 255))
    inner = [(s / 2 + (x - s / 2) * 0.84, s / 2 + 8 + (y - s / 2 - 8) * 0.84) for x, y in pts]
    d.polygon(inner, fill=(255, 255, 255, 255))
    hi = [(s / 2 + (x - s / 2) * 0.5, s / 2 - 10 + (y - s / 2 - 8) * 0.5) for x, y in pts]
    d.polygon(hi, fill=(255, 255, 240, 255))
    save(img.resize((64, 64), Image.LANCZOS), "star")


def stars():
    """A night sky's stars, tiling: 256 x 256, white dots of different brightness (drawn added)."""
    s = 256
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(70):
        x, y = RNG.integers(0, s, 2)
        b = int(RNG.integers(90, 255))
        r = 1 if RNG.random() < 0.85 else 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=(b, b, min(255, b + 20), 255))
    save(img, "stars")


def weather():
    """Weather and sky: a soft cloud (256 x 128), a snow flake, a rain streak, a dust mote and the moon.
    All white, tinted in the game. Own random source, so the older textures stay as they were."""
    rng = np.random.default_rng(23)
    # Cloud: a heap of soft round puffs, flat at the bottom, lit from above.
    w, h = 256, 128
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    dens = np.zeros((h, w))
    for _ in range(20):
        cx = rng.uniform(40, 216)
        cy = rng.uniform(64, 88) - 34 * np.exp(-((cx - 118) / 42) ** 2) - 14 * np.exp(-((cx - 170) / 26) ** 2)
        r = rng.uniform(14, 34) * (1.3 - abs(cx - 128) / 200)
        dens = np.maximum(dens, 1 - smooth(np.hypot(xs - cx, (ys - cy) * 1.15), r * 0.55, r))
    dens *= 1 - smooth(ys, 92, 104)
    light = 1 - 0.28 * smooth(ys, 50, 100)
    a = np.zeros((h, w, 4))
    a[..., 0] = light
    a[..., 1] = light
    a[..., 2] = light * 1.02
    a[..., 3] = smooth(dens, 0.0, 0.6) * 0.95
    save(arr_img(a).filter(ImageFilter.GaussianBlur(1.5)), "cloud")
    # Snow flake: a soft white dot with a bright core.
    s = 32
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float64)
    r = np.hypot(xs - s / 2 + 0.5, ys - s / 2 + 0.5)
    a = np.ones((s, s, 4))
    a[..., 3] = (1 - smooth(r, 3, 12)) * 0.85 + (1 - smooth(r, 0, 4)) * 0.15
    save(arr_img(a), "flake")
    # Dust mote: fainter and softer.
    a = np.ones((s, s, 4))
    a[..., 3] = (1 - smooth(r, 0, 14)) ** 2
    save(arr_img(a), "mote")
    # Rain streak: 8 x 64, thin, fading at both ends.
    w, h = 8, 64
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    a = np.ones((h, w, 4))
    a[..., 3] = (1 - smooth(np.abs(xs - w / 2 + 0.5), 0.6, 2.4)) * np.sin(np.pi * (ys + 0.5) / h) ** 0.7
    save(arr_img(a), "rain")
    # Moon: a pale disc with soft craters and a halo.
    s = 128
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float64)
    r = np.hypot(xs - s / 2 + 0.5, ys - s / 2 + 0.5)
    disc_a = 1 - smooth(r, 25, 27)
    shade = np.ones((s, s))
    for _ in range(7):
        cx, cy, cr = rng.uniform(46, 82), rng.uniform(46, 82), rng.uniform(5, 11)
        shade -= 0.07 * (1 - smooth(np.hypot(xs - cx, ys - cy), cr * 0.5, cr))
    halo = (1 - smooth(r, 26, 62)) ** 2 * 0.35
    a = np.zeros((s, s, 4))
    a[..., 0] = np.where(disc_a > 0, 0.95 * shade, 0.75)
    a[..., 1] = np.where(disc_a > 0, 0.95 * shade, 0.8)
    a[..., 2] = np.where(disc_a > 0, 0.88 * shade, 1)
    a[..., 3] = np.maximum(disc_a, halo)
    save(arr_img(a), "moon")


def key_art(logo_img):
    """The teaser (art/launcher/bridgearchitect_teaser.png) for the launcher's spotlight and the contracts
    menu: 910x512 at the left of a 1024x512 texture, like the Mercenaries key art. The launcher tile
    becomes a cut of it with the logo."""
    src_path = ROOT / "art" / "launcher" / "bridgearchitect_teaser.png"
    if not src_path.exists():
        return False
    src = Image.open(src_path).convert("RGB")
    canvas = Image.new("RGB", (1024, 512), (60, 30, 20))
    w = round(512 * src.width / src.height)
    canvas.paste(src.resize((w, 512), Image.LANCZOS), (0, 0))
    (ROOT / "DarkmoonArcade" / "media" / "launcher").mkdir(parents=True, exist_ok=True)
    canvas.save(ROOT / "DarkmoonArcade" / "media" / "launcher" / "bridgearchitect.tga")
    # Tile 512 x 256: the middle of the scene, the logo on top.
    tile_w = src.width * 0.62
    left = (src.width - tile_w) / 2 + src.width * 0.08
    crop = src.crop((int(left), int(src.height * 0.18), int(left + tile_w), int(src.height * 0.18 + tile_w / 2)))
    img = crop.resize((512, 256), Image.LANCZOS).convert("RGBA")
    shade = Image.new("RGBA", (512, 256), (0, 0, 0, 70))
    img.alpha_composite(shade)
    if logo_img is not None:
        lg = logo_img.resize((400, 200), Image.LANCZOS)
        img.alpha_composite(lg, ((512 - 400) // 2, 28))
    img.save(ROOT / "DarkmoonArcade" / "media" / "tiles" / "bridgearchitect.tga")
    return True


if __name__ == "__main__":
    beam("beam_wood", (0.78, 0.55, 0.3), "wood")
    beam("beam_road", (0.55, 0.37, 0.2), "road")
    beam("beam_steel", (0.6, 0.64, 0.7), "steel")
    beam("beam_rope", (0.82, 0.72, 0.5), "rope")
    disc("joint", 32, (0.55, 0.5, 0.45), (0.2, 0.17, 0.14), (0.85, 0.8, 0.7))
    disc("anchor", 32, (0.85, 0.65, 0.2), (0.3, 0.2, 0.08), (1, 0.9, 0.6))
    water()
    gradient()
    grid()
    splinter()
    crane()
    flag()
    star()
    stars()
    weather()
    lg = logo()
    if not key_art(lg):
        tile(lg)
    print("ok", sorted(p.name for p in OUT.glob("*.tga")))
