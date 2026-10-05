"""Converts the hand-made artwork in art/ into game textures: python tools/import_art.py"""
import pathlib

from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "DarkmoonArcade" / "media"


def background_mask(src):
    """True where the artwork shows its dark backdrop; the black outline of the logo is kept."""
    h, w, _ = src.shape
    mx = src.max(axis=2)
    r, b = src[..., 0], src[..., 2]
    colored = ((b > r + 6) & (mx > 40)) | (mx >= 200) | ((r > 150) & (src[..., 1] > 90))
    protected = np.asarray(Image.fromarray((colored * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(19))) > 0
    passable = ((mx > 24) & (b <= r + 6) & (mx < 200)) | ((mx <= 24) & ~protected) | ((b > r) & (mx > 24) & (mx < 48))
    seen = np.zeros((h, w), bool)
    queue = deque()
    for y in range(h):
        for x in (0, w - 1):
            queue.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        if seen[y, x] or not passable[y, x]:
            continue
        seen[y, x] = True
        if y > 0: queue.append((y - 1, x))
        if y < h - 1: queue.append((y + 1, x))
        if x > 0: queue.append((y, x - 1))
        if x < w - 1: queue.append((y, x + 1))
    return seen


def cutout_logo():
    src = np.asarray(Image.open(ROOT / "art" / "logo_source.png").convert("RGB"))
    alpha = np.where(background_mask(src.astype(int)), 0, 255).astype(np.uint8)
    alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(1.2)))
    logo = Image.fromarray(np.dstack([src, alpha]), "RGBA")
    logo = logo.crop(logo.getbbox()).resize((512, 330), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(logo, (0, 0))
    canvas.save(MEDIA / "logo.tga")


def moon_icon():
    # The source has a baked-in checkerboard instead of transparency; the moon is a circle, so mask it.
    src = Image.open(ROOT / "art" / "moon_icon.png").convert("RGBA")
    w, h = src.size
    ss = 4
    mask = Image.new("L", (w * ss, h * ss), 0)
    cx, cy, r = 298 * ss, 300 * ss, 293 * ss
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    src.putalpha(mask.resize((w, h), Image.LANCZOS))
    side = 600
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(src, ((side - w) // 2, (side - h) // 2))
    square.resize((64, 64), Image.LANCZOS).save(MEDIA / "icon.tga")
    square.resize((128, 128), Image.LANCZOS).save(MEDIA / "portrait.tga")


if __name__ == "__main__":
    cutout_logo()
    moon_icon()
    print("Artwork imported into", MEDIA)
