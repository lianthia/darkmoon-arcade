"""Generates all textures (TGA) and sounds (OGG) procedurally: python tools/gen_assets.py"""
import math
import pathlib
import subprocess
import tempfile
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "DarkmoonArcade" / "media"
MEDIA.mkdir(parents=True, exist_ok=True)

SS = 4  # supersampling factor for anti-aliasing

# Must match Game.WIDTH / Game.HEIGHT / Game.DEATH_Y; textures are 512 wide and cropped in-game.
FIELD_W, FIELD_H, DEATH_Y = 432, 462, 379

COLORS = {
    "red": (232, 52, 52),
    "yellow": (250, 206, 40),
    "green": (58, 196, 72),
    "blue": (48, 122, 240),
    "purple": (172, 72, 222),
    "orange": (255, 132, 28),
    "pearl": (226, 222, 238),
    "pink": (246, 92, 172),
}


def save_tga(img: Image.Image, name: str, folder: str = "murlocblast"):
    target = MEDIA / folder
    target.mkdir(parents=True, exist_ok=True)
    img.save(target / f"{name}.tga")


def grid(size):
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    u = (xs + 0.5) / size * 2 - 1
    v = (ys + 0.5) / size * 2 - 1
    return u, v


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def to_image(rgb, alpha, size):
    arr = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]])
    img = Image.fromarray((arr * 255).astype(np.uint8), "RGBA")
    return img.resize((size, size), Image.LANCZOS)



def bubble(color, size=64):
    n = size * SS
    u, v = grid(n)
    d = np.sqrt(u * u + v * v)
    r = 0.94
    inside = d < r
    dn = np.clip(d / r, 0, 1)
    nz = np.sqrt(np.clip(1 - dn * dn, 0, 1))
    nx, ny = u / r, v / r
    light = np.array([-0.45, -0.6, 0.66])
    light /= np.linalg.norm(light)
    diffuse = np.clip(nx * light[0] + ny * light[1] + nz * light[2], 0, 1)
    base = np.array(color) / 255.0

    rgb = base * (0.32 + 0.78 * diffuse[..., None])
    # Colored rim light bottom-right sells the glass look.
    rim = smoothstep(0.6, 1.0, dn) * np.clip(nx * 0.5 + ny * 0.7, 0, 1)
    rgb += (base * 0.6 + 0.25)[None, None, :] * (rim * 0.55)[..., None]
    core = np.exp(-((u + 0.1) ** 2 + (v + 0.12) ** 2) / 0.35)
    rgb += base * 0.18 * core[..., None]
    hx, hy = u + 0.3, v + 0.46
    spec = np.exp(-((hx / 0.34) ** 2 + (hy / 0.2) ** 2) * 1.6)
    spec = np.clip(spec * 1.25, 0, 1)
    rgb = rgb * (1 - spec[..., None] * 0.9) + spec[..., None] * 1.0
    spec2 = np.exp(-(((u - 0.38) / 0.12) ** 2 + ((v - 0.45) / 0.07) ** 2) * 2)
    rgb += spec2[..., None] * 0.35
    outline = smoothstep(0.84, 0.99, dn)
    rgb = rgb * (1 - outline[..., None] * 0.55)

    alpha = np.where(inside, 1.0, 0.0) * (1 - smoothstep(0.985, 1.0, d / r))
    return to_image(rgb, alpha, size)


SYMBOLS = ["triangle", "star", "diamond", "square", "plus", "hexagon", "ring", "heart"]


def symbol(kind, size=64):
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx = cy = n / 2
    s = n * 0.2
    white = (255, 255, 255, 255)
    if kind == "triangle":
        pts = [(cx, cy - s * 1.1), (cx + s, cy + s * 0.75), (cx - s, cy + s * 0.75)]
        dr.polygon(pts, fill=white)
    elif kind == "star":
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = s * 1.15 if i % 2 == 0 else s * 0.5
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        dr.polygon(pts, fill=white)
    elif kind == "diamond":
        dr.polygon([(cx, cy - s * 1.15), (cx + s * 0.8, cy), (cx, cy + s * 1.15), (cx - s * 0.8, cy)], fill=white)
    elif kind == "square":
        dr.rectangle([cx - s * 0.8, cy - s * 0.8, cx + s * 0.8, cy + s * 0.8], fill=white)
    elif kind == "plus":
        w = s * 0.38
        dr.rectangle([cx - w, cy - s, cx + w, cy + s], fill=white)
        dr.rectangle([cx - s, cy - w, cx + s, cy + w], fill=white)
    elif kind == "ring":
        dr.ellipse([cx - s, cy - s, cx + s, cy + s], outline=white, width=int(s * 0.42))
    elif kind == "heart":
        r = s * 0.55
        dr.ellipse([cx - 2 * r, cy - r * 1.6, cx, cy + r * 0.4], fill=white)
        dr.ellipse([cx, cy - r * 1.6, cx + 2 * r, cy + r * 0.4], fill=white)
        dr.polygon([(cx - 2 * r + r * 0.12, cy - r * 0.3), (cx + 2 * r - r * 0.12, cy - r * 0.3), (cx, cy + s * 1.1)], fill=white)
    elif kind == "hexagon":
        pts = [(cx + math.cos(math.pi / 6 + i * math.pi / 3) * s, cy + math.sin(math.pi / 6 + i * math.pi / 3) * s) for i in range(6)]
        dr.polygon(pts, fill=white)
    return img.resize((size, size), Image.LANCZOS)



def radial(size, fn):
    n = size * SS
    u, v = grid(n)
    d = np.sqrt(u * u + v * v)
    a = fn(d, u, v)
    return to_image(np.ones(u.shape + (3,)), a, size)


def stone(size=64):
    n = size * SS
    u, v = grid(n)
    d = np.sqrt(u * u + v * v)
    r = 0.94
    dn = np.clip(d / r, 0, 1)
    nz = np.sqrt(np.clip(1 - dn * dn, 0, 1))
    light = np.array([-0.45, -0.6, 0.66])
    light /= np.linalg.norm(light)
    diffuse = np.clip(u / r * light[0] + v / r * light[1] + nz * light[2], 0, 1)
    rng = np.random.default_rng(5)
    tex = fbm(n, n, rng, ((n // 6, 0.5), (n // 14, 0.3), (n // 30, 0.2)))
    base = np.array([0.46, 0.44, 0.42]) * (0.7 + 0.5 * tex)[..., None]
    rgb = base * (0.3 + 0.8 * diffuse[..., None])
    img = to_image(rgb, (d < r) * (1 - smoothstep(0.985, 1.0, d / r)), n)
    dr = ImageDraw.Draw(img)
    crack = (40, 36, 34, 255)
    w = max(2, n // 70)
    dr.line([(n * 0.30, n * 0.18), (n * 0.42, n * 0.40), (n * 0.36, n * 0.55), (n * 0.48, n * 0.78)], fill=crack, width=w)
    dr.line([(n * 0.42, n * 0.40), (n * 0.66, n * 0.46), (n * 0.80, n * 0.38)], fill=crack, width=w)
    dr.line([(n * 0.36, n * 0.55), (n * 0.22, n * 0.62)], fill=crack, width=w)
    rim = Image.fromarray((np.dstack([np.zeros((n, n, 3)), smoothstep(0.86, 0.99, dn) * (d < r) * 0.55]) * 255).astype(np.uint8), "RGBA")
    img = Image.alpha_composite(img, rim)
    return img.resize((size, size), Image.LANCZOS)


def bomb(size=64):
    img = bubble((44, 44, 58), size * SS)
    dr = ImageDraw.Draw(img)
    n = size * SS
    dr.rounded_rectangle([n * 0.40, n * 0.02, n * 0.60, n * 0.16], radius=n * 0.03, fill=(150, 120, 70, 255), outline=(60, 45, 20, 255), width=n // 80)
    dr.line([(n * 0.5, n * 0.04), (n * 0.62, -n * 0.04)], fill=(110, 80, 40, 255), width=n // 40)
    skull = (235, 235, 240, 210)
    dr.ellipse([n * 0.36, n * 0.40, n * 0.64, n * 0.64], fill=skull)
    dr.rectangle([n * 0.42, n * 0.58, n * 0.58, n * 0.70], fill=skull)
    dr.ellipse([n * 0.41, n * 0.47, n * 0.48, n * 0.54], fill=(44, 44, 58, 255))
    dr.ellipse([n * 0.52, n * 0.47, n * 0.59, n * 0.54], fill=(44, 44, 58, 255))
    return img.resize((size, size), Image.LANCZOS)


def glow():
    return radial(64, lambda d, u, v: np.exp(-(d / 0.45) ** 2) * (d < 1))


def ring():
    return radial(64, lambda d, u, v: np.exp(-((d - 0.78) / 0.08) ** 2) * (d < 1))


def spark():
    def fn(d, u, v):
        cross = np.exp(-(np.abs(u) / 0.06) ** 2) * np.exp(-(np.abs(v) / 0.7) ** 2)
        cross += np.exp(-(np.abs(v) / 0.06) ** 2) * np.exp(-(np.abs(u) / 0.7) ** 2)
        return np.clip(cross + np.exp(-(d / 0.18) ** 2), 0, 1)
    return radial(32, fn)


def dot():
    return radial(16, lambda d, u, v: 1 - smoothstep(0.55, 0.95, d))



def value_noise(h, w, scale, rng):
    gh, gw = h // scale + 2, w // scale + 2
    g = rng.random((gh, gw))
    ys = np.linspace(0, gh - 2, h, endpoint=False)
    xs = np.linspace(0, gw - 2, w, endpoint=False)
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = ys - y0, xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(h, w, rng, octaves=((64, 0.5), (32, 0.25), (16, 0.15), (8, 0.1))):
    return sum(value_noise(h, w, s, rng) * a for s, a in octaves)


def background():
    w, h = 512, 512
    used = FIELD_H
    rng = np.random.default_rng(7)
    ys = np.linspace(0, 1, h)[:, None]
    top = np.array([28, 92, 118]) / 255
    bottom = np.array([6, 24, 46]) / 255
    t = np.clip(ys / (used / h), 0, 1)
    rgb = top * (1 - t[..., None]) + bottom * t[..., None]
    rgb = np.broadcast_to(rgb, (h, w, 3)).copy()
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    rays = np.zeros((h, w))
    for x0, width, strength in [(40, 18, 0.10), (120, 30, 0.08), (200, 14, 0.09), (280, 24, 0.07), (360, 18, 0.08), (420, 26, 0.05)]:
        dist = np.abs((xx - x0) - (yy * 0.35))
        rays += strength * np.exp(-(dist / width) ** 2) * np.clip(1 - yy / 380, 0, 1)
    rgb += rays[..., None] * np.array([0.7, 0.95, 1.0])
    caus = fbm(h, w, rng, ((24, 0.6), (12, 0.4)))
    caus = np.clip((caus - 0.55) * 4, 0, 1) * np.clip(1 - yy / 260, 0, 1) * 0.08
    rgb += caus[..., None] * np.array([0.6, 1.0, 1.0])
    # Sand floor below the death line, behind the launcher.
    sand_top = DEATH_Y + 12
    sand = smoothstep(sand_top - 6, sand_top + 18, yy)
    ripple = 0.5 + 0.5 * np.sin(xx * 0.09 + np.sin(yy * 0.3) * 1.5 + yy * 0.2)
    sand_col = np.array([0.40, 0.33, 0.20]) * (0.75 + 0.25 * ripple[..., None]) * (1 - (yy - sand_top) / 200).clip(0.5, 1)[..., None]
    rgb = rgb * (1 - sand[..., None]) + sand_col * sand[..., None]
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    dr = ImageDraw.Draw(img, "RGBA")
    for side in (0, 1):
        for k in range(3):
            base_x = (8 + k * 10) if side == 0 else (FIELD_W - 8 - k * 10)
            height = 110 + k * 45 + int(rng.integers(0, 40))
            phase = rng.random() * 6
            left, right = [], []
            for i in range(0, height, 3):
                x = base_x + math.sin(i * 0.045 + phase) * 7
                half = (4.5 - k) * (1 - i / height) + 0.8
                half *= 1 + 0.35 * math.sin(i * 0.35 + phase)
                y = sand_top + 22 - i
                left.append((x - half, y))
                right.append((x + half, y))
            col = (18 + k * 6, 92 + k * 22, 52 + k * 8, 190 - k * 25)
            dr.polygon(left + right[::-1], fill=col)
    for _ in range(40):
        x, y = rng.integers(10, FIELD_W - 10), rng.integers(20, DEATH_Y - 10)
        r = rng.integers(1, 4)
        dr.ellipse([x - r, y - r, x + r, y + r], outline=(200, 240, 255, 70), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    return img


def ceiling():
    w, h = 512, 512
    rng = np.random.default_rng(3)
    n = fbm(h, w, rng)
    n2 = fbm(h, w, rng, ((16, 0.6), (6, 0.4)))
    stone = np.array([0.30, 0.27, 0.24])
    rgb = stone * (0.55 + 0.7 * n[..., None]) * (0.85 + 0.3 * n2[..., None])
    moss = np.clip((n2 - 0.55) * 3, 0, 1)
    rgb = rgb * (1 - moss[..., None] * 0.5) + np.array([0.18, 0.32, 0.16]) * moss[..., None] * 0.5
    # The game crops this texture from the bottom, so the lit edge must sit at the bottom.
    yy = np.arange(h)[:, None]
    edge = np.exp(-((yy - (h - 7)) / 2.5) ** 2)
    shadow = smoothstep(h - 4, h, yy)
    rgb = rgb + edge[..., None] * 0.25
    rgb = rgb * (1 - shadow[..., None] * 0.6)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    dr = ImageDraw.Draw(img, "RGBA")
    for _ in range(14):
        x = rng.integers(4, w - 4)
        y = h - rng.integers(10, 26)
        r = rng.integers(3, 6)
        dr.ellipse([x - r, y - r, x + r, y + r], fill=(205, 196, 170, 255), outline=(90, 80, 64, 255))
        dr.ellipse([x - r // 2, y - r // 2, x + r // 2, y + r // 2], fill=(60, 52, 44, 255))
    return img


def arrow():
    n = 128 * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx = n / 2
    tip = n * 0.06
    head_base = n * 0.24
    shaft_w = n * 0.035
    head_w = n * 0.11
    outline = (60, 36, 6, 255)
    o = n * 0.012
    dr.polygon([(cx, tip - o), (cx + head_w + o, head_base + o), (cx - head_w - o, head_base + o)], fill=outline)
    dr.rectangle([cx - shaft_w - o, head_base - o, cx + shaft_w + o, n * 0.5], fill=outline)
    dr.polygon([(cx, tip), (cx + head_w, head_base), (cx - head_w, head_base)], fill=(255, 214, 90, 255))
    dr.rectangle([cx - shaft_w, head_base - 2, cx + shaft_w, n * 0.5], fill=(240, 186, 60, 255))
    dr.polygon([(cx, tip + n * 0.02), (cx - head_w * 0.55, head_base - n * 0.015), (cx, head_base - n * 0.015)], fill=(255, 240, 180, 255))
    return img.resize((128, 128), Image.LANCZOS)


def launcher():
    size = 128
    n = size * SS
    u, v = grid(n)
    d = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    ring_mask = smoothstep(0.62, 0.66, d) * (1 - smoothstep(0.9, 0.94, d))
    shade = 0.6 + 0.4 * np.clip(-v * 0.8 + 0.3, 0, 1)
    bands = 0.85 + 0.15 * np.cos((d - 0.78) * 30)
    gold = np.array([0.95, 0.72, 0.25])
    rgb = gold * (shade * bands)[..., None]
    # Nieten
    rivets = np.zeros_like(d)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        rx, ry = math.cos(a) * 0.78, math.sin(a) * 0.78
        rd = np.sqrt((u - rx) ** 2 + (v - ry) ** 2)
        rivets = np.maximum(rivets, 1 - smoothstep(0.035, 0.05, rd))
    rgb = rgb * (1 - rivets[..., None]) + np.array([1.0, 0.93, 0.7]) * rivets[..., None]
    inner = 1 - smoothstep(0.6, 0.64, d)
    rgb = rgb * (1 - inner[..., None]) + np.array([0.04, 0.10, 0.14]) * inner[..., None]
    alpha = np.clip(ring_mask + inner * 0.75, 0, 1)
    return to_image(rgb, alpha, size)



RATE = 44100


def env(n, attack=0.004, decay=0.08):
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def sweep(f0, f1, dur, wave_fn=np.sin, curve=1.0):
    n = int(RATE * dur)
    t = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * t ** curve
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return wave_fn(phase)


def tone(freq, dur, decay=0.25, harmonics=((1, 1.0), (2, 0.35), (3, 0.12))):
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    s = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in harmonics)
    return s * env(n, 0.005, decay)


def noise(dur, rng, lowpass=0.2):
    n = int(RATE * dur)
    x = rng.standard_normal(n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += lowpass * (x[i] - acc)
        y[i] = acc
    return y / (np.abs(y).max() + 1e-9)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(sig, offset, total):
    out = np.zeros(total)
    start = int(offset * RATE)
    out[start: start + len(sig)] = sig[: max(0, total - start)]
    return out


def write_ogg(sig, name, gain=0.8, folder="murlocblast"):
    sig = sig / (np.abs(sig).max() + 1e-9) * gain
    pcm = (sig * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = pathlib.Path(tmp) / "x.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(MEDIA / folder / f"{name}.ogg")],
            check=True,
        )


def sounds():
    rng = np.random.default_rng(11)
    for i, pitch in enumerate((1.0, 1.12, 1.26, 1.41, 1.59), start=1):
        body = sweep(380 * pitch, 980 * pitch, 0.09, curve=0.6) * env(int(RATE * 0.09), 0.002, 0.045)
        click = noise(0.012, rng, 0.6) * env(int(RATE * 0.012), 0.0005, 0.004) * 0.4
        write_ogg(mix(body, click), f"pop{i}", 0.7)
    shoot = mix(
        sweep(260, 1100, 0.11, curve=0.5) * env(int(RATE * 0.11), 0.002, 0.05) * 0.7,
        noise(0.09, rng, 0.08) * env(int(RATE * 0.09), 0.005, 0.03) * 0.5,
    )
    write_ogg(shoot, "shoot", 0.55)
    write_ogg(tone(1500, 0.05, 0.012, ((1, 1.0), (2.7, 0.3))), "bounce", 0.35)
    write_ogg(mix(tone(170, 0.09, 0.03, ((1, 1.0), (2, 0.4))), noise(0.02, rng, 0.3) * 0.3), "land", 0.5)
    drop_n = int(RATE * 0.32)
    t = np.arange(drop_n) / RATE
    wob = np.sin(2 * np.pi * 22 * t) * 0.15
    f = (820 - 600 * (t / t[-1])) * (1 + wob)
    drop = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(drop_n, 0.004, 0.14)
    write_ogg(drop, "drop", 0.6)
    rum_n = int(RATE * 0.6)
    rumble = noise(0.6, rng, 0.02) * env(rum_n, 0.01, 0.25) + tone(55, 0.6, 0.25, ((1, 1.0),)) * 0.8
    write_ogg(rumble, "ceiling", 0.8)
    total = int(RATE * 0.3)
    warn = place(tone(880, 0.09, 0.04), 0, total) + place(tone(880, 0.09, 0.04), 0.14, total)
    write_ogg(warn, "warn", 0.45)
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    total = int(RATE * 1.1)
    clear = sum(place(tone(fq, 0.6, 0.22), i * 0.09, total) for i, fq in enumerate(notes))
    sparkle = sum(place(tone(2093 + 300 * k, 0.15, 0.05, ((1, 1.0),)) * 0.3, 0.45 + k * 0.06, total) for k in range(5))
    write_ogg(clear + sparkle, "clear", 0.7)
    total = int(RATE * 1.3)
    over = sum(place(tone(fq, 0.45, 0.3, ((1, 1.0), (2, 0.5), (3, 0.3))), i * 0.28, total) for i, fq in enumerate([392.0, 349.2, 311.1, 261.6]))
    write_ogg(over, "gameover", 0.7)
    write_ogg(sweep(600, 900, 0.05) * env(int(RATE * 0.05), 0.002, 0.02), "swap", 0.35)
    boom_n = int(RATE * 0.8)
    boom = mix(
        noise(0.8, rng, 0.05) * env(boom_n, 0.002, 0.22),
        sweep(140, 38, 0.8, curve=0.4) * env(boom_n, 0.003, 0.3) * 1.2,
        noise(0.05, rng, 0.7) * env(int(RATE * 0.05), 0.0005, 0.01) * 0.6,
    )
    write_ogg(boom, "explode", 0.9)


def main():
    for i, (name, rgb) in enumerate(COLORS.items(), start=1):
        save_tga(bubble(rgb), f"bubble{i}")
        save_tga(symbol(SYMBOLS[i - 1]), f"symbol{i}")
    save_tga(stone(), "bubble9")
    save_tga(bomb(), "bubble10")
    save_tga(glow(), "glow", "")
    save_tga(ring(), "ring", "")
    save_tga(spark(), "spark", "")
    save_tga(dot(), "dot", "")
    save_tga(background(), "background")
    save_tga(ceiling(), "ceiling")
    save_tga(arrow(), "arrow")
    save_tga(launcher(), "launcher")
    sounds()
    print("Assets erzeugt in", MEDIA)


if __name__ == "__main__":
    main()
