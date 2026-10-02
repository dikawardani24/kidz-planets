#!/usr/bin/env python3
"""Generate NASA-inspired moon surface textures locally with Pillow.

Every moon in the catalog describes surface features reported by NASA
(craters, cracks, volcanoes, two-tone hemispheres...). The 3D scene was
rendering all moons as flat colors because their catalog entries had an
empty textureAsset. This script generates a small stylized equirectangular
JPG per moon under assets/textures/moons/<id>.jpg.

These are kid-friendly stylized interpretations, not NASA photo mosaics.
The exception is Earth's Moon, which already uses the real NASA LRO map
(assets/textures/moon_lroc_2k.jpg) and is wired directly in the catalog.

Usage:
  /usr/bin/python3 tool/generate_moon_textures.py
  /usr/bin/python3 tool/generate_moon_textures.py --only io --only europa
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
# The runnable app is the only package that bundles assets.
ASSETS = ROOT / "apps/kidz_planets/assets"
OUTPUT = ASSETS / "textures/moons"
W, H = 1024, 512

# id -> (base color, crater base color for shading, crater count, grain)
PROFILES: dict[str, tuple[tuple[int, int, int], tuple[int, int, int], int, float]] = {
    "phobos": ((122, 106, 96), (122, 106, 96), 220, 0.30),
    "deimos": ((168, 152, 138), (168, 152, 138), 60, 0.18),
    "io": ((232, 200, 92), (232, 200, 92), 10, 0.12),
    "europa": ((217, 200, 164), (217, 200, 164), 12, 0.08),
    "ganymede": ((155, 147, 135), (155, 147, 135), 120, 0.20),
    "callisto": ((111, 108, 102), (111, 108, 102), 320, 0.28),
    "titan": ((208, 138, 45), (208, 138, 45), 0, 0.10),
    "enceladus": ((238, 244, 251), (238, 244, 251), 40, 0.05),
    "mimas": ((169, 169, 163), (169, 169, 163), 200, 0.22),
    "tethys": ((217, 222, 225), (217, 222, 225), 110, 0.12),
    "iapetus": ((150, 142, 132), (150, 142, 132), 150, 0.22),
    "miranda": ((154, 164, 165), (154, 164, 165), 60, 0.20),
    "ariel": ((191, 197, 196), (191, 197, 196), 70, 0.12),
    "umbriel": ((86, 90, 94), (86, 90, 94), 90, 0.20),
    "titania": ((167, 175, 177), (167, 175, 177), 110, 0.16),
    "oberon": ((133, 139, 140), (133, 139, 140), 170, 0.22),
    "triton": ((208, 199, 194), (208, 199, 194), 30, 0.10),
}


def shade(color: tuple[int, int, int], f: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(c * f))) for c in color)


def grain(img: Image.Image, rng: random.Random, strength: float) -> None:
    px = img.load()
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            v = rng.uniform(-strength, strength)
            r, g, b = px[x, y]
            px[x, y] = (
                max(0, min(255, int(r * (1 + v)))),
                max(0, min(255, int(g * (1 + v)))),
                max(0, min(255, int(b * (1 + v)))),
            )


def crater(
    d: ImageDraw.ImageDraw,
    x: float,
    y: float,
    r: float,
    base: tuple[int, int, int] | None = None,
) -> None:
    # Soft shaded bowl: darkened floor offset toward lower-right (light
    # comes from upper-left), subtle darker rim — no bright white ring.
    # Real HiRISE/MRO frames show muted shading, not cartoon outlines.
    floor = shade(base, 0.72) if base else (60, 58, 55)
    rim = shade(base, 0.55) if base else (48, 46, 44)
    d.ellipse([x - r, y - r, x + r, y + r], fill=rim)
    d.ellipse(
        [x - r * 0.82 + r * 0.12, y - r * 0.82 + r * 0.12,
         x + r * 0.82 + r * 0.12, y + r * 0.82 + r * 0.12],
        fill=floor,
    )


def paint_io(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Sulfur plains + dark volcanic dots with pale frost rings.
    for _ in range(26):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(8, 30)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(240, 224, 170))
    for _ in range(16):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(4, 12)
        d.ellipse([x - r * 2.2, y - r * 2.2, x + r * 2.2, y + r * 2.2],
                  outline=(245, 240, 220), width=3)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(58, 40, 26))
    for _ in range(30):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(6, 26)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(196, 158, 62))


def paint_europa(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Lineae: reddish-brown cracks across bright ice.
    for _ in range(46):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        pts = [(x, y)]
        ang = rng.uniform(0, math.pi * 2)
        for _ in range(6):
            ang += rng.uniform(-0.7, 0.7)
            step = rng.uniform(18, 60)
            x = (x + math.cos(ang) * step) % W
            y = min(H - 4, max(4, y + math.sin(ang) * step))
            pts.append((x, y))
        d.line(pts, fill=(148, 84, 62), width=rng.choice([2, 2, 3, 4]))
    for _ in range(10):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(5, 14)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(186, 138, 116))



def paint_ganymede(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Dark cratered patches + lighter grooved bands.
    for _ in range(9):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(60, 170)
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7],
                  fill=(122, 114, 102))
    for _ in range(26):
        y = rng.uniform(0, H)
        d.line([(0, y), (W, y + rng.uniform(-24, 24))],
               fill=(205, 198, 186), width=2)


def paint_enceladus(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Tiger stripes near the south pole.
    for i in range(4):
        y = H - 60 - i * 22
        d.line([(40, y), (W - 40, y + rng.uniform(-8, 8))],
               fill=(120, 170, 220), width=4)


def paint_mimas(d: ImageDraw.ImageDraw, rng: random.Random, base: tuple[int, int, int] | None = None) -> None:
    # Giant Herschel-scale basin.
    crater(d, W * 0.62, H * 0.45, 66, base)
    crater(d, W * 0.62, H * 0.45, 44, base)


def paint_tethys(d: ImageDraw.ImageDraw, rng: random.Random, base: tuple[int, int, int] | None = None) -> None:
    # Odysseus basin + Ithaca Chasma canyon line.
    crater(d, W * 0.35, H * 0.4, 52, base)
    d.line([(W * 0.1, H * 0.75), (W * 0.9, H * 0.3)],
           fill=(170, 176, 180), width=5)


def paint_iapetus(d: ImageDraw.ImageDraw, rng: random.Random, base: tuple[int, int, int] | None = None) -> None:
    # Two-tone: dark leading hemisphere, bright trailing.
    d.rectangle([0, 0, W // 2, H], fill=(74, 62, 50))
    for _ in range(40):
        crater(d, rng.uniform(0, W // 2), rng.uniform(0, H),
               rng.uniform(2, 6), (74, 62, 50))


def paint_miranda(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Coronae: patchwork ovoids with concentric grooves + scarps.
    for _ in range(4):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        for rr in (64, 48, 32):
            d.ellipse([x - rr, y - rr * 0.7, x + rr, y + rr * 0.7],
                      outline=(176, 186, 187), width=4)
    for _ in range(12):
        y = rng.uniform(0, H)
        d.line([(0, y), (W, y + rng.uniform(-40, 40))],
               fill=(110, 120, 122), width=2)


def paint_ariel(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Bright plains + long graben valleys.
    for _ in range(14):
        y = rng.uniform(0, H)
        d.line([(0, y), (W, y + rng.uniform(-30, 30))],
               fill=(150, 160, 160), width=3)


def paint_titan(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Opaque haze bands + dark polar seas, no visible craters.
    for _ in range(16):
        y = rng.uniform(0, H)
        col = rng.choice([(232, 168, 80), (188, 118, 48), (222, 150, 60)])
        d.line([(0, y), (W, y + rng.uniform(-14, 14))], fill=col, width=14)
    for _ in range(5):
        x = rng.uniform(W * 0.2, W * 0.8)
        r = rng.uniform(14, 40)
        d.ellipse([x - r, 30, x + r, 30 + r * 0.7], fill=(70, 60, 52))


def paint_triton(d: ImageDraw.ImageDraw, rng: random.Random) -> None:
    # Cantaloupe terrain + pink cap + geyser streaks.
    for _ in range(120):
        x, y = rng.uniform(0, W), rng.uniform(H * 0.35, H)
        r = rng.uniform(4, 12)
        d.ellipse([x - r, y - r, x + r, y + r],
                  outline=(168, 160, 158), width=2)
    d.rectangle([0, 0, W, H * 0.28], fill=(232, 214, 214))
    for _ in range(18):
        x = rng.uniform(0, W)
        d.line([(x, rng.uniform(H * 0.3, H * 0.5)),
                (x + rng.uniform(-30, 30), rng.uniform(H * 0.5, H * 0.8))],
               fill=(90, 78, 78), width=2)


def paint_phobos(d: ImageDraw.ImageDraw, rng: random.Random,
                 base: tuple[int, int, int]) -> None:
    # Phobos (MRO/HiRISE): dark gray-brown rubble pile dominated by the
    # muted, eroded Stickney depression — a soft tonal low, NOT a black
    # hole. Faint short groove striations cluster near Stickney; a whisper
    # of redder regolith sits on one rim flank. Everything muted.
    sx, sy, sr = W * 0.36, H * 0.40, 88
    # Stickney as layered soft tonal steps, darkest only ~0.8 of base.
    for rr, f in ((88, 0.88), (70, 0.82), (52, 0.78)):
        d.ellipse([sx - rr, sy - rr * 0.9, sx + rr, sy + rr * 0.9],
                  fill=shade(base, f))
    # Faint inner pit, still well above black.
    d.ellipse([sx - 26, sy - 22, sx + 26, sy + 22], fill=shade(base, 0.72))
    # Grooves: short, faint, roughly parallel, fading away from Stickney.
    for _ in range(30):
        cx = rng.uniform(W * 0.1, W * 0.75)
        cy = rng.uniform(H * 0.2, H * 0.8)
        length = rng.uniform(20, 70)
        ang = rng.uniform(-0.25, 0.25)
        dx, dy = math.cos(ang) * length / 2, math.sin(ang) * length / 2
        d.line([(cx - dx, cy - dy), (cx + dx, cy + dy)],
               fill=shade(base, 0.90), width=1)
    # Subtle redder wash hugging Stickney's flank — low contrast.
    for _ in range(40):
        x = rng.uniform(sx - 110, sx + 110)
        y = rng.uniform(sy - 90, sy + 90)
        r = rng.uniform(4, 14)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(132, 108, 94))


def paint_deimos(d: ImageDraw.ImageDraw, rng: random.Random,
                 base: tuple[int, int, int]) -> None:
    # Deimos (MRO/HiRISE): smooth dust-mantled face — craters are soft,
    # shallow, partly infilled, almost no rim contrast. Slightly warmer
    # and brighter than Phobos, gentle large-scale mottling only.
    for _ in range(46):  # broad soft mottling, very low contrast
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(18, 60)
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7],
                  fill=shade(base, rng.uniform(0.94, 1.03)))
    for _ in range(30):  # shallow subdued bowls
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(5, 20)
        d.ellipse([x - r, y - r, x + r, y + r], fill=shade(base, 0.90))
        d.ellipse([x - r * 0.55, y - r * 0.55, x + r * 0.55, y + r * 0.55],
                  fill=shade(base, 0.96))


def craters(d: ImageDraw.ImageDraw, rng: random.Random, n: int,
            rmin: float, rmax: float,
            base: tuple[int, int, int] | None = None) -> None:
    for _ in range(n):
        crater(d, rng.uniform(0, W), rng.uniform(0, H),
               rng.uniform(rmin, rmax), base)


FEATURES = {
    "io": paint_io,
    "europa": paint_europa,
    "ganymede": paint_ganymede,
    "enceladus": paint_enceladus,
    "mimas": paint_mimas,
    "tethys": paint_tethys,
    "iapetus": paint_iapetus,
    "miranda": paint_miranda,
    "ariel": paint_ariel,
    "titan": paint_titan,
    "triton": paint_triton,
}


def render(moon_id: str) -> Image.Image:
    base, _, crater_n, grain_strength = PROFILES[moon_id]
    rng = random.Random(hash(moon_id) & 0xFFFFFFFF)
    img = Image.new("RGB", (W, H), base)
    d = ImageDraw.Draw(img)
    for y in range(H):
        f = 1.0 - 0.10 * abs(y / H - 0.5) * 2
        d.line([(0, y), (W, y)], fill=shade(base, f))
    if moon_id == "phobos":
        paint_phobos(d, rng, base)
        craters(d, rng, 110, 2, 9, base)  # Phobos IS heavily cratered
    elif moon_id == "deimos":
        paint_deimos(d, rng, base)
        # No extra sharp craters — paint_deimos already laid soft bowls.
    else:
        FEATURES.get(moon_id, lambda d, r, b=None: None)(d, rng, base)
    if crater_n and moon_id not in ("phobos", "deimos"):
        scale = 3.0 if moon_id == "callisto" else 1.0
        craters(d, rng, crater_n, 1.5 * scale, 7 * scale, base)
    grain(img, rng, grain_strength)
    return img


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", action="append",
                        help="Moon id; repeatable.")
    args = parser.parse_args()
    selected = args.only or list(PROFILES)
    unknown = sorted(set(selected) - PROFILES.keys())
    if unknown:
        parser.error("Unknown moon id(s): " + ", ".join(unknown))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for moon_id in selected:
        path = OUTPUT / f"{moon_id}.jpg"
        render(moon_id).save(path, quality=88)
        print(f"create {path.relative_to(ROOT)}")
    print(f"Processed {len(selected)} moon textures.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
