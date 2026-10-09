"""Renders the Mercenaries views to PNG without the game: python tests/render.py [out_dir] [view filter]

The addon runs against a geometry mock (render_mock.lua); every visible texture and text is drawn
with the real art: client files and atlases from the installed WoW: Forever client (tools/casc_local.py),
addon textures from the repo. Files the client lacks are drawn green, like the client does.
Models and creature portraits cannot be rendered and show as labelled placeholders.
"""
import math
import pathlib
import re
import sys

from lupa import luajit21 as lupa
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "DarkmoonArcade"
sys.path.insert(0, str(ROOT / "tools"))
import atlas_preview as ap  # noqa: E402
import casc_local  # noqa: E402

S = 1.5
CACHE = ROOT / "tools" / ".cache"


class Assets:
    def __init__(self):
        self.client = casc_local.Client()
        self.images = {}
        atlases = {r["ID"]: r for r in ap.table("UiTextureAtlas")}
        self.atlas = {}
        for m in ap.table("UiTextureAtlasMember"):
            a = atlases.get(m["UiTextureAtlasID"])
            if a:
                self.atlas[m["CommittedName"].lower()] = (int(a["FileDataID"]), int(a["AtlasWidth"]), int(a["AtlasHeight"]),
                                                          int(m["CommittedLeft"]), int(m["CommittedTop"]),
                                                          int(m["CommittedRight"]), int(m["CommittedBottom"]))
        self.missing = set()

    def file_id(self, path):
        return self.client.file_id(path)

    def by_id(self, fid):
        if fid in self.images:
            return self.images[fid]
        img = None
        status = self.client.status(fid)
        try:
            if status == "ok":
                img = ap.decode_blp(self.client.read(fid))
            elif status == "not downloaded":
                # In the client's root but streamed on first use: fetch the same file from wago.
                img = ap.texture(fid).convert("RGBA")
        except Exception:  # noqa: BLE001 - unreadable formats count as missing
            img = None
        if img is None:
            self.missing.add(fid)
        self.images[fid] = img
        return img

    def texture(self, file):
        """Image for a SetTexture argument, or None when the client cannot show it."""
        if file is None:
            return None
        if re.fullmatch(r"\d+(\.0)?", file):
            return self.by_id(int(float(file)))
        low = file.lower().replace("\\", "/")
        m = re.match(r"interface/addons/darkmoonarcade[^/]*/(.*)", low)
        if m:
            local = ADDON / m.group(1)
            for cand in (local, local.with_suffix(".tga"), local.with_suffix(".blp")):
                if cand.exists():
                    key = str(cand)
                    if key not in self.images:
                        self.images[key] = Image.open(cand).convert("RGBA")
                    return self.images[key]
            self.missing.add(file)
            return None
        fid = self.file_id(file)
        if fid is None:
            self.missing.add(file)
            return None
        return self.by_id(fid)

    def atlas_image(self, name):
        info = self.atlas.get(name.lower())
        if not info:
            self.missing.add("atlas:" + name)
            return None
        fid, aw, ah, l, t, r, b = info
        tex = self.by_id(fid)
        if tex is None:
            return None
        sx, sy = tex.width / aw, tex.height / ah
        return tex.crop((int(l * sx), int(t * sy), int(r * sx), int(b * sy)))

    def font(self, size):
        path = CACHE / "frizqt.ttf"
        if not path.exists():
            fid = self.file_id("Fonts/FRIZQT__.TTF")
            path.write_bytes(self.client.read(fid))
        return ImageFont.truetype(str(path), max(6, int(round(size))))


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else []


def crop_coord(img, coord):
    u0, u1, v0, v1 = coord
    flip_x, flip_y = u0 > u1, v0 > v1
    u0, u1 = sorted((u0, u1))
    v0, v1 = sorted((v0, v1))
    box = (int(max(0, u0) * img.width), int(max(0, v0) * img.height), int(min(1, u1) * img.width), int(min(1, v1) * img.height))
    if box[2] <= box[0] or box[3] <= box[1]:
        return img
    out = img.crop(box)
    if flip_x:
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    if flip_y:
        out = out.transpose(Image.FLIP_TOP_BOTTOM)
    return out


def tint(img, color, alpha, desat):
    r, g, b, a = img.split()
    if desat:
        grey = img.convert("L")
        r = g = b = grey
    cr, cg, cb, ca = (list(color) + [1, 1, 1, 1])[:4]
    r = r.point(lambda v: int(v * cr))
    g = g.point(lambda v: int(v * cg))
    b = b.point(lambda v: int(v * cb))
    a = a.point(lambda v: int(v * ca * alpha))
    return Image.merge("RGBA", (r, g, b, a))


COLOR_CODE = re.compile(r"\|c([0-9a-fA-F]{8})|\|r|\|T.*?\|t")


def draw_item(canvas, item, assets):
    x0, y0, x1, y1 = [v * S for v in lua_list(item["rect"])]
    w, h = int(round(x1 - x0)), int(round(y1 - y0))
    if w <= 0 or h <= 0:
        return
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    kind = item["kind"]
    alpha = item["alpha"] if item["alpha"] is not None else 1
    if kind == "model":
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle((x0, y0, x1, y1), 12, fill=(120, 140, 170, int(90 * alpha)), outline=(200, 220, 255, int(160 * alpha)))
        d.text(((x0 + x1) / 2, (y0 + y1) / 2), "3D " + str(item["display"]), fill=(255, 255, 255, int(220 * alpha)), anchor="mm")
    elif kind == "texture":
        if item["solid"] is not None:
            c = lua_list(item["solid"])
            img = Image.new("RGBA", (w, h), tuple(int(v * 255) for v in c[:3]) + (int(255 * (c[3] if len(c) > 3 else 1)),))
        elif item["portrait"] is not None:
            img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            d.rectangle((0, 0, 63, 63), fill=(150, 110, 80, 255))
            d.ellipse((18, 8, 46, 40), fill=(225, 190, 150, 255))
            d.ellipse((6, 38, 58, 90), fill=(90, 70, 120, 255))
        else:
            if item["atlas"] is not None:
                img = assets.atlas_image(item["atlas"])
            else:
                img = assets.texture(item["file"])
            if img is None:
                img = Image.new("RGBA", (8, 8), (0, 255, 0, 255))
            else:
                img = crop_coord(img, lua_list(item["coord"]))
        if item["rot"]:
            img = img.rotate(math.degrees(item["rot"]), resample=Image.BICUBIC)
        img = img.resize((w, h), Image.BICUBIC)
        img = tint(img, lua_list(item["color"]), alpha, item["desat"])
        if item["mask"] is not None:
            mask = assets.texture(item["mask"]["file"])
            if mask is not None:
                mx0, my0, mx1, my1 = [v * S for v in lua_list(item["mask"]["rect"])]
                mw, mh = max(1, int(mx1 - mx0)), max(1, int(my1 - my0))
                m = Image.new("L", (w, h), 0)
                src = mask.convert("RGBA").resize((mw, mh), Image.BICUBIC)
                ma = src.split()[3] if src.getextrema()[3][0] < 255 else src.convert("L")
                m.paste(ma, (int(mx0 - x0), int(my0 - y0)))
                img.putalpha(ImageChops.multiply(img.split()[3], m))
        if item["blend"] == "ADD":
            r, g, b, a = img.split()
            a_f = a.point(lambda v: v / 255)
            add = Image.merge("RGB", tuple(ImageChops.multiply(ch, a) for ch in (r, g, b)))
            region = canvas.crop((int(x0), int(y0), int(x0) + w, int(y0) + h)).convert("RGB")
            summed = ImageChops.add(region, add)
            clip_paste(canvas, summed.convert("RGBA"), int(x0), int(y0), item)
            return
        layer.alpha_composite(img, (int(x0), int(y0))) if 0 <= int(x0) and 0 <= int(y0) else layer.paste(img, (int(x0), int(y0)), img)
    elif kind == "text":
        text = item["text"]
        color = lua_list(item["color"])
        m = re.match(r"\|c([0-9a-fA-F]{8})", text)
        if m:
            hx = m.group(1)
            color = [int(hx[2:4], 16) / 255, int(hx[4:6], 16) / 255, int(hx[6:8], 16) / 255, 1]
        text = COLOR_CODE.sub(lambda mm: "  " if mm.group(0).startswith("|T") else "", text)
        font = assets.font(item["size"] * S)
        flags = item["flags"] or ""
        stroke = 2 if "THICK" in flags else (1 if "OUTLINE" in flags else 0)
        lines = []
        for para in text.split("\n"):
            if item["wrap"] is not False and w > 0:
                words, cur = para.split(" "), ""
                for word in words:
                    trial = (cur + " " + word).strip()
                    if cur and font.getlength(trial) > w + 2:
                        lines.append(cur)
                        cur = word
                    else:
                        cur = trial
                lines.append(cur)
            else:
                line = para
                while line and font.getlength(line) > w + 2 and item["wrap"] is False:
                    line = line[:-1]
                lines.append(line if line == para else line[:-1] + "…")
        lh = item["size"] * S * 1.15
        total = lh * len(lines)
        jv = item["justifyV"]
        ty = y0 if jv == "TOP" else (y1 - total if jv == "BOTTOM" else (y0 + y1) / 2 - total / 2)
        d = ImageDraw.Draw(layer)
        fill = tuple(int(v * 255) for v in color[:3]) + (int(255 * alpha * (color[3] if len(color) > 3 else 1)),)
        for i, line in enumerate(lines):
            lw = font.getlength(line)
            jh = item["justifyH"]
            tx = x0 if jh == "LEFT" else (x1 - lw if jh == "RIGHT" else (x0 + x1) / 2 - lw / 2)
            if item["shadow"] and not stroke:
                d.text((tx + 1, ty + i * lh + 1), line, font=font, fill=(0, 0, 0, int(200 * alpha)))
            d.text((tx, ty + i * lh), line, font=font, fill=fill, stroke_width=stroke, stroke_fill=(0, 0, 0, int(255 * alpha)))
    clip_composite(canvas, layer, item)


def clip_rect(item, size):
    if item["clip"] is None:
        return None
    c = [v * S for v in lua_list(item["clip"])]
    return (max(0, int(c[0])), max(0, int(c[1])), min(size[0], int(c[2])), min(size[1], int(c[3])))


def clip_composite(canvas, layer, item):
    box = clip_rect(item, canvas.size)
    if box:
        mask = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        mask.paste(layer.crop(box), box[:2])
        layer = mask
    canvas.alpha_composite(layer)


def clip_paste(canvas, img, x, y, item):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(img, (x, y))
    box = clip_rect(item, canvas.size)
    full = canvas.copy()
    full.paste(layer, (0, 0), Image.new("L", canvas.size, 0))
    region = Image.new("L", canvas.size, 0)
    region.paste(255, (max(0, x), max(0, y), x + img.width, y + img.height))
    if box:
        keep = Image.new("L", canvas.size, 0)
        keep.paste(255, box)
        region = ImageChops.multiply(region, keep)
    canvas.paste(layer, (0, 0), region)


def main():
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools" / ".cache" / "render"
    out.mkdir(parents=True, exist_ok=True)
    only = sys.argv[2] if len(sys.argv) > 2 else None
    assets = Assets()
    toc = (ADDON / "DarkmoonArcade.toc").read_text(encoding="utf-8")
    files = [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_FILES = lua.table_from(files)
    g.ADDON_SOURCES = lua.table_from({f: (ADDON / f).read_text(encoding="utf-8") for f in files})
    g.RENDER_ATLASES = lua.table_from({name: True for name in assets.atlas})
    g.RENDER_ONLY = only
    smoke = (ROOT / "tests" / "smoke.lua").read_text(encoding="utf-8")
    header = smoke[:smoke.index("\nlocal ns = {}")]
    script = header + "\n" + (ROOT / "tests" / "render_mock.lua").read_text(encoding="utf-8") + "\n" + \
        (ROOT / "tests" / "render.lua").read_text(encoding="utf-8")
    g.print = lambda *a: __builtins__.print(*a)
    try:
        lua.execute(script)
    finally:
        errors = g.DarkmoonArcadeDB and g.DarkmoonArcadeDB.errors
        if errors:
            for i in range(1, len(errors) + 1):
                print("captured:", errors[i].message)
    for shot in lua_list(g.Shots):
        canvas = Image.new("RGBA", (int(shot["w"] * S), int(shot["h"] * S)), (10, 8, 6, 255))
        for item in lua_list(shot["items"]):
            draw_item(canvas, item, assets)
        path = out / f"{shot['name']}.png"
        canvas.convert("RGB").save(path)
        print("wrote", path)
    if assets.missing:
        print("missing in client:", sorted(map(str, assets.missing)))


if __name__ == "__main__":
    main()
