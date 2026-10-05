"""Converts the hand-made artwork in art/ into game textures: python tools/import_art.py"""
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "DarkmoonArcade" / "media"


def feathered_logo():
    src = Image.open(ROOT / "art" / "logo_source.png").convert("RGB")
    w, h = src.size
    # Elliptical feather so the dark backdrop of the artwork melts into the hub background.
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    nx, ny = (xs - w / 2) / (w * 0.5), (ys - h * 0.47) / (h * 0.5)
    d = np.sqrt(nx ** 2 + ny ** 2)
    alpha = np.clip((1.02 - d) / 0.16, 0, 1)
    # Keep the bright artwork fully opaque even near the edge.
    lum = np.asarray(src).astype(float).max(axis=2) / 255
    alpha = np.maximum(alpha, np.clip((lum - 0.28) * 3, 0, 1) * (d < 1.08))
    rgba = np.dstack([np.asarray(src), (alpha * 255).astype(np.uint8)])
    logo = Image.fromarray(rgba, "RGBA").resize((512, 341), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.paste(logo, (0, 0))
    canvas.save(MEDIA / "logo.tga")


def moon_icon():
    src = Image.open(ROOT / "art" / "logo_source.png").convert("RGBA")
    cx, cy, r = 735, 228, 168
    crop = src.crop((cx - r, cy - r, cx + r, cy + r)).resize((256, 256), Image.LANCZOS)
    mask = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(mask).ellipse([8, 8, 1016, 1016], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(4)).resize((256, 256), Image.LANCZOS)
    crop.putalpha(mask)
    crop.resize((64, 64), Image.LANCZOS).save(MEDIA / "icon.tga")
    crop.resize((128, 128), Image.LANCZOS).save(MEDIA / "portrait.tga")


if __name__ == "__main__":
    feathered_logo()
    moon_icon()
    print("Artwork imported into", MEDIA)
