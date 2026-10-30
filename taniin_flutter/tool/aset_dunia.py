"""Generates the extra world sprites in assets/images/dunia/.

Villagers are palette swaps of the farmer sheets (assets/images/walk.png and
idle.png, 32 px frames); wildlife and decorations are drawn pixel by pixel at
the map's 16 px art scale. Run from taniin_flutter/:

    python3 tool/aset_dunia.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

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


# --- Decorations (drawn at native 16 px art scale) ---------------------------


def hay():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 4, 14, 15], radius=3, fill=hexc("#c9962f"), outline=hexc("#4a2c0e"))
    d.rounded_rectangle([2, 5, 13, 9], radius=2, fill=hexc("#e8c25a"))
    for x in (4, 7, 10):
        d.line([x, 6, x + 1, 13], fill=hexc("#a87422"))
    d.line([2, 11, 13, 11], fill=hexc("#8a5a1c"))
    d.point([(5, 5), (9, 6), (12, 7)], fill=hexc("#f6dd8a"))
    im.save(OUT / "jerami.png")


def crate():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 3, 14, 15], fill=hexc("#b07a3f"), outline=hexc("#3e2410"))
    d.rectangle([2, 4, 13, 5], fill=hexc("#cf9a5a"))
    d.line([2, 9, 13, 9], fill=hexc("#7a4c22"))
    d.line([3, 6, 12, 14], fill=hexc("#7a4c22"))
    d.line([3, 7, 12, 15], fill=hexc("#8a5a2b"))
    # A few vegetables poking out of the top.
    d.point([(4, 2), (5, 2), (5, 3)], fill=hexc("#e05a2a"))
    d.point([(9, 2), (10, 1), (10, 2), (11, 2)], fill=hexc("#5aa83c"))
    im.save(OUT / "peti.png")


def barrel():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 2, 13, 15], radius=3, fill=hexc("#9a6233"), outline=hexc("#3e2410"))
    d.ellipse([3, 2, 12, 5], fill=hexc("#6b4020"), outline=hexc("#3e2410"))
    for y in (6, 12):
        d.line([2, y, 13, y], fill=hexc("#5a5a6a"))
    d.line([5, 6, 5, 14], fill=hexc("#b8784a"))
    im.save(OUT / "tong.png")


def well():
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    stone, stone_dark, line = hexc("#9aa0a8"), hexc("#6a7078"), hexc("#2e2a28")
    wood, wood_dark = hexc("#9a6233"), hexc("#5a3418")
    # Posts and roof.
    d.rectangle([5, 6, 7, 22], fill=wood, outline=wood_dark)
    d.rectangle([24, 6, 26, 22], fill=wood, outline=wood_dark)
    d.polygon([(2, 9), (16, 1), (29, 9)], fill=hexc("#b8442a"), outline=line)
    d.line([4, 8, 16, 2], fill=hexc("#d8643a"))
    d.line([8, 10, 23, 10], fill=wood_dark)
    d.line([16, 10, 16, 17], fill=hexc("#cfc4a8"))
    d.rectangle([14, 16, 18, 19], fill=hexc("#7a4c22"), outline=wood_dark)
    # Stone ring.
    d.ellipse([3, 17, 28, 25], fill=hexc("#1e3a52"), outline=line)
    d.rectangle([3, 21, 28, 30], fill=stone, outline=line)
    d.ellipse([3, 26, 28, 31], fill=stone, outline=line)
    d.ellipse([5, 18, 26, 24], fill=hexc("#2a5a7a"))
    for x in range(5, 27, 5):
        d.line([x, 22, x, 27], fill=stone_dark)
    d.line([4, 25, 27, 25], fill=stone_dark)
    im.save(OUT / "sumur.png")


def scarecrow():
    im = Image.new("RGBA", (16, 32))
    d = ImageDraw.Draw(im)
    wood, wood_dark = hexc("#9a6233"), hexc("#4a2c12")
    d.rectangle([7, 8, 8, 31], fill=wood, outline=wood_dark)
    d.rectangle([1, 14, 14, 15], fill=wood, outline=wood_dark)
    # Shirt with straw hands.
    d.rectangle([4, 13, 11, 22], fill=hexc("#c24a3a"), outline=hexc("#5a1a12"))
    d.line([4, 17, 11, 17], fill=hexc("#e0b040"))
    d.point([(0, 14), (0, 15), (15, 14), (15, 15)], fill=hexc("#e8c25a"))
    d.point([(5, 22), (7, 23), (10, 22)], fill=hexc("#e8c25a"))
    # Sack head and straw hat.
    d.ellipse([4, 6, 11, 13], fill=hexc("#e6d2a2"), outline=hexc("#5a3a12"))
    d.point([(6, 9), (9, 9)], fill=hexc("#2a1a10"))
    d.line([6, 11, 9, 11], fill=hexc("#7a5a2a"))
    d.rectangle([2, 5, 13, 6], fill=hexc("#e8c25a"), outline=hexc("#5a3a12"))
    d.polygon([(5, 5), (8, 0), (10, 5)], fill=hexc("#f6dd8a"), outline=hexc("#5a3a12"))
    im.save(OUT / "orangan.png")


def stall():
    im = Image.new("RGBA", (48, 40))
    d = ImageDraw.Draw(im)
    wood, wood_dark, line = hexc("#9a6233"), hexc("#5a3418"), hexc("#2a1606")
    # Posts.
    d.rectangle([3, 10, 5, 38], fill=wood, outline=wood_dark)
    d.rectangle([42, 10, 44, 38], fill=wood, outline=wood_dark)
    # Striped awning.
    d.rectangle([0, 4, 47, 13], fill=hexc("#f4efe2"), outline=line)
    for x in range(1, 47, 8):
        d.rectangle([x, 5, x + 3, 12], fill=hexc("#d23c32"))
    for x in range(0, 48, 4):
        d.pieslice([x, 10, x + 4, 16], 0, 180, fill=hexc("#d23c32") if (x // 4) % 2 == 0 else hexc("#f4efe2"), outline=line)
    d.polygon([(0, 4), (24, 0), (47, 4)], fill=hexc("#b8302a"), outline=line)
    # Counter with produce baskets.
    d.rectangle([2, 26, 45, 38], fill=wood, outline=line)
    d.rectangle([3, 27, 44, 28], fill=hexc("#c0844a"))
    d.line([3, 33, 44, 33], fill=wood_dark)
    produce = [("#e05a2a", "#5aa83c"), ("#c8a060", "#6a4a2a"), ("#d8364a", "#3e8a34"), ("#f0d050", "#5aa83c")]
    for i, (fruit, leaf) in enumerate(produce):
        x = 6 + i * 10
        d.rectangle([x, 22, x + 7, 26], fill=hexc("#8a5a2b"), outline=line)
        for j in range(3):
            d.ellipse([x + j * 2, 19, x + j * 2 + 3, 22], fill=hexc(fruit), outline=line)
        d.point([(x + 2, 18), (x + 5, 18)], fill=hexc(leaf))
    # Price sign.
    d.rectangle([18, 30, 29, 36], fill=hexc("#f4efe2"), outline=line)
    d.line([20, 33, 27, 33], fill=hexc("#5a3418"))
    im.save(OUT / "kios.png")


def flowerbed():
    im = Image.new("RGBA", (32, 16))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 5, 31, 15], radius=3, fill=hexc("#7a4a26"), outline=hexc("#3e2410"))
    d.rounded_rectangle([1, 6, 30, 8], radius=2, fill=hexc("#94603a"))
    colors = ["#ff6b8a", "#ffd23f", "#ffffff", "#b07cff", "#ff8f3f", "#ff6b8a", "#ffd23f"]
    for i, color in enumerate(colors):
        x = 3 + i * 4
        y = 4 + (i % 2) * 2
        d.line([x + 1, y + 2, x + 1, y + 6], fill=hexc("#3e8a34"))
        d.point([(x, y + 4), (x + 2, y + 5)], fill=hexc("#5aa83c"))
        d.rectangle([x, y, x + 2, y + 2], fill=hexc(color))
        d.point([(x + 1, y + 1)], fill=hexc("#f0b030") if color != "#ffd23f" else hexc("#c06a20"))
    im.save(OUT / "bunga.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    villagers()
    butterflies()
    birds()
    ducks()
    fish()
    hay()
    crate()
    barrel()
    well()
    scarecrow()
    stall()
    flowerbed()


if __name__ == "__main__":
    main()
