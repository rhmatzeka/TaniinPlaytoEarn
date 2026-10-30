"""Generates the extra world sprites in assets/images/dunia/ and dekor/.

Villagers are palette swaps of the farmer sheets (assets/images/walk.png and
idle.png, 32 px frames). Village props come from tool/aset_dekor.py and
wildlife, water plants, rocks and stumps from tool/aset_alam.py. Run from
taniin_flutter/:

    python3 tool/aset_dunia.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

import aset_alam
import aset_dekor

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "images"
OUT = SRC / "dunia"


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


# --- Villagers -------------------------------------------------------------

# Farmer palette: hair greys, overalls, shirt, skin.
HAIR = ["#0e0e0e", "#1d1d1d", "#2f2f2f", "#4e4e4e", "#7b7b7b"]
OVERALLS = "#1a3473"
SHIRT = "#2eafc7"
SKIN = "#ffc68b"
SKIN_SHADE = "#ef7b55"

VILLAGERS = {
    # name: hair (dark to light), overalls, shirt, skin, skin shade, hat
    "sari": (["#2a160c", "#3e2414", "#5a3520", "#7a4b2c", "#a06a40"], "#8a2342", "#f2c14e", None, None, False),
    "budi": (["#3a3a3a", "#555555", "#7a7a7a", "#a3a3a3", "#d0d0d0"], "#2f6b3a", "#efe6d2", "#e9ad74", "#c56a43", False),
    "rani": (["#5a1e08", "#7e2c0c", "#a8441a", "#c96428", "#e08a44"], "#5a2f86", "#f08fb2", None, None, False),
    "karto": (["#8a8a8a", "#a8a8a8", "#c4c4c4", "#dedede", "#f4f4f4"], "#6b4423", "#dcc08a", "#e2a46c", "#b9643f", True),
}

STRAW = [hexc("#5a3a12"), hexc("#b8862e"), hexc("#e8c25a"), hexc("#f6dd8a")]


def swap(image, hair, overalls, shirt, skin, shade):
    mapping = {hexc(src): hexc(dst) for src, dst in zip(HAIR, hair)}
    mapping[hexc(OVERALLS)] = hexc(overalls)
    mapping[hexc(SHIRT)] = hexc(shirt)
    if skin:
        mapping[hexc(SKIN)] = hexc(skin)
        mapping[hexc(SKIN_SHADE)] = hexc(shade)
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y] in mapping:
                px[x, y] = mapping[px[x, y]]
    return out


def add_hats(sheet, hair_colors):
    """Draws a straw caping over the hair of every 32 px frame."""
    hair = {hexc(c) for c in hair_colors}
    px = sheet.load()
    draw = ImageDraw.Draw(sheet)
    for fy in range(0, sheet.height, 32):
        for fx in range(0, sheet.width, 32):
            cells = [
                (x, y)
                for y in range(fy, fy + 32)
                for x in range(fx, fx + 32)
                if px[x, y] in hair
            ]
            if not cells:
                continue
            top = min(y for _, y in cells)
            left = min(x for x, _ in cells)
            right = max(x for x, _ in cells)
            cx = (left + right) // 2
            brim = top + 4
            # Conical caping: wide brim, pointed crown.
            draw.rectangle([left - 2, brim, right + 2, brim + 1], fill=STRAW[0])
            draw.rectangle([left - 1, brim, right + 1, brim], fill=STRAW[2])
            for row in range(4):
                half = 1 + row * 2
                y = top + row
                draw.line([cx - half, y, cx + half, y], fill=STRAW[2 if row % 2 else 3])
                draw.point([(cx - half - 1, y), (cx + half + 1, y)], fill=STRAW[0])
            draw.point([(cx, top - 1)], fill=STRAW[0])
    return sheet


def villagers():
    walk = Image.open(SRC / "walk.png").convert("RGBA")
    idle = Image.open(SRC / "idle.png").convert("RGBA")
    for name, (hair, overalls, shirt, skin, shade, hat) in VILLAGERS.items():
        for kind, sheet in (("jalan", walk), ("diam", idle)):
            out = swap(sheet, hair, overalls, shirt, skin, shade)
            if hat:
                out = add_hats(out, hair)
            out.save(OUT / f"warga_{name}_{kind}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    villagers()
    aset_dekor.main()
    aset_alam.main()


if __name__ == "__main__":
    main()
