"""Wildlife, water plants and the map's rocks, stumps and bushes.

Same recipe as tool/aset_dekor.py: shaded volumes lit from the top left,
outlines tinted from each material, small story details, and four-frame
strips for anything that moves. Writes to assets/images/satwa/ (animals)
and assets/images/alam/ (plants, rocks, stumps). Run from taniin_flutter/:

    python3 tool/aset_alam.py
"""

import math

from aset_dekor import (
    BARK,
    CLOTH_CREAM,
    FRAMES,
    INK,
    LEAF,
    ROOT,
    STONE,
    STRAW,
    TOMATO,
    WATER,
    blob,
    canvas,
    dot,
    grid,
    fruit,
    ground,
    hexc,
    line,
    mix,
    noise,
    outline,
    ramp,
    strip,
    sway,
    tone,
)

SATWA = ROOT / "assets" / "images" / "satwa"
ALAM = ROOT / "assets" / "images" / "alam"

FOAM = (232, 248, 255, 255)
RIPPLE = (190, 232, 250, 200)

GREY = ramp("#3a3a48", "#6a6a78", "#a4a2ae", "#d8d6de", "#f6f4f8")
MALLARD = ramp("#0a2a1e", "#145a34", "#22874a", "#4cb86a", "#9ae0a0")
CHESTNUT = ramp("#3a1a14", "#6a3020", "#94482c", "#b8683e", "#d89060")
HEN_BROWN = ramp("#3a2214", "#62402a", "#8e6640", "#b88e5e", "#dcb888")
BILL = ramp("#8a4a08", "#d08a14", "#f2b62a", "#ffe06a")
DUCKLING = ramp("#8a6a14", "#c8a020", "#f0cc3a", "#ffe874", "#fff8c0")
KOI = ramp("#6a1e08", "#b8400e", "#ee7a1e", "#ffaa4a", "#ffe0b0")
SPARROW = ramp("#2e1c14", "#5a3a26", "#8a5e3a", "#b88a5a", "#e2c49a")
MOSS = ramp("#1e3a1a", "#2e5a22", "#4a7e2a", "#78a63a", "#a8cc5a")
CATTAIL = ramp("#2a140c", "#4a2616", "#6e3a1e", "#94562c")
LILY = ramp("#0b3a2a", "#145c34", "#2a8a3e", "#58b24a", "#9ad66a")
LOTUS = ramp("#a83a6a", "#e06a9a", "#f6a2c4", "#ffd8e8", "#ffffff")
FROG = ramp("#14361a", "#24602a", "#3e8e34", "#72bc48", "#b4e07a")
MUSH = ramp("#5a0c10", "#a81e1e", "#e04436", "#ff8a72")
BERRY = ramp("#3a0a24", "#7a1640", "#c02a5a", "#f26a8a")


# --- Animals ------------------------------------------------------------------


def duck(head, body, breast, wing, female=False):
    """A dabbling duck on the water, facing left, four bobbing frames."""
    frames = []
    for f in range(FRAMES):
        im = canvas(20, 15)
        bob = (0, 0, 1, 1)[f]
        oy = 1 + bob
        clip = lambda x, y, oy=oy: y <= 10 + oy
        blob(im, 11, 8.2 + oy, 7.0, 3.4, body, seed=1, clip=clip)
        blob(im, 6.6, 8.4 + oy, 2.7, 2.5, breast, seed=2, clip=clip)
        blob(im, 12.2, 7.2 + oy, 4.6, 2.2, wing, seed=3, clip=clip)
        # Tail with the drake's curl.
        for x, y, c in ((17, 6, body[1]), (18, 5, body[1]), (17, 7, body[2]), (18, 6, INK if not female else body[1])):
            dot(im, x, y + oy, c)
        if not female:
            dot(im, 18, 4 + oy, INK)
        # Blue wing patch.
        for x in (13, 14):
            dot(im, x, 8 + oy, hexc("#3a5ad8"))
            dot(im, x, 9 + oy, hexc("#2a3a9a"))
        dot(im, 12, 8 + oy, CLOTH_CREAM[4])
        # Neck and head.
        blob(im, 5.2, 6.4 + oy, 1.5, 2.0, head, seed=4)
        blob(im, 4.6, 3.6 + oy, 2.7, 2.4, head, seed=5)
        if not female:
            line(im, [(4, 6 + oy), (6, 6 + oy)], CLOTH_CREAM[4])
        else:
            line(im, [(3, 3 + oy), (6, 3 + oy)], HEN_BROWN[0])
        dot(im, 4, 3 + oy, INK)
        dot(im, 5, 2 + oy, head[4])
        # Bill.
        for x, y, c in ((1, 4, BILL[2]), (2, 4, BILL[3]), (0, 5, BILL[1]), (1, 5, BILL[1]), (2, 5, BILL[2])):
            dot(im, x, y + oy, c)
        outline(im)
        # Ripples where the body meets the water, drifting back.
        px = im.load()
        for x in range(1, 20):
            y = 11 + oy
            if (x + f) % 5 in (0, 1, 2):
                if px[x, y][3] == 0:
                    px[x, y] = RIPPLE
        for x in (0, 1, 18, 19):
            if (x + f) % 2:
                dot(im, x, 12 + oy - (1 if f % 2 else 0), FOAM)
        frames.append(im)
    return strip(frames)


def ducks():
    male = duck(MALLARD, GREY, CHESTNUT, ramp("#3a3430", "#6a5e54", "#968a7e", "#c2b6aa", "#e2d8cc"))
    female = duck(HEN_BROWN, HEN_BROWN, HEN_BROWN, ramp("#2e1c10", "#583a22", "#7e5a36", "#a4804e", "#c8a674"), female=True)
    sheet = canvas(male.width, male.height * 2)
    sheet.alpha_composite(male, (0, 0))
    sheet.alpha_composite(female, (0, male.height))
    sheet.save(SATWA / "bebek_renang.png")
    # Ducklings: round fluffy chicks paddling after their mother.
    frames = []
    for f in range(FRAMES):
        im = canvas(11, 9)
        oy = (0, 0, 1, 1)[(f + 1) % 4]
        blob(im, 6.2, 5.6 + oy, 3.8, 2.4, DUCKLING, seed=6, clip=lambda x, y, oy=oy: y <= 6 + oy)
        blob(im, 3.4, 3.0 + oy, 2.1, 2.0, DUCKLING, seed=7)
        dot(im, 3, 2 + oy, INK)
        dot(im, 1, 3 + oy, BILL[2])
        dot(im, 0, 3 + oy, BILL[1])
        dot(im, 9, 4 + oy, DUCKLING[1])
        outline(im)
        for x in range(1, 11):
            if (x + f) % 4 in (0, 1) and im.load()[x, 7 + oy][3] == 0:
                dot(im, x, 7 + oy, RIPPLE)
        frames.append(im)
    strip(frames).save(SATWA / "anak_bebek.png")


def fish():
    # A golden carp leaping, two tail frames.
    frames = []
    for f in range(2):
        im = canvas(13, 8)
        blob(im, 6, 4, 4.4, 2.3, KOI, seed=8)
        tail = [(10, 2), (11, 1), (10, 6), (11, 7)] if f == 0 else [(10, 3), (11, 2), (11, 3), (10, 5), (11, 5), (11, 6)]
        for x, y in tail:
            dot(im, x, y, KOI[2])
        dot(im, 11, 4, KOI[1])
        dot(im, 10, 4, KOI[2])
        dot(im, 5, 1, KOI[3])
        dot(im, 6, 1, KOI[2])
        line(im, [(4, 5), (7, 5)], KOI[4])
        dot(im, 3, 3, INK)
        dot(im, 6, 3, CLOTH_CREAM[4])
        outline(im)
        frames.append(im)
    strip(frames).save(SATWA / "ikan_lompat.png")
    # Shadow of a fish gliding under the surface.
    frames = []
    for f in range(2):
        im = canvas(12, 6)
        shade = (10, 40, 60, 110)
        for x in range(1, 9):
            half = 2.0 - abs(x - 4) * 0.4
            for y in range(round(3 - half), round(3 + half) + 1):
                dot(im, x, y, shade)
        for x, y in ((9, 2 - f), (10, 1 - f + 1), (9, 4 + f), (10, 5)):
            dot(im, x, y, shade)
        frames.append(im)
    strip(frames).save(SATWA / "ikan_bayang.png")


BUTTERFLY_COLORS = [
    ramp("#8a5a10", "#e8a020", "#ffd04a", "#fff2a8"),
    ramp("#7a2a5a", "#d0508a", "#ff8ab8", "#ffd8ea"),
    ramp("#1e3a8a", "#3a6ad8", "#6aa8ff", "#c8e4ff"),
    ramp("#6a6a6a", "#c8c4bc", "#f2efe8", "#ffffff"),
]


BUTTERFLY_FRAMES = [
    [
        "....K.K....",
        ".KKK.b.KKK.",
        "KLLMKbKMLLK",
        "KLMMKbKMMLK",
        "KMMDKbKDMMK",
        ".KKKKbKKKK.",
        "..KMDbDMK..",
        "..KMMbMMK..",
        "...KK.KK...",
    ],
    [
        "....K.K....",
        "..KK.b.KK..",
        ".KLMKbKMLK.",
        ".KMMKbKMMK.",
        ".KMDKbKDMK.",
        "..KKKbKKK..",
        "...KDbDK...",
        "...KMbMK...",
        "....K.K....",
    ],
    [
        "....K.K....",
        "...KKbKK...",
        "...KLbLK...",
        "...KMbMK...",
        "...KMbMK...",
        "...KDbDK...",
        "....KbK....",
        ".....b.....",
        "...........",
    ],
]


def butterflies():
    rows = []
    for colors in BUTTERFLY_COLORS:
        pal = {"K": mix(colors[0], INK, 0.5), "D": colors[1], "M": colors[2], "L": colors[3], "b": hexc("#2a1810")}
        frames = []
        for f in (0, 1, 2, 1):
            im = canvas(11, 9)
            grid(im, BUTTERFLY_FRAMES[f], pal)
            frames.append(im)
        rows.append(strip(frames))
    sheet = canvas(rows[0].width, rows[0].height * len(rows))
    for i, row in enumerate(rows):
        sheet.alpha_composite(row, (0, i * row.height))
    sheet.save(SATWA / "kupu_kupu.png")


def birds():
    # A sparrow flying left: wings up, level, down, level.
    frames = []
    for f in range(FRAMES):
        im = canvas(15, 11)
        blob(im, 7.5, 6, 4.2, 2.0, SPARROW, seed=14)
        blob(im, 3.6, 5.2, 1.9, 1.7, SPARROW, seed=15)
        line(im, [(5, 7), (9, 7)], SPARROW[4])
        dot(im, 3, 4, INK)
        dot(im, 1, 5, BILL[1])
        for x, y in ((11, 5), (12, 5), (13, 4), (12, 6)):
            dot(im, x, y, SPARROW[1])
        wing = (-3, -1, 2, -1)[f]
        for i in range(5):
            x = 6 + i
            y0 = 5
            y1 = 5 + round(wing * (1 - i * 0.12))
            for y in range(min(y0, y1), max(y0, y1) + 1):
                dot(im, x, y, SPARROW[2] if y != y1 else SPARROW[1])
        dot(im, 8, 5 + wing, SPARROW[3])
        outline(im)
        frames.append(im)
    strip(frames).save(SATWA / "burung_terbang.png")


FROG_FRAMES = [
    [".kk...kk.", "kWPkkkPWk", "kGGGGGGGk", "kGLGGGLGk", "kgGyyyGgk", "kggyyyggk", ".kgkkkgk."],
    [".kk...kk.", "kGGkkkGGk", "kGGGGGGGk", "kGLGGGLGk", "kgGyyyGgk", "kggyyyggk", ".kgkkkgk."],
    [".kk...kk.", "kWPkkkPWk", "kGGGGGGGk", "kGLGGGLGk", "kgGyyyGgk", "kggyyyggk", ".kgkkkgk."],
    [".kk...kk.", "kWPkkkPWk", "kGGGGGGGk", "kGLyyyLGk", "kgyWWWygk", "kgyWWWygk", ".kgyyygk."],
]


def frog():
    # A frog on a lily pad: sits, blinks, puffs its throat.
    pal = {
        "k": hexc("#123018"), "W": hexc("#ffffff"), "P": INK, "G": hexc("#8ad04a"),
        "L": hexc("#c4ec7a"), "g": hexc("#4e9a34"), "y": hexc("#eef2a8"),
    }
    frames = []
    for f in range(FRAMES):
        im = canvas(16, 12)
        lily_pad(im, 8, 8.6, 7.2, 2.8, seed=20, notch=0.3)
        outline(im)
        grid(im, FROG_FRAMES[f], pal, 4, 2)
        frames.append(im)
    strip(frames).save(SATWA / "katak.png")


def dragonfly():
    frames = []
    for f in range(2):
        im = canvas(13, 7)
        line(im, [(2, 3), (11, 3)], hexc("#2a6ad0"))
        dot(im, 1, 3, hexc("#1a3a7a"))
        dot(im, 2, 2, hexc("#58c0f0"))
        wing = (200, 236, 255, 170)
        for x in range(3, 7):
            dot(im, x, 1 + f, wing)
            dot(im, x, 5 - f, wing)
        dot(im, 4, 2, wing)
        dot(im, 4, 4, wing)
        frames.append(im)
    strip(frames).save(SATWA / "capung.png")


# --- Water plants ---------------------------------------------------------------


def lily_pad(im, cx, cy, rx, ry, seed, notch=0.0):
    """A floating pad with a notch cut toward the viewer and radial veins."""
    def keep(x, y):
        ang = math.atan2((y + 0.5 - cy) / ry, (x + 0.5 - cx) / rx)
        return not (abs(ang - math.pi / 2 - notch) < 0.32)

    blob(im, cx, cy, rx, ry, LILY, seed=seed, clip=keep)
    px = im.load()
    for k in range(5):
        a = k / 5 * math.tau + 0.4
        for r in (0.35, 0.6):
            x = round(cx + math.cos(a) * rx * r)
            y = round(cy + math.sin(a) * ry * r)
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3]:
                px[x, y] = LILY[1]


def lilies():
    im = canvas(20, 12)
    lily_pad(im, 7, 7, 6.2, 3.2, seed=1)
    lily_pad(im, 15, 8.5, 4.2, 2.3, seed=2, notch=0.8)
    # Lotus flower: layered petals.
    blob(im, 7, 5.5, 2.8, 1.8, LOTUS, seed=3)
    for x, y in ((5, 3), (7, 2), (9, 3), (6, 4), (8, 4)):
        dot(im, x, y, LOTUS[3])
    dot(im, 7, 3, LOTUS[4])
    dot(im, 7, 5, hexc("#ffd23f"))
    outline(im)
    im.save(ALAM / "teratai_1.png")

    im = canvas(16, 10)
    lily_pad(im, 8, 6, 6.6, 3.2, seed=4, notch=-0.4)
    blob(im, 9, 3.8, 1.3, 2.0, LOTUS, seed=5)
    dot(im, 9, 1, LOTUS[2])
    line(im, [(9, 5), (9, 6)], LILY[2])
    outline(im)
    im.save(ALAM / "teratai_2.png")

    im = canvas(20, 10)
    lily_pad(im, 5, 6, 3.8, 2.0, seed=6)
    lily_pad(im, 12, 5, 4.6, 2.4, seed=7, notch=0.6)
    lily_pad(im, 16.5, 7.5, 2.6, 1.4, seed=8, notch=-0.5)
    outline(im)
    im.save(ALAM / "teratai_3.png")


def reeds(name, cattails, seed):
    """A clump of reeds at the bank; cattail heads nod in the wind."""
    frames = []
    for f in range(FRAMES):
        im = canvas(16, 24)
        px = im.load()
        stems = [(3, 9), (5, 4), (7, 2), (9, 6), (11, 3), (13, 10)]
        for i, (x, top) in enumerate(stems):
            dx = sway(f, i * 0.17)
            for y in range(top, 21):
                bend = dx if y < top + (21 - top) * 0.45 else 0
                c = LEAF[3] if (i + y) % 4 else LEAF[2]
                if i % 2:
                    c = LEAF[2] if y % 3 else LEAF[1]
                dot(im, x + bend, y, c)
            dot(im, x + dx, top, LEAF[4])
            if cattails and i in (1, 3, 4):
                for y in range(top + 2, top + 6):
                    dot(im, x + dx, y, CATTAIL[2])
                    dot(im, x + dx + 1, y, CATTAIL[1])
                dot(im, x + dx, top + 2, CATTAIL[3])
        # Leaf blades fanning out at the base.
        for x0, x1, y0 in ((2, -1, 15), (12, 15, 16), (4, 1, 18), (11, 14, 19)):
            line(im, [(x0, 21), (x1, y0)], LEAF[3])
        outline(im)
        # Rings in the water at the foot of the clump.
        for x in range(2, 14):
            if (x + f + seed) % 4 in (0, 1):
                if px[x, 22][3] == 0:
                    px[x, 22] = RIPPLE
        frames.append(im)
    strip(frames).save(ALAM / f"{name}.png")


def water_rock():
    frames = []
    for f in range(FRAMES):
        im = canvas(20, 14)
        blob(im, 9, 8, 6.4, 4.6, STONE[:5], seed=30, clip=lambda x, y: y <= 10)
        blob(im, 13, 9, 3.2, 2.6, STONE[:5], seed=31, clip=lambda x, y: y <= 10)
        for x, y in ((6, 4), (7, 4), (8, 3), (5, 5)):
            dot(im, x, y, MOSS[3])
        dot(im, 9, 3, MOSS[2])
        outline(im)
        px = im.load()
        # Foam hugging the rock, breathing in and out.
        for x in range(0, 20):
            for y, gap in ((11, 0), (12, 1)):
                if (x + f + gap) % 3 and px[x, y][3] == 0:
                    px[x, y] = FOAM if y == 11 else RIPPLE
        frames.append(im)
    strip(frames).save(ALAM / "batu_air.png")


def drift_leaf():
    im = canvas(7, 5)
    blob(im, 3.5, 2.5, 3.0, 1.6, ramp("#6a3a10", "#b8701e", "#e8a63a", "#ffd27a"), seed=40)
    line(im, [(1, 3), (5, 2)], hexc("#7a4a14"))
    outline(im)
    im.save(ALAM / "daun_hanyut.png")


# --- Rocks, stumps, bushes --------------------------------------------------------


def tuft(im, x, y, flip=False):
    s = -1 if flip else 1
    dot(im, x, y, LEAF[3])
    dot(im, x + s, y - 1, LEAF[4])
    dot(im, x - s, y - 1, LEAF[3])
    dot(im, x, y - 2, LEAF[4])


def rocks():
    shapes = [
        ("batu_kecil_1", 14, 12, [(7, 8, 5.2, 3.6, 0)], [(4, 5), (5, 5), (6, 4)]),
        ("batu_kecil_2", 14, 12, [(6, 8.5, 4.2, 3.0, 1), (10, 9, 2.6, 2.0, 2)], [(4, 6)]),
        ("batu_kecil_3", 14, 12, [(7, 8.5, 5.6, 2.8, 3)], []),
        ("batu_besar_1", 20, 16, [(10, 10, 8.2, 5.6, 4), (14, 12, 4, 2.6, 5)], [(5, 6), (6, 5), (7, 5), (8, 4), (9, 4), (6, 6)]),
        ("batu_besar_2", 20, 16, [(8, 10.5, 6.4, 4.8, 6), (14.5, 11.5, 4.6, 3.4, 7)], [(14, 8), (15, 8), (13, 9)]),
        ("batu_besar_3", 20, 16, [(10, 10, 7.6, 5.4, 8)], [(6, 6), (7, 5), (8, 5), (12, 5), (13, 6)]),
    ]
    for name, w, h, parts, moss in shapes:
        im = canvas(w, h)
        for cx, cy, rx, ry, seed in parts:
            blob(im, cx, cy, rx, ry, STONE[:5], seed=seed, rough=0.25, clip=lambda x, y, h=h: y <= h - 3)
            # A crack.
            dot(im, round(cx + 1), round(cy), STONE[1])
            dot(im, round(cx + 2), round(cy + 1), STONE[1])
        for x, y in moss:
            dot(im, x, y, MOSS[3] if (x + y) % 2 else MOSS[4])
            dot(im, x, y + 1, MOSS[2])
        outline(im)
        tuft(im, 1, h - 3)
        tuft(im, w - 2, h - 3, flip=True)
        ground(im, (1, h - 5, w - 1, h)).save(ALAM / f"{name}.png")


def stump(name, w, h, seed, extra):
    im = canvas(w, h)
    cx = w / 2
    top_y = h * 0.42
    rx = w * 0.36
    # Trunk with bark ridges, flaring roots.
    for y in range(round(top_y), h - 3):
        flare = max(0, (y - (h - 7)) * 0.8)
        for x in range(round(cx - rx - flare), round(cx + rx + flare) + 1):
            u = (x - (cx - rx - flare)) / (2 * (rx + flare))
            v = 0.85 - u * 0.8
            if round(x * 1.7 + noise(x, 0, seed) * 2) % 3 == 0:
                v -= 0.25
            dot(im, x, y, tone(BARK, v))
    # Cut face: rings.
    for y in range(round(top_y - rx * 0.45), round(top_y + rx * 0.45) + 1):
        for x in range(round(cx - rx), round(cx + rx) + 1):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - top_y) / (rx * 0.45))
            if d > 1:
                continue
            ring = int(d * 4) % 2
            c = hexc("#e8c08a") if ring == 0 else hexc("#c8945a")
            if d > 0.86:
                c = BARK[3]
            dot(im, x, y, c)
    dot(im, round(cx), round(top_y), hexc("#a06a3a"))
    # Moss over one side of the bark.
    for i in range(10):
        x = round(cx - rx + noise(i, 1, seed) * rx * 0.9)
        y = round(top_y + 2 + noise(i, 2, seed) * (h - top_y - 6))
        dot(im, x, y, MOSS[3] if i % 2 else MOSS[2])
        dot(im, x + 1, y, MOSS[4])
    extra(im, cx, top_y, rx)
    outline(im)
    tuft(im, 1, h - 3)
    tuft(im, w - 2, h - 2, flip=True)
    ground(im, (1, h - 5, w - 1, h)).save(ALAM / f"{name}.png")


def mushrooms(im, x, y):
    for mx, my, r in ((x, y, 1.8), (x + 3, y + 1, 1.3)):
        line(im, [(round(mx), round(my)), (round(mx), round(my) + 2)], CLOTH_CREAM[3])
        blob(im, mx + 0.5, my, r + 0.4, r * 0.8, MUSH, seed=int(mx * 7))
        dot(im, round(mx), round(my) - 1, CLOTH_CREAM[4])


def stumps():
    stump("tunggul_1", 18, 16, 50, lambda im, cx, ty, rx: mushrooms(im, cx + rx - 1, ty + 4))
    stump("tunggul_2", 18, 16, 51, lambda im, cx, ty, rx: None)

    def axe(im, cx, ty, rx):
        line(im, [(round(cx + 1), round(ty)), (round(cx + 5), round(ty - 5))], hexc("#c8945a"))
        line(im, [(round(cx + 2), round(ty)), (round(cx + 6), round(ty - 5))], hexc("#8a5a2a"))
        for x, y in ((round(cx - 1), round(ty)), (round(cx), round(ty) - 1), (round(cx), round(ty)), (round(cx) - 1, round(ty) - 1)):
            dot(im, x, y, hexc("#9aa0b0"))
        dot(im, round(cx) - 1, round(ty) - 1, hexc("#e0e4f0"))

    stump("tunggul_3", 18, 18, 52, axe)
    stump("tunggul_besar", 32, 22, 53, lambda im, cx, ty, rx: mushrooms(im, cx - rx + 2, ty + 6))


def bush(name, seed, flowers=None, berries=False, fern=False):
    im = canvas(20, 16)
    if fern:
        angles = (-2.75, -2.35, -1.95, -1.57, -1.2, -0.8, -0.4)
        for i, a in enumerate(angles):
            length = 9 - abs(i - 3)
            for k in range(length):
                x = round(10 + math.cos(a) * k * 1.15)
                y = round(14 + math.sin(a) * k * 1.25 + (k * k * 0.05 if abs(a + 1.57) > 0.5 else 0))
                dot(im, x, y, LEAF[2] if k < 2 else LEAF[3])
                if 1 < k < length - 1:
                    nx, ny = -math.sin(a), math.cos(a)
                    dot(im, round(x + nx), round(y + ny), LEAF[2])
                    dot(im, round(x - nx), round(y - ny), LEAF[4])
    else:
        for i, (cx, cy, r) in enumerate(((10, 9, 6.2), (6, 10.5, 4.2), (14.5, 10.5, 4.4), (10, 6.5, 4.0))):
            blob(im, cx, cy, r, r * 0.8, LEAF[:5], rough=0.4, seed=seed + i, clip=lambda x, y: y <= 13)
    if berries:
        for i, (x, y) in enumerate(((6, 8), (11, 6), (14, 9), (9, 11), (16, 11), (4, 11))):
            fruit(im, x, y, 1.0, BERRY, seed=seed + i)
    if flowers:
        for i, (x, y) in enumerate(((6, 7), (10, 4), (14, 7), (8, 10), (15, 10))):
            dot(im, x, y, hexc(flowers[0]))
            dot(im, x + 1, y, hexc(flowers[1]))
            dot(im, x, y + 1, hexc(flowers[1]))
            dot(im, x + 1, y + 1, hexc("#ffd23f"))
    outline(im)
    ground(im, (2, 11, 18, 16)).save(ALAM / f"{name}.png")


def bushes():
    bush("semak_buah", 60, berries=True)
    bush("semak_bunga", 61, flowers=("#ffffff", "#f2e6ff"))
    bush("semak_pakis", 62, fern=True)
    bush("semak_kuning", 63, flowers=("#fff2a8", "#ffcc33"))


def main():
    SATWA.mkdir(parents=True, exist_ok=True)
    ALAM.mkdir(parents=True, exist_ok=True)
    ducks()
    fish()
    butterflies()
    birds()
    frog()
    dragonfly()
    lilies()
    reeds("alang_1", True, 0)
    reeds("alang_2", False, 2)
    water_rock()
    drift_leaf()
    rocks()
    stumps()
    bushes()


if __name__ == "__main__":
    main()
