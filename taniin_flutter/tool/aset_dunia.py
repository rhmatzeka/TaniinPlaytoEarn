"""Generates the extra world sprites in assets/images/dunia/.

Villagers are palette swaps of the farmer sheets (assets/images/walk.png and
idle.png, 32 px frames); wildlife and decorations are drawn pixel by pixel at
the map's 16 px art scale. Run from taniin_flutter/:

    python3 tool/aset_dunia.py
"""

import math
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
#
# Colours come from the tileset's own ramps: the dark plum outline, the
# red-brown wood and roof tiles of the houses, the maple tree greens. Light
# falls from the top left and every prop sits on a soft shadow.

INK = hexc("#1c0a18")
SHADOW = (28, 10, 24, 84)

WOOD = [hexc(c) for c in ("#32131e", "#4a2123", "#8a3625", "#ae4924", "#c46120", "#e0823a")]
STRAWS = [hexc(c) for c in ("#6e3a1c", "#a5642a", "#d89a3a", "#f2c35c", "#fbe7a1")]
LEAF = [hexc(c) for c in ("#0f3b33", "#0f6542", "#1a8321", "#38a129", "#6ebd3c", "#a6dc6a")]
STONE = [hexc(c) for c in ("#3c2c34", "#6a5a5e", "#9a8a82", "#c8baa4", "#e6dccb")]
IRON = [hexc(c) for c in ("#2a2438", "#4e4a62", "#8a86a0", "#c4c2d4")]
RED = [hexc(c) for c in ("#5a0f12", "#8f2418", "#c33321", "#e0503a", "#f48a6a")]
CREAM = [hexc(c) for c in ("#b88a72", "#d9ab91", "#f7dbc6", "#fff4ea")]
ROOF = [hexc(c) for c in ("#550b04", "#7e210d", "#c33f1a", "#d66226", "#ee8a4a")]
WATER = [hexc(c) for c in ("#0d2236", "#16405e", "#2a6f96", "#7fc8ea")]

# Shared grid keys; each prop adds its own.
BASE = {
    "k": INK,
    "1": WOOD[0], "2": WOOD[1], "3": WOOD[2], "4": WOOD[3], "5": WOOD[4], "6": WOOD[5],
    "e": STRAWS[0], "d": STRAWS[1], "m": STRAWS[2], "b": STRAWS[3], "a": STRAWS[4],
    "g": LEAF[1], "G": LEAF[2], "L": LEAF[3], "l": LEAF[4],
}

# A round fruit or flower head, outlined; A light, B mid, C dark, h shine.
ROUND = [
    ".kkk.",
    "khABk",
    "kABCk",
    "kBCCk",
    ".kkk.",
]


def canvas(width, height):
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))


def grid(image, rows, palette, ox=0, oy=0):
    px = image.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette and 0 <= ox + x < image.width and 0 <= oy + y < image.height:
                px[ox + x, oy + y] = palette[ch]


def outline(image):
    """Rings every opaque shape with the tileset's ink outline."""
    px = image.load()
    w, h = image.size
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255 and px[nx, ny] != INK:
                    edge.append((x, y))
                    break
    for xy in edge:
        px[xy] = INK
    return image


def grounded(image, box):
    """Puts [image] on an elliptical shadow."""
    out = canvas(*image.size)
    ImageDraw.Draw(out).ellipse(box, fill=SHADOW)
    out.alpha_composite(image)
    return out


HAY_BALE = [
    ".abTbaabTab.",
    "abbTbbbbTbba",
    "bbbTbbabTbbb",
    "aaaTaaaaTaaa",
    "bmbtbmbmtbmb",
    "mdmtmdmdtmdm",
    "mmmtmmmmtmmm",
    "mbmtmbmbtmbm",
    "dmdtdmdmtdmd",
    "mmmtmmmmtmmm",
    "dddtdddd tddd".replace(" ", ""),
    ".eeteeeetee.",
]


def bale(width=16, height=16, ox=2, oy=2):
    """One square bale: lit top face, straw front, two twine bands."""
    im = canvas(width, height)
    grid(im, HAY_BALE, {**BASE, "T": WOOD[2], "t": WOOD[1]}, ox, oy)
    return outline(im)


def hay():
    im = bale()
    # Loose straws poking out.
    grid(im, ["b", "m"], BASE, 0, 7)
    grid(im, ["m", ".", "d"], BASE, 15, 9)
    grid(im, ["a"], BASE, 5, 1)
    grounded(im, (1, 12, 15, 15)).save(OUT / "jerami.png")


def hay_stack():
    # Two bales, the upper one shifted so both faces show.
    im = bale(20, 26, 1, 11)
    top = bale(20, 26, 6, 1)
    # The upper bale shades the straw it rests on.
    px, tp = im.load(), top.load()
    for x in range(20):
        if tp[x, 13] == INK and px[x, 14][3] == 255 and px[x, 14] != INK:
            px[x, 14] = STRAWS[1]
    im.alpha_composite(top)
    grid(im, ["b", "m"], BASE, 0, 17)
    grid(im, ["m", ".", "d"], BASE, 19, 6)
    grid(im, ["a", "b"], BASE, 10, 0)
    grounded(im, (1, 22, 18, 25)).save(OUT / "jerami_tumpuk.png")


def crate():
    rows = [
        "..............",
        "..............",
        "..............",
        "..............",
        "1111111111111.",
        "45555555555554",
        "45333333333354",
        "42223342222254",
        "42222443222254",
        "42222234422254",
        "42222222344254",
        "45222222223354",
        "45555555555554",
        "44444444444444",
    ]
    im = canvas(16, 16)
    grid(im, rows, BASE, 1, 1)
    # Produce heaped inside: tomatoes and a cabbage.
    tomato = {"k": INK, "h": RED[4], "A": RED[3], "B": RED[2], "C": RED[1]}
    cabbage = {"k": INK, "h": LEAF[5], "A": LEAF[4], "B": LEAF[3], "C": LEAF[2]}
    grid(im, ROUND, tomato, 2, 2)
    grid(im, ROUND, cabbage, 9, 1)
    grid(im, ROUND, tomato, 6, 2)
    grid(im, ["g.g", ".G."], BASE, 3, 1)
    grid(im, ["G"], BASE, 7, 1)
    outline(im)
    grounded(im, (1, 12, 15, 15)).save(OUT / "peti.png")


def barrel():
    im = canvas(16, 16)
    px = im.load()
    # Bulging staves, lit from the left.
    ramp = [WOOD[4], WOOD[5], WOOD[5], WOOD[4], WOOD[4], WOOD[3], WOOD[3], WOOD[3], WOOD[2], WOOD[2]]
    for y in range(4, 15):
        bulge = 1 if 6 <= y <= 11 else 0
        left, right = 3 - bulge, 12 + bulge
        for x in range(left, right + 1):
            t = (x - left) / (right - left)
            c = ramp[min(int(t * len(ramp)), len(ramp) - 1)]
            if x in (5, 8, 11) and y not in (6, 12):
                c = WOOD[1] if x != 5 else WOOD[2]
            px[x, y] = c
    # Iron hoops.
    for y in (6, 12):
        bulge = 1 if 6 <= y <= 11 else 0
        for x in range(3 - bulge, 13 + bulge):
            t = (x - 3) / 10
            px[x, y] = IRON[3] if t < 0.25 else IRON[2] if t < 0.6 else IRON[1]
    # Lid.
    d = ImageDraw.Draw(im)
    d.ellipse([3, 1, 12, 5], fill=WOOD[2])
    d.ellipse([4, 2, 11, 4], fill=WOOD[4])
    d.line([5, 3, 10, 3], fill=WOOD[3])
    px[5, 2] = WOOD[5]
    outline(im)
    grounded(im, (1, 12, 15, 15)).save(OUT / "tong.png")


def scarecrow():
    rows = [
        "....................",
        "........abbm........",
        ".......abbbbm.......",
        ".......bbbbmm.......",
        ".......RRRRRr.......",
        "....abbbbbbbbbbm....",
        "...bmmmmmmmmmmmmd...",
        "......ffffffff......",
        "......FFFFFFFf......",
        "......FFoFFoFf......",
        "......FpFFFFpf......",
        "......FFxFFxFf......",
        ".......fFxxff.......",
        "........bmmb........",
        "..QQQQQQQQQQQQQQQQ..",
        "abRRPPRRRRRRRRRRRRba",
        "bmRRPPRRRRRRRRRRRRmb",
        "..rrrrrRRRRRRrrrrr..",
        ".......RRRRRRr......",
        ".......RRoRRRr......",
        ".......RRRRRRr......",
        ".......rRoRRrr......",
        "......bmbbmbbm......",
        "......d.m34m.d......",
        ".........34.........",
        ".........34.........",
        ".........34.........",
        ".........34.........",
        ".........34.........",
        ".........23.........",
        ".........23.........",
        "....................",
    ]
    pal = {
        **BASE,
        "F": hexc("#ead2a0"), "f": hexc("#c9a067"), "o": INK, "p": hexc("#f08a7a"),
        "x": WOOD[1], "R": RED[2], "r": RED[1], "Q": RED[3], "P": hexc("#3f7fbf"),
    }
    im = canvas(20, 32)
    grid(im, rows, pal)
    outline(im)
    grounded(im, (5, 28, 14, 31)).save(OUT / "orangan.png")


FLOWER = [
    ".kk.",
    "khAk",
    "kAcB",
    ".kB.",
]
TULIP = [
    "k.k",
    "hkA",
    "hAB",
    ".B.",
]


def flowerbed(name, flowers):
    im = canvas(32, 18)
    d = ImageDraw.Draw(im)
    # Leafy mound spilling over the planter.
    for i, x in enumerate(range(3, 29, 4)):
        top = 6 + (i % 2)
        d.ellipse([x - 1, top, x + 5, top + 6], fill=LEAF[2])
    for i, x in enumerate(range(3, 29, 4)):
        top = 6 + (i % 2)
        d.ellipse([x, top, x + 3, top + 3], fill=LEAF[3])
        d.point([(x + 1, top + 1)], fill=LEAF[4])
    # Planter box: lit rim, two planks, corner posts with nails.
    d.rectangle([2, 11, 29, 16], fill=WOOD[3])
    d.line([2, 11, 29, 11], fill=WOOD[5])
    d.line([2, 12, 29, 12], fill=WOOD[4])
    d.line([2, 14, 29, 14], fill=WOOD[1])
    d.line([2, 16, 29, 16], fill=WOOD[2])
    for x in (2, 27):
        d.rectangle([x, 11, x + 2, 16], fill=WOOD[4])
        d.line([x, 11, x, 16], fill=WOOD[5])
        d.point([(x + 1, 13), (x + 1, 15)], fill=WOOD[0])
    for x, y in ((8, 13), (14, 15), (19, 13), (23, 15)):
        d.point([(x, y), (x + 1, y)], fill=WOOD[2])
    px = im.load()
    # Stems and flower heads.
    for x, y, kind, colors in flowers:
        for sy in range(y + 3, 11):
            px[x + 1, sy] = LEAF[1]
        px[x + 2, y + 5] = LEAF[4]
        stamp = FLOWER if kind == "f" else TULIP
        pal = {"k": INK, "h": hexc(colors[0]), "A": hexc(colors[1]), "B": hexc(colors[2]), "c": hexc(colors[3])}
        grid(im, stamp, pal, x, y)
    outline(im)
    grounded(im, (1, 14, 30, 17)).save(OUT / f"{name}.png")


PINK = ("#ffd0dc", "#ff7b9c", "#c2406a", "#ffd23f")
YELLOW = ("#fff3b0", "#ffd23f", "#d08a1a", "#c0561a")
WHITE = ("#ffffff", "#f1ede4", "#b8b0c4", "#ffb020")
PURPLE = ("#e0c8ff", "#a77cf0", "#6a44b0", "#ffd23f")
ORANGE = ("#ffd2a0", "#ff8f3f", "#c0501a", "#ffe070")
SCARLET = ("#ffb0a0", "#ec4a3a", "#9a1f22", "#ffd23f")
BLUE = ("#d4ecff", "#6aaaf0", "#3a5ab0", "#ffffff")


def flowerbeds():
    flowerbed("bunga", [
        (3, 3, "f", PINK), (8, 1, "f", YELLOW), (12, 4, "t", SCARLET), (15, 2, "f", WHITE),
        (20, 3, "f", PURPLE), (24, 1, "f", PINK), (27, 4, "t", YELLOW),
    ])
    flowerbed("bunga_2", [
        (3, 4, "t", ORANGE), (6, 1, "f", BLUE), (11, 3, "t", SCARLET), (14, 1, "f", YELLOW),
        (19, 4, "t", PINK), (22, 2, "f", WHITE), (26, 3, "t", ORANGE),
    ])


def stall():
    w, h = 48, 46
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    px = im.load()
    # Shaded back wall under the awning.
    d.rectangle([7, 12, 40, 31], fill=WOOD[1])
    for y in (16, 21, 26):
        d.line([7, y, 40, y], fill=WOOD[0])
    d.rectangle([7, 12, 40, 14], fill=WOOD[0])
    # Strings of chillies and garlic hanging from the frame.
    for i, y in enumerate(range(14, 22)):
        px[11, y] = WOOD[0] if i == 0 else (RED[3] if i % 2 else RED[2])
        px[12 if i % 2 else 10, y] = RED[1] if i else WOOD[0]
    for i, y in enumerate(range(14, 21, 2)):
        d.rectangle([35, y, 36, y + 1], fill=CREAM[2])
        px[35, y] = CREAM[3]
        px[36, y + 1] = CREAM[0]
    # Posts.
    for x in (5, 40):
        d.rectangle([x, 10, x + 2, 42], fill=WOOD[3])
        d.line([x, 10, x, 42], fill=WOOD[4])
        d.line([x + 2, 10, x + 2, 42], fill=WOOD[2])
    # Awning: stripes fan out from the back edge to the front edge.
    back, front = (8, 39), (1, 46)
    top, bottom = 2, 10
    stripes = 12
    for y in range(top, bottom + 1):
        t = (y - top) / (bottom - top)
        left = back[0] + (front[0] - back[0]) * t
        right = back[1] + (front[1] - back[1]) * t
        for x in range(round(left), round(right) + 1):
            k = int((x - left) / (right - left + 1) * stripes)
            red = k % 2 == 0
            tone = 3 if y <= 3 else 2 if y <= 8 else 1
            px[x, y] = RED[tone] if red else CREAM[tone]
    # Ridge beam.
    d.line([8, 1, 39, 1], fill=WOOD[3])
    # Scalloped front flap.
    for x in range(1, 47):
        k = (x - 1) // 4
        red = k % 2 == 0
        light, mid, dark = (RED[3], RED[2], RED[1]) if red else (CREAM[3], CREAM[2], CREAM[1])
        px[x, 11] = INK
        px[x, 12] = light
        px[x, 13] = mid
        px[x, 14] = dark if (x - 1) % 4 in (0, 3) else mid
        if (x - 1) % 4 in (1, 2):
            px[x, 15] = dark
    # Counter: lit top, planked front.
    d.rectangle([3, 30, 44, 42], fill=WOOD[3])
    d.line([3, 30, 44, 30], fill=WOOD[5])
    d.rectangle([3, 31, 44, 32], fill=WOOD[4])
    d.line([3, 33, 44, 33], fill=WOOD[1])
    for y in (37, 41):
        d.line([4, y, 43, y], fill=WOOD[2])
    d.line([3, 42, 44, 42], fill=WOOD[1])
    for x, y in ((7, 35), (12, 39), (34, 35), (39, 39)):
        d.line([x, y, x + 2, y], fill=WOOD[4])
    # Crates of produce on the counter.
    tomato = {"k": INK, "h": RED[4], "A": RED[3], "B": RED[2], "C": RED[1]}
    corn = {"k": INK, "h": hexc("#fff3b0"), "A": hexc("#ffd23f"), "B": hexc("#e8a820"), "C": hexc("#b06a10")}
    cabbage = {"k": INK, "h": LEAF[5], "A": LEAF[4], "B": LEAF[3], "C": LEAF[2]}
    pumpkin = {"k": INK, "h": hexc("#ffc080"), "A": hexc("#f08a2a"), "B": hexc("#d0601a"), "C": hexc("#8a3a10")}
    for i, pal in enumerate((tomato, corn, cabbage, pumpkin)):
        x = 8 + i * 8
        for fx, fy in ((0, 21), (3, 21), (6, 21), (1, 19), (4, 19)):
            grid(im, ROUND, pal, x - 1 + fx, fy)
        if pal is tomato or pal is pumpkin:
            for fx in (1, 4):
                px[x + 1 + fx, 19] = LEAF[3]
        d.rectangle([x - 1, 25, x + 8, 29], fill=WOOD[4])
        d.rectangle([x - 1, 25, x + 8, 25], fill=WOOD[5])
        d.line([x - 1, 27, x + 8, 27], fill=WOOD[2])
        d.line([x - 1, 29, x + 8, 29], fill=WOOD[2])
        d.rectangle([x - 2, 24, x + 9, 29], outline=INK)
    # Price board with a carrot and a coin on it.
    d.rectangle([16, 34, 31, 40], fill=CREAM[2], outline=INK)
    d.line([17, 35, 30, 35], fill=CREAM[3])
    d.line([17, 39, 30, 39], fill=CREAM[1])
    carrot = [
        "...gG",
        "..oog",
        ".ooO.",
        "ooO..",
        "O....",
    ]
    grid(im, carrot, {**BASE, "o": hexc("#f08a2a"), "O": hexc("#c0501a")}, 18, 35)
    coin = [".yy.", "yYYy", "yYYy", ".yy."]
    grid(im, coin, {"y": hexc("#b06a10"), "Y": hexc("#ffd23f")}, 25, 35)
    outline(im)
    grounded(im, (2, 39, 45, 45)).save(OUT / "kios.png")


def well():
    w, h = 32, 36
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    px = im.load()
    cx, rx = 15.5, 12.5
    top_y, bottom_y = 23.0, 30.0
    # Stone wall: courses of staggered stones, rounder shading at the sides.
    for y in range(int(top_y), int(bottom_y) + 4):
        for x in range(3, 29):
            u = (x - cx) / rx
            if abs(u) > 1:
                continue
            curve = math.sqrt(1 - u * u) * 3.6
            if y > bottom_y + curve:
                continue
            row = int(y - top_y - curve * 0.3) // 3
            seam = (x + (row % 2) * 3) % 6 == 0
            course = (y - top_y - curve * 0.3) % 3 < 1
            if seam or course:
                c = STONE[1]
            else:
                tone = 3 if u < -0.45 else 2 if u < 0.5 else 1
                if (x * 7 + row * 13) % 5 == 0:
                    tone = max(tone - 1, 1)
                c = STONE[tone]
            px[x, y] = c
    # Capstone rim and the water inside.
    d.ellipse([3, 19, 28, 27], fill=STONE[3])
    d.ellipse([3, 20, 28, 27], fill=STONE[2])
    d.ellipse([3, 19, 28, 26], fill=STONE[3])
    d.ellipse([6, 20, 25, 25], fill=WATER[0])
    d.ellipse([7, 21, 24, 25], fill=WATER[1])
    d.line([10, 23, 13, 23], fill=WATER[2])
    d.line([17, 24, 19, 24], fill=WATER[2])
    px[11, 22] = WATER[3]
    for x in (8, 14, 20, 26):
        px[x, 20 if 8 < x < 24 else 22] = STONE[1]
    px[6, 21] = STONE[4]
    px[7, 20] = STONE[4]
    # Posts on the rim.
    for x in (4, 26):
        d.rectangle([x, 8, x + 1, 23], fill=WOOD[3])
        d.line([x, 8, x, 23], fill=WOOD[4])
    # Winch: a log drum wound with rope, a crank, and a bucket on the rope.
    d.rectangle([6, 12, 25, 13], fill=WOOD[3])
    d.line([6, 12, 25, 12], fill=WOOD[4])
    d.rectangle([11, 11, 20, 14], fill=WOOD[2], outline=INK)
    for x in range(12, 20):
        px[x, 12] = CREAM[2] if x % 2 else CREAM[1]
        px[x, 13] = CREAM[1] if x % 2 else CREAM[0]
    d.line([27, 12, 29, 12], fill=IRON[2])
    d.line([29, 12, 29, 15], fill=IRON[1])
    px[29, 15] = WOOD[4]
    d.line([15, 15, 15, 16], fill=CREAM[1])
    bucket = [
        "kkkkkkk",
        "k25554k",
        "kIIIIIk",
        ".k443k.",
        ".k432k.",
        ".kkkkk.",
    ]
    grid(im, bucket, {**BASE, "I": IRON[2]}, 12, 16)
    # Tiled roof like the village houses.
    for y in range(1, 10):
        t = (y - 1) / 8
        left = round(9 - 8 * t)
        right = round(22 + 8 * t)
        for x in range(left, right + 1):
            band = (y - 1) // 2
            seam = (x + band * 2) % 4 == 0
            if (y - 1) % 2 == 1:
                c = ROOF[1]
            elif seam:
                c = ROOF[1]
            else:
                c = ROOF[3] if x < 16 else ROOF[2]
            if y == 1 and not seam:
                c = ROOF[4]
            px[x, y] = c
    d.line([1, 9, 30, 9], fill=ROOF[0])
    d.line([9, 0, 22, 0], fill=WOOD[3])
    outline(im)
    grounded(im, (2, 29, 29, 35)).save(OUT / "sumur.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    villagers()
    butterflies()
    birds()
    ducks()
    fish()
    hay()
    hay_stack()
    crate()
    barrel()
    well()
    scarecrow()
    stall()
    flowerbeds()


if __name__ == "__main__":
    main()
