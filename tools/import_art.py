"""Converts the hand-made artwork in art/ into game textures: python tools/import_art.py"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "DarkmoonArcade" / "media"


# The arcade's logo (art/darkmoon_logo.png, drawn by hand with a transparent background) at the top
# of a 512x256 texture (512x172 used); UI/Window.lua shows that part in the header.
LOGO_W = 512


def arcade_logo():
    src = Image.open(ROOT / "art" / "darkmoon_logo.png").convert("RGBA")
    src = src.crop(src.getbbox())
    h = round(LOGO_W * src.height / src.width)
    canvas = Image.new("RGBA", (LOGO_W, 256), (0, 0, 0, 0))
    canvas.paste(src.resize((LOGO_W, h), Image.LANCZOS), (0, 0))
    canvas.save(MEDIA / "logo.tga")
    print("arcade logo", LOGO_W, "x", h)


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


def mercenaries_logo():
    """The Mercenaries title (already cut out), 960 wide with 32 px room all round at the top of a
    1024x512 texture, plus a matching soft dark halo that lifts it off busy backgrounds."""
    src = Image.open(ROOT / "art" / "mercenaries_logo.webp").convert("RGBA")
    src = src.crop(src.getbbox())
    h = round(960 * src.height / src.width)
    canvas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
    canvas.paste(src.resize((960, h), Image.LANCZOS), (32, 32))
    canvas.save(MEDIA / "mercs" / "logo.tga")
    alpha = canvas.split()[3].filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(12))
    alpha = alpha.point(lambda v: min(255, int(v * 2.4)))
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    halo.putalpha(alpha)
    halo.save(MEDIA / "mercs" / "logo_shadow.tga")
    print("mercenaries logo used height", h + 64)


if __name__ == "__main__":
    arcade_logo()
    moon_icon()
    mercenaries_logo()
    print("Artwork imported into", MEDIA)
