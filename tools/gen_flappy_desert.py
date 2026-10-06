"""Generates the Horde desert scenery for Flappy Griffin: python tools/gen_flappy_desert.py"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_assets as ga
import gen_arcade as arc

H = 462


def sky():
    h, w = 512, 512
    yy = np.linspace(0, 1, h)[:, None, None] * np.ones((1, w, 1))
    top = np.array([0.42, 0.30, 0.42])
    mid = np.array([0.95, 0.58, 0.32])
    low = np.array([1.0, 0.86, 0.55])
    t = np.clip(yy / (H / h), 0, 1)
    rgb = np.where(t < 0.55, top + (mid - top) * (t / 0.55), mid + (low - mid) * ((t - 0.55) / 0.45))
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    sun = np.exp(-(((xs - 140) / 60) ** 2 + ((ys - 250) / 60) ** 2))
    rgb = rgb + sun[..., None] * np.array([0.4, 0.3, 0.1])
    return arc.to_rgba(rgb)


def dust():
    """Thin streaks of drifting dust instead of clouds; tiles horizontally."""
    w, h = 512, 256
    rng = np.random.default_rng(33)
    img = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for _ in range(14):
        cx, cy = rng.integers(0, w * 2), rng.integers(40, h * 2 - 80)
        length, thick = rng.integers(160, 360), rng.integers(10, 26)
        for dx in (-w * 2, 0, w * 2):
            dr.ellipse([cx - length + dx, cy - thick, cx + length + dx, cy + thick], fill=(255, 226, 180, 70))
    img = img.filter(ImageFilter.GaussianBlur(14))
    return img.resize((w, h), Image.LANCZOS)


def mesas():
    """Flat-topped red buttes of the Barrens and Durotar."""
    w, h = 512, 256
    rng = np.random.default_rng(12)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for col, base, count, height in [((170, 96, 70, 255), 150, 5, 80), ((128, 62, 44, 255), 190, 6, 55)]:
        x = -40
        while x < w + 40:
            width = int(rng.integers(50, 120))
            top = base - int(rng.integers(height // 2, height))
            slope = int(rng.integers(10, 22))
            for dx in (0,):
                pts = [(x + dx, h), (x + dx + slope, top), (x + dx + width - slope, top), (x + dx + width, h)]
                dr.polygon(pts, fill=col)
                dr.line([(x + dx + slope, top), (x + dx + width - slope, top)], fill=(220, 150, 100, 255), width=3)
            x += width + int(rng.integers(10, 60))
    # Make the strip tile: blend the right edge into the left.
    arr = np.array(img).astype(float)
    blend = 40
    for i in range(blend):
        a = i / blend
        arr[:, w - blend + i] = arr[:, w - blend + i] * (1 - a) + arr[:, i] * a
    return Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.8))


def tile_texture(base, seed, cracks):
    """128px seamless noise texture (sand or rock)."""
    n = 128
    rng = np.random.default_rng(seed)
    noise = ga.value_noise(n, n, 16, rng) * 0.5 + ga.value_noise(n, n, 8, rng) * 0.3 + ga.value_noise(n, n, 4, rng) * 0.2
    noise = (noise + np.roll(noise, n // 2, axis=0) + np.roll(noise, n // 2, axis=1)) / 3
    rgb = np.array(base) * (0.8 + 0.4 * noise)[..., None]
    img = arc.to_rgba(rgb)
    if cracks:
        dr = ImageDraw.Draw(img)
        for _ in range(cracks):
            x, y = rng.integers(0, n), rng.integers(0, n)
            for _ in range(5):
                nx, ny = x + rng.integers(-14, 15), y + rng.integers(4, 18)
                dr.line([(x, y), (nx, ny)], fill=(70, 34, 22, 160), width=1)
                x, y = nx % n, ny % n
    return img


def ground_lip():
    w, h = 512, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    rng = np.random.default_rng(6)
    dr.rectangle([0, 24, w, 36], fill=(196, 140, 86, 255))
    dr.rectangle([0, 34, w, 40], fill=(150, 98, 60, 200))
    for x in range(0, w, 24):
        r = int(rng.integers(3, 7))
        dr.ellipse([x - r, 22 - r, x + r, 22 + r], fill=(170, 112, 70, 255))
    return img


def pillar_cap():
    """Horde cap: dark iron with red trim and spikes."""
    w, h = 128, 32
    n = 4
    img = Image.new("RGBA", (w * n, h * n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    s = n
    dr.rounded_rectangle([2 * s, 6 * s, (w - 2) * s, (h - 4) * s], radius=3 * s, fill=(70, 60, 56, 255), outline=(30, 22, 20, 255), width=2 * s)
    dr.rectangle([2 * s, (h - 11) * s, (w - 2) * s, (h - 6) * s], fill=(170, 30, 24, 255))
    for i in range(7):
        x = (12 + i * 17) * s
        dr.polygon([(x - 4 * s, 7 * s), (x, 0), (x + 4 * s, 7 * s)], fill=(200, 196, 186, 255))
    return img.resize((w, h), Image.LANCZOS)


def main():
    ga.save_tga(sky(), "sky_desert", "flappy")
    ga.save_tga(dust(), "clouds_desert", "flappy")
    ga.save_tga(mesas(), "mountains_desert", "flappy")
    ga.save_tga(ground_lip(), "ground_lip_desert", "flappy")
    ga.save_tga(tile_texture((0.86, 0.62, 0.38), 3, 0), "sand", "flappy")
    ga.save_tga(tile_texture((0.66, 0.36, 0.24), 4, 10), "rock_desert", "flappy")
    ga.save_tga(pillar_cap(), "pillar_cap_horde", "flappy")
    print("Desert scenery generated")


if __name__ == "__main__":
    main()
