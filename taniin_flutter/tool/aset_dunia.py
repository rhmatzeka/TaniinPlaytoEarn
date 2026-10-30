"""Generates the extra world sprites in assets/images/dunia/ and dekor/.

Villagers are palette swaps of the farmer sheets (assets/images/walk.png and
idle.png, 32 px frames); wildlife is drawn pixel by pixel at the map's 16 px
art scale, and the village props come from tool/aset_dekor.py. Run from
taniin_flutter/:

    python3 tool/aset_dunia.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

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


# --- Pixel maps -------------------------------------------------------------


def paint(rows, palette):
    height = len(rows)
    width = max(len(r) for r in rows)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = image.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                px[x, y] = palette[ch]
    return image


def strip(frames):
    width = sum(f.width for f in frames)
    height = max(f.height for f in frames)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    for f in frames:
        out.alpha_composite(f, (x, 0))
        x += f.width
    return out


def stack(rows_of_frames):
    rows = [strip(r) for r in rows_of_frames]
    out = Image.new("RGBA", (max(r.width for r in rows), sum(r.height for r in rows)))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    return out


OUTLINE = hexc("#2a1606")


def butterflies():
    open_ = [
        "........",
        ".OO..OO.",
        "OWWOOWWO",
        "OWLBBLWO",
        ".OWBBWO.",
        ".OWBBWO.",
        "..O..O..",
        "........",
    ]
    closed = [
        "........",
        "..O..O..",
        "..OWWO..",
        "..OLLO..",
        "..OBBO..",
        "...BB...",
        "........",
        "........",
    ]
    colors = [("#fff7e6", "#f2c94c"), ("#ffd23f", "#f08a24"), ("#ff8fb1", "#ffffff"), ("#7cc7ff", "#2f6fd6")]
    rows = []
    for wing, light in colors:
        pal = {"O": OUTLINE, "W": hexc(wing), "L": hexc(light), "B": hexc("#3b2416")}
        rows.append([paint(open_, pal), paint(closed, pal)])
    stack(rows).save(OUT / "kupu.png")


def birds():
    up = [
        "OO........OO",
        ".OO......OO.",
        "..OObbbbOO..",
        "...ObbbbbOy.",
        "....OOOOO...",
        "............",
        "............",
    ]
    down = [
        "............",
        "............",
        "...ObbbbO...",
        "..OObbbbbOy.",
        ".OO.OOOOO.OO",
        "OO.......OO.",
        "............",
    ]
    pal = {"O": hexc("#2a1a10"), "b": hexc("#8a5a34"), "y": hexc("#f0b030")}
    strip([paint(up, pal), paint(down, pal)]).save(OUT / "burung.png")


def ducks():
    base = [
        "...OOO........",
        "..OGGGO.......",
        ".YYGkGO.......",
        "..OGGGO..OO...",
        "...OWWOOOWWO..",
        "..OWWWWWWWWWO.",
        "..OWWWwwWWWWWO",
        "...OWWWWWWWWO.",
        "....OOOOOOOO..",
    ]
    ripple_a = "..r.r..r.r..r."
    ripple_b = ".r..r.r..r.r.."
    pal = {
        "O": hexc("#2a1a10"),
        "G": hexc("#2f8a4a"),
        "Y": hexc("#f0a020"),
        "k": hexc("#101010"),
        "W": hexc("#f4f1e6"),
        "w": hexc("#c9c2ae"),
        "r": hexc("#d8f2ff"),
    }
    f0 = paint(["." * 14] + base + [ripple_a], pal)
    f1 = paint(base + [ripple_b, "." * 14], pal)
    strip([f0, f1]).save(OUT / "bebek.png")


def fish():
    rows = [
        "..OOO.O.",
        ".OoooOoO",
        "OkoooooO",
        ".OoooOoO",
        "..OOO.O.",
    ]
    pal = {"O": hexc("#5a2a10"), "o": hexc("#f08a3a"), "k": hexc("#101010")}
    paint(rows, pal).save(OUT / "ikan.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    villagers()
    butterflies()
    birds()
    ducks()
    fish()
    aset_dekor.main()


if __name__ == "__main__":
    main()
