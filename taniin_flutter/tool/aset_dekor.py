"""Village props for assets/images/dekor/, drawn pixel by pixel.

Every prop is built from shaded volumes (lit from the top left) instead of
flat boxes, outlined with a darker tint of its own colour the way the
tileset's trees and houses are, and most come as a strip of four frames so
cloth, flowers, water and straw move a little in the wind. Run through
tool/aset_dunia.py, or on its own from taniin_flutter/:

    python3 tool/aset_dekor.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "dekor"
FRAMES = 4


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def ramp(*values):
    return [hexc(v) for v in values]


INK = hexc("#1c0a18")
SHADOW = (28, 10, 24, 78)

WOOD = ramp("#32131e", "#4a2123", "#6e2c22", "#8a3625", "#ae4924", "#c46120", "#e0823a")
BARK = ramp("#2a1418", "#4a2a26", "#6e4232", "#8e5a3e", "#b07a52")
STRAW = ramp("#6e3a1c", "#9a5c24", "#c88a32", "#e8b24a", "#f6d47a", "#fff0b8")
LEAF = ramp("#0b2e2a", "#0f5040", "#1a7a32", "#38a129", "#6ebd3c", "#b2e06a")
STONE = ramp("#2e2430", "#4e4450", "#76686c", "#a09088", "#c8b8a4", "#ece0cc")
IRON = ramp("#241e30", "#4e4a62", "#8a86a0", "#d0cee0")
CLOTH_RED = ramp("#4a0c14", "#7e1a1c", "#b02a24", "#d8442e", "#f07650")
CLOTH_CREAM = ramp("#8a6450", "#c09a7e", "#e6c8aa", "#fae8d4", "#fffaf2")
DENIM = ramp("#1a2244", "#2a3e74", "#3e62a8", "#6a92d0")
BURLAP = ramp("#5a3a22", "#8a6440", "#b88e5e", "#dcb884", "#f2d8a8")
ROOF = ramp("#3a0806", "#6a1a0c", "#9a2e14", "#c84a1e", "#e46e2c", "#f4a05a")
WATER = ramp("#0a1c30", "#123856", "#1e5c84", "#3a8cba", "#9adcf4", "#ffffff")
SOIL = ramp("#2a1210", "#46221a", "#64362a", "#82503a")

TOMATO = ramp("#5a0c10", "#9a1c18", "#d23626", "#f0603e", "#ffb09a")
PUMPKIN = ramp("#5a2208", "#9a4210", "#d66a1c", "#f49234", "#ffd08a")
CORN = ramp("#7a4a08", "#b87a10", "#e8b020", "#ffd848", "#fff2a8")
CABBAGE = ramp("#0f4030", "#1e7034", "#46a03a", "#82c850", "#c8ec90")
EGGPLANT = ramp("#1e0c2c", "#3e1a56", "#64308a", "#9258bc", "#d2a8f0")


# --- Helpers ------------------------------------------------------------------


def noise(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 1023) / 1023


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


LIGHT = (-0.45, -0.65, 0.62)


def tone(colors, value):
    """Picks a colour from a ramp for a light value in 0..1."""
    i = int(max(0.0, min(0.999, value)) * len(colors))
    return colors[i]


def blob(im, cx, cy, rx, ry, colors, rough=0.0, seed=0, lift=0.0, clip=None):
    """A lit ellipsoid: fruit, bushes, stones, hay, cloth puffs."""
    px = im.load()
    for y in range(math.floor(cy - ry) - 1, math.ceil(cy + ry) + 2):
        for x in range(math.floor(cx - rx) - 1, math.ceil(cx + rx) + 2):
            if not (0 <= x < im.width and 0 <= y < im.height):
                continue
            if clip and not clip(x, y):
                continue
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1 + rough * (noise(x, y, seed) - 0.5):
                continue
            nz = math.sqrt(max(0.0, 1 - min(d, 1)))
            lit = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
            px[x, y] = tone(colors, (lit - 0.05) / 0.9 + lift + (noise(x, y, seed + 7) - 0.5) * rough * 0.12)


def fruit(im, cx, cy, r, colors, seed=0, stem=None):
    """One round fruit with its own outline, so a heap reads as many."""
    size = int(r * 2) + 5
    piece = canvas(size, size)
    c = size / 2
    blob(piece, c, c, r, r * 0.92, colors, seed=seed)
    if stem:
        dot(piece, int(c), int(c - r), stem)
    outline(piece)
    im.alpha_composite(piece, (round(cx - c), round(cy - c)))


def grid(im, rows, palette, ox=0, oy=0):
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette and 0 <= ox + x < im.width and 0 <= oy + y < im.height:
                px[ox + x, oy + y] = palette[ch]


def dot(im, x, y, color):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.load()[x, y] = color


def line(im, points, color):
    ImageDraw.Draw(im).line(points, fill=color)


def outline(im):
    """Selective outline: each edge takes a deep tint of what it borders,
    a little softer on the lit top and left."""
    px = im.load()
    w, h = im.size
    edges = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy, strength in ((0, 1, 0.62), (1, 0, 0.62), (-1, 0, 0.74), (0, -1, 0.8)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 255:
                    edges[(x, y)] = mix(px[nx, ny], INK, strength)
                    break
    for xy, color in edges.items():
        px[xy] = color
    return im


def ground(im, box):
    out = Image.new("RGBA", im.size)
    ImageDraw.Draw(out).ellipse(box, fill=SHADOW)
    out.alpha_composite(im)
    return out


def strip(frames):
    out = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * f.width, 0))
    return out


def sway(frame, phase=0.0):
    """-1, 0 or 1: a gentle back-and-forth over the four frames."""
    return round(math.sin((frame / FRAMES + phase) * math.tau) * 1.1)


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# --- Hay ----------------------------------------------------------------------


def straw_strands(im, cx, cy, seed, count, inside, colors=STRAW):
    """Short strokes that give hay its grain, pointing away from (cx, cy)."""
    for i in range(count):
        x = int(noise(i, 1, seed) * im.width)
        y = int(noise(i, 2, seed) * im.height)
        if not inside(x, y):
            continue
        ang = math.atan2(y - cy, x - cx) + (noise(i, 3, seed) - 0.5) * 0.9
        length = 2 + int(noise(i, 4, seed) * 2)
        light = noise(i, 5, seed) > 0.45
        c = colors[4] if light else colors[1]
        for s in range(length):
            dot(im, round(x + math.cos(ang) * s), round(y + math.sin(ang) * s), c)


def hay_heap():
    im = canvas(20, 18)
    blob(im, 10, 11, 8.4, 8.6, STRAW, rough=0.3, seed=3, clip=lambda x, y: y <= 15)
    px = im.load()
    solid = lambda x, y: 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] == 255
    # Strands drape down from the crown.
    for i in range(40):
        x = 2 + int(noise(i, 1, 9) * 16)
        y = 4 + int(noise(i, 2, 9) * 11)
        if not solid(x, y):
            continue
        ang = math.atan2(y - 1, x - 10)
        light = noise(i, 5, 9) > 0.5
        for k in range(3):
            xx, yy = round(x + math.cos(ang) * k), round(y + math.sin(ang) * k)
            if solid(xx, yy):
                px[xx, yy] = STRAW[4] if light else STRAW[1]
    # Wisps on the crown and sides.
    for x, y, c in ((10, 1, STRAW[4]), (9, 2, STRAW[3]), (12, 2, STRAW[4]), (2, 9, STRAW[3]), (18, 10, STRAW[2])):
        dot(im, x, y, c)
    outline(im)
    for x, y, c in ((1, 16, STRAW[3]), (2, 17, STRAW[2]), (17, 16, STRAW[3]), (18, 17, STRAW[4])):
        dot(im, x, y, c)
    return ground(im, (1, 13, 19, 18))


def bale(w=15, h=13, seed=0):
    """A square bale with a lit top, flaky front and twine, slightly puffed."""
    im = canvas(w + 2, h + 2)
    px = im.load()
    top = 4
    for y in range(h):
        for x in range(w):
            # Rounded corners.
            if (x in (0, w - 1) and y in (0, h - 1)) or (x in (0, w - 1) and y == 1 and noise(x, y, seed) > 0.5):
                continue
            if y < top:
                v = 0.78 - y * 0.05 - x * 0.012
            else:
                v = 0.58 - (y - top) * 0.045 - x * 0.012
                # Flakes: soft vertical seams.
                if (x + (y // 3) % 2) % 4 == 0:
                    v -= 0.12
            v += (noise(x, y, seed) - 0.5) * 0.06
            px[x + 1, y + 1] = tone(STRAW, v)
    for i in range(5):
        x = 2 + int(noise(i, 1, seed + 1) * (w - 2))
        y = top + 2 + int(noise(i, 2, seed + 1) * (h - top - 3))
        c = STRAW[4] if noise(i, 3, seed) > 0.5 else STRAW[1]
        dot(im, x, y, c)
        dot(im, x, y + 1, c)
    # Twine around the bale.
    for tx in (4, w - 4):
        for y in range(1, h + 1):
            c = WOOD[4] if y <= top else WOOD[3]
            dot(im, tx + (1 if y <= top else 0), y, c)
        dot(im, tx + 1, 1, WOOD[5])
    # Straw tufts on the edges.
    dot(im, 0, top + 3, STRAW[3])
    dot(im, w + 1, top + 5, STRAW[2])
    dot(im, 5, 0, STRAW[4])
    return outline(im)


def hay_stack():
    im = canvas(28, 26)
    im.alpha_composite(bale(seed=1), (1, 11))
    im.alpha_composite(bale(seed=2), (11, 12))
    im.alpha_composite(bale(seed=3), (6, 1))
    for x, y, c in ((0, 24, STRAW[3]), (1, 25, STRAW[2]), (26, 24, STRAW[4]), (27, 25, STRAW[3]), (13, 25, STRAW[3])):
        dot(im, x, y, c)
    return ground(im, (1, 21, 27, 26))


# --- Flower bed ---------------------------------------------------------------

DAISY = [".p.", "pcp", ".p."]
BLOOM = [".pp.", "pPcp", "pcPp", ".pp."]
TULIP = ["p.p", "PpP", "Ppp", ".p."]
BELL = [".p.", "pPp", "ppp", "p.p"]


def flower_colors(base):
    light, mid, dark, centre = (hexc(c) for c in base)
    return {"P": light, "p": mid, "D": dark, "c": centre}


PINK = ("#ffc4d4", "#f4729a", "#b83a68", "#ffd23f")
YELLOW = ("#fff2a8", "#ffcc33", "#c88a14", "#c0561a")
WHITE = ("#ffffff", "#ece6f0", "#a8a0c0", "#ffb020")
PURPLE = ("#e4ccff", "#a678ec", "#6440aa", "#ffe060")
ORANGE = ("#ffd8a8", "#ff8c3a", "#c04e18", "#ffe070")
SCARLET = ("#ffb4a4", "#e84436", "#98201e", "#ffd23f")
BLUE = ("#dcefff", "#6aa8f2", "#3456b0", "#ffffff")


def flowerbed(flowers, seed):
    frames = []
    for f in range(FRAMES):
        im = canvas(36, 22)
        # Soil mound.
        blob(im, 18, 15.5, 15.5, 4.6, SOIL, seed=seed)
        # Leaves: overlapping clumps of different sizes.
        for i in range(11):
            x = 5 + i * 2.6 + (noise(i, 1, seed) - 0.5) * 2
            y = 12.5 - noise(i, 2, seed) * 3
            r = 2.4 + noise(i, 3, seed) * 1.6
            blob(im, x, y, r, r * 0.85, LEAF[:5], rough=0.4, seed=seed + i, lift=-0.04)
        frames.append(im)
    out = []
    for f, im in enumerate(frames):
        px = im.load()
        for i, (x, y, kind, colors) in enumerate(flowers):
            dx = sway(f, i * 0.23)
            # Stem bends: only the upper half follows the head.
            for sy in range(y + 2, 13):
                bend = dx if sy < y + 4 else 0
                px[x + 1 + bend, sy] = LEAF[2] if sy % 3 else LEAF[3]
            px[x + 2, y + 5] = LEAF[4]
            stamp = {"d": DAISY, "b": BLOOM, "t": TULIP, "l": BELL}[kind]
            grid(im, stamp, flower_colors(colors), x + dx, y)
        # Stone border along the front.
        for i in range(9):
            sx = 4 + i * 3.6 + (noise(i, 4, seed) - 0.5)
            sy = 17.4 + math.sin(i / 8 * math.pi) * 1.6
            blob(im, sx, sy, 2.1, 1.6, STONE[:5], seed=seed + 30 + i)
        outline(im)
        # Grass tufts at the ends.
        for gx, gy in ((1, 15), (34, 16)):
            dot(im, gx, gy, LEAF[3])
            dot(im, gx, gy - 1, LEAF[4])
        out.append(ground(im, (2, 16, 34, 21)))
    return strip(out)


# --- Scarecrow ----------------------------------------------------------------


def scarecrow():
    frames = []
    for f in range(FRAMES):
        im = canvas(26, 36)
        px = im.load()
        # Pole and crossbar.
        for y in range(14, 34):
            px[12, y] = BARK[3]
            px[13, y] = BARK[2]
            if noise(1, y) > 0.8:
                px[13, y] = BARK[1]
        # Sleeves: puffed, drooping toward the hands.
        for x in range(3, 23):
            droop = 1 if x < 5 or x > 20 else 0
            for y in range(15 + droop, 19 + droop):
                v = 0.75 - (y - 15 - droop) * 0.16 + (0.08 if (x + y) % 5 == 0 else 0)
                px[x, y] = tone(CLOTH_RED, v)
        for x in (6, 9, 16, 19):
            px[x, 16] = CLOTH_RED[1]
            px[x, 17] = CLOTH_RED[1]
        # Patches.
        for x, y in ((7, 16), (8, 16), (7, 17), (8, 17)):
            px[x, y] = DENIM[2] if y == 16 else DENIM[1]
        px[7, 16] = DENIM[3]
        # Shirt body with overall bib.
        for y in range(18, 27):
            for x in range(8, 18):
                px[x, y] = tone(CLOTH_RED, 0.6 - (x - 8) * 0.04 - (y - 18) * 0.02)
        for y in range(20, 28):
            for x in range(9, 17):
                px[x, y] = tone(DENIM, 0.82 - (x - 9) * 0.06 - (y - 20) * 0.02)
        for x in (9, 16):
            for y in range(17, 21):
                px[x, y] = DENIM[2]
        px[10, 22] = hexc("#f0c040")
        px[15, 22] = hexc("#f0c040")
        line(im, [(11, 24), (14, 24)], DENIM[1])
        px[13, 26] = CLOTH_CREAM[2]
        px[14, 26] = CLOTH_CREAM[2]
        # Straw: hands and hem, blowing a little.
        w = sway(f)
        for side, x0 in ((-1, 3), (1, 22)):
            for k, (dx, dy) in enumerate(((1, -1), (2, 0), (1, 1), (2, 2))):
                x = x0 + side * dx
                y = 17 + dy + (w if k % 2 else 0)
                dot(im, x, y, STRAW[4] if k % 2 else STRAW[3])
            dot(im, x0, 17, STRAW[2])
        for i, x in enumerate(range(9, 17)):
            length = 2 + (i % 3 == 1)
            for y in range(28, 28 + length):
                dot(im, x + (w if y > 28 and i % 2 else 0), y, STRAW[3] if i % 2 else STRAW[2])
        # Head: burlap sack.
        blob(im, 13, 11, 4.6, 4.4, BURLAP, seed=5)
        for x, y in ((11, 10), (15, 10)):
            px[x, y] = INK
            px[x, y - 1] = BURLAP[2]
        px[11, 9] = hexc("#5a4a6a")
        px[15, 9] = hexc("#5a4a6a")
        for x, y in ((11, 13), (12, 14), (13, 14), (14, 14), (15, 13)):
            px[x, y] = WOOD[1]
        for x in (12, 14):
            px[x, 13] = WOOD[2]
        px[10, 12] = hexc("#e88a7a")
        px[16, 12] = hexc("#e88a7a")
        # Neck tie.
        line(im, [(11, 15), (15, 15)], STRAW[1])
        # Straw hair under the hat.
        for x in (8, 9, 17, 18):
            dot(im, x, 8 + (x % 2), STRAW[3])
        # Hat, tipped a little to one side.
        for x in range(5, 22):
            y = 7 - (x - 5) // 9
            v = 0.7 - abs(x - 12) * 0.02
            px[x, y] = tone(STRAW, v + 0.12)
            px[x, y + 1] = tone(STRAW, v - 0.25)
        blob(im, 13, 4.2, 4.2, 3.2, STRAW, seed=6, clip=lambda x, y: y <= 6)
        line(im, [(9, 5), (17, 5)], CLOTH_RED[2])
        px[10, 5] = CLOTH_RED[3]
        px[14, 2] = STRAW[1]
        # A crow on the right arm; it pecks on one frame.
        crow = (
            [".kk.....", "kKwk....", "YkKKkkk.", ".kKhhKKk", "..kKKKk.", "...k.k.."]
            if f != 2
            else ["........", ".kk.....", "kKwkkk..", "YkKhhKk.", "..kKKKkk", "...k.k.."]
        )
        grid(im, crow, {"k": hexc("#16101e"), "K": hexc("#2e2a44"), "h": hexc("#4e4a78"), "w": hexc("#d8d0e8"), "Y": hexc("#f0b030")}, 1, 9)
        outline(im)
        frames.append(ground(im, (6, 31, 20, 35)))
    return strip(frames)


# --- Market stall -------------------------------------------------------------

LETTERS = {
    "P": ["111", "101", "111", "100", "100"],
    "A": ["010", "101", "111", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "R": ["110", "101", "110", "101", "101"],
}


def write(im, text, x, y, color, shade):
    for ch in text:
        for r, row in enumerate(LETTERS[ch]):
            for c, bit in enumerate(row):
                if bit == "1":
                    dot(im, x + c + 1, y + r + 1, shade)
        for r, row in enumerate(LETTERS[ch]):
            for c, bit in enumerate(row):
                if bit == "1":
                    dot(im, x + c, y + r, color)
        x += 4


def basket(im, x, y, w, produce, seed):
    """A woven basket heaped with round produce."""
    stem = LEAF[2] if produce in (TOMATO, PUMPKIN, EGGPLANT) else None
    for i, (fx, fy) in enumerate(((2.3, 0), (6.7, 0), (4.5, -2.8))):
        fruit(im, x + fx, y + fy - 1.6, 2.3, produce, seed=seed + i, stem=stem)
    px = im.load()
    for yy in range(y, y + 4):
        for xx in range(x, x + w):
            weave = (xx + yy) % 2
            px[xx, yy] = (STRAW[3] if weave else STRAW[2]) if yy == y else (STRAW[2] if weave else STRAW[1])
    line(im, [(x, y + 3), (x + w - 1, y + 3)], STRAW[0])


def stall():
    frames = []
    W, H = 56, 56
    for f in range(FRAMES):
        im = canvas(W, H)
        px = im.load()
        # Back wall in shadow, with a shelf of jars.
        for y in range(18, 38):
            for x in range(9, 47):
                px[x, y] = WOOD[1] if (y - 18) % 5 else WOOD[0]
        line(im, [(10, 26), (45, 26)], WOOD[3])
        for i, color in enumerate((TOMATO, CORN, CABBAGE, EGGPLANT, PUMPKIN, CORN)):
            jx = 12 + i * 6
            for yy in range(22, 26):
                px[jx, yy] = color[2]
                px[jx + 1, yy] = color[1]
            px[jx, 22] = color[4]
            px[jx, 21] = CLOTH_CREAM[2]
            px[jx + 1, 21] = CLOTH_CREAM[1]
        # Posts.
        for x in (6, 47):
            for y in range(14, 50):
                px[x, y] = WOOD[5]
                px[x + 1, y] = WOOD[4]
                px[x + 2, y] = WOOD[2]
                if noise(x, y) > 0.86:
                    px[x + 1, y] = WOOD[3]
        # Hanging chillies and garlic, swinging.
        s = sway(f, 0.1)
        for i, y in enumerate(range(19, 28)):
            ox = s if y > 23 else 0
            px[13 + ox, y] = TOMATO[3] if i % 2 else TOMATO[2]
            if i:
                px[(12 if i % 2 else 14) + ox, y] = TOMATO[1]
        px[13, 18] = LEAF[2]
        for i, y in enumerate(range(19, 27, 2)):
            ox = -s if y > 22 else 0
            blob(im, 42.5 + ox, y + 1, 1.6, 1.4, CLOTH_CREAM, seed=i)
        # Awning: curved cloth, stripes with folds, sagging in the middle.
        back_l, back_r, front_l, front_r = 11, 44, 2, 53
        top, bottom = 6, 15
        for y in range(top, bottom + 1):
            t = (y - top) / (bottom - top)
            left = back_l + (front_l - back_l) * t
            right = back_r + (front_r - back_r) * t
            for x in range(round(left), round(right) + 1):
                u = (x - left) / (right - left)
                k = u * 10
                stripe = int(k)
                fold = k - stripe
                red = stripe % 2 == 0
                v = 0.8 - t * 0.2 - fold * 0.25 + (0.12 if fold < 0.25 else 0)
                px[x, y] = tone(CLOTH_RED if red else CLOTH_CREAM, v)
        # Ridge pole.
        for x in range(11, 45):
            px[x, 5] = WOOD[4]
            px[x, 4] = WOOD[5]
        # Scalloped valance flapping in the wind.
        for x in range(2, 54):
            u = (x - 2) / 51
            k = int(u * 10)
            red = k % 2 == 0
            sag = 0
            local = (u * 10) % 1
            wave = round(math.sin((x / 7 + f / FRAMES) * math.tau) * 0.6)
            depth = 4 + wave + (1 if 0.2 < local < 0.8 else 0)
            for d in range(depth):
                v = 0.62 - d * 0.12 - (0.15 if local > 0.75 else 0)
                px[x, 16 + sag + d] = tone(CLOTH_RED if red else CLOTH_CREAM, v)
            px[x, 16 + sag] = mix(px[x, 16 + sag], INK, 0.45)
        # Sign on the roof.
        for y in range(0, 6):
            for x in range(18, 39):
                px[x, y] = tone(WOOD[2:], 0.75 - y * 0.08 + (noise(x, y) - 0.5) * 0.1)
        write(im, "PASAR", 19, 0, CLOTH_CREAM[3], WOOD[1])
        # Counter top and planked front.
        for y in range(36, 51):
            for x in range(4, 52):
                if y < 39:
                    v = 0.9 - (y - 36) * 0.18
                else:
                    plank = (x - 4) // 6
                    v = 0.55 + (noise(plank, 0, 9) - 0.5) * 0.25 - (y - 39) * 0.015
                    if (x - 4) % 6 == 0:
                        v = 0.2
                px[x, y] = tone(WOOD[1:], v)
        for x, y in ((13, 43), (31, 46), (44, 41)):
            px[x, y] = WOOD[1]
            px[x + 1, y] = WOOD[2]
        # Price board.
        for y in range(41, 48):
            for x in range(21, 35):
                px[x, y] = tone(CLOTH_CREAM, 0.75 - (y - 41) * 0.06)
        grid(im, ["...gG", "..oog", ".ooO.", "ooO..", "O...."], {"g": LEAF[2], "G": LEAF[4], "o": PUMPKIN[3], "O": PUMPKIN[2]}, 23, 42)
        blob(im, 30.5, 44.5, 2.2, 2.2, CORN, seed=2)
        # Baskets of produce on the counter.
        for i, produce in enumerate((TOMATO, CORN, CABBAGE, EGGPLANT)):
            basket(im, 9 + i * 10, 33, 9, produce, seed=10 + i * 5)
        # Pumpkin and a sack on the ground.
        blob(im, 4.5, 50, 3.4, 2.8, PUMPKIN, seed=4)
        px[4, 47] = LEAF[2]
        px[5, 46] = LEAF[3]
        blob(im, 51, 48.5, 3.4, 4.2, BURLAP, seed=8)
        line(im, [(49, 45), (53, 45)], BURLAP[0])
        dot(im, 51, 44, STRAW[4])
        dot(im, 52, 43, STRAW[3])
        outline(im)
        frames.append(ground(im, (2, 47, 54, 55)))
    return strip(frames)


# --- Well -----------------------------------------------------------------------


def well():
    frames = []
    for f in range(FRAMES):
        im = canvas(36, 40)
        px = im.load()
        cx = 18
        # Stone wall: rows of irregular stones around a cylinder.
        for row in range(3):
            y = 31 + row * 2.6
            n = 7 + row % 2
            for i in range(n):
                u = (i + 0.5 * (row % 2) + 0.5) / (n + 0.5) * 2 - 1
                sx = cx + u * 13.5
                sy = y + (1 - u * u) * 2.6
                rx = 2.6 * math.sqrt(max(0.25, 1 - u * u)) + noise(i, row) * 0.6
                blob(im, sx, sy, rx, 1.7, STONE[:5], seed=row * 10 + i, lift=-0.22 * max(0, u))
        # Capstone rim, then the water inside it.
        blob(im, cx, 28.5, 14.8, 4.6, STONE[1:5], seed=40)
        blob(im, cx, 28.2, 11.6, 3.0, WATER[:3], seed=41, lift=-0.25)
        for i in range(3):
            x = 11 + ((i * 7 + f * 2) % 14)
            y = 27 + (i % 2)
            dot(im, x, y, WATER[3])
            dot(im, x + 1, y, WATER[4] if i == f % 3 else WATER[3])
        # Rim stone joints and moss.
        for i in range(9):
            a = i / 9 * math.pi
            x = round(cx + math.cos(a) * 13.4)
            y = round(28.5 + math.sin(a) * 3.8)
            dot(im, x, y, STONE[1])
        for x, y in ((6, 33), (7, 34), (8, 33), (27, 36), (28, 35), (5, 30)):
            dot(im, x, y, LEAF[3] if (x + y) % 2 else LEAF[2])
        # Log posts with a creeping vine.
        for x in (5, 29):
            for y in range(10, 30):
                px[x, y] = BARK[3]
                px[x + 1, y] = BARK[2]
                if noise(x, y, 3) > 0.8:
                    px[x + 1, y] = BARK[1]
        for y in range(14, 28):
            if y % 3 != 1:
                dot(im, 5 + (y % 2), y, LEAF[3] if y % 2 else LEAF[4])
        dot(im, 7, 18, LEAF[4])
        dot(im, 4, 22, LEAF[3])
        # Crossbar, rope drum and crank.
        line(im, [(7, 14), (28, 14)], WOOD[4])
        line(im, [(7, 15), (28, 15)], WOOD[2])
        for x in range(13, 23):
            px[x, 13] = CLOTH_CREAM[2] if x % 2 else CLOTH_CREAM[1]
            px[x, 14] = CLOTH_CREAM[1] if x % 2 else CLOTH_CREAM[0]
            px[x, 15] = CLOTH_CREAM[0]
        line(im, [(31, 14), (33, 14)], IRON[2])
        line(im, [(33, 14), (33, 17)], IRON[1])
        dot(im, 33, 18, WOOD[5])
        # Bucket swinging on the rope.
        s = sway(f, 0.3)
        line(im, [(18, 16), (18 + s, 19)], CLOTH_CREAM[1])
        bx = 15 + s
        for y in range(20, 25):
            inset = 0 if y < 22 else 1
            for x in range(bx + inset, bx + 7 - inset):
                px[x, y] = tone(WOOD[2:], 0.8 - (x - bx) * 0.09)
        line(im, [(bx, 21), (bx + 6, 21)], IRON[2])
        dot(im, bx, 21, IRON[3])
        line(im, [(bx, 20), (bx + 6, 20)], WOOD[6])
        # Roof of curved shingles, like the houses.
        for row in range(5):
            y0 = 2 + row * 2
            half = 9 + row * 2.4
            for x in range(round(cx - half), round(cx + half) + 1):
                local = (x - cx + half + row * 2) % 4
                for d in range(3):
                    if d == 2 and local in (0, 3):
                        continue
                    v = 0.85 - d * 0.22 - (x - cx + half) / (2 * half) * 0.25
                    dot(im, x, y0 + d, tone(ROOF, v))
        for x in range(round(cx - 9), round(cx + 9) + 1):
            dot(im, x, 1, ROOF[5] if x % 3 else ROOF[4])
        line(im, [(3, 12), (33, 12)], ROOF[1])
        outline(im)
        for gx, gy in ((3, 37), (33, 37), (4, 38)):
            dot(im, gx, gy, LEAF[3])
            dot(im, gx, gy - 1, LEAF[4])
        frames.append(ground(im, (2, 32, 34, 40)))
    return strip(frames)


# --- Crate and barrel -----------------------------------------------------------


def crate():
    im = canvas(18, 18)
    px = im.load()
    # Produce heaped above the rim.
    for i, (x, y, produce) in enumerate(((4.8, 6.5, TOMATO), (9, 6.5, CABBAGE), (13.2, 6.5, TOMATO), (6.9, 3.6, PUMPKIN), (11.1, 3.6, TOMATO))):
        fruit(im, x, y, 2.2, produce, seed=i, stem=LEAF[2] if produce is not CABBAGE else None)
    # Slatted front with corner posts.
    for y in range(8, 17):
        for x in range(2, 16):
            slat = (y - 8) // 3
            v = 0.7 - (y - 8) % 3 * 0.12 + (noise(slat, 0, 4) - 0.5) * 0.2 - (x - 2) * 0.012
            if (y - 8) % 3 == 2:
                v = 0.15
            px[x, y] = tone(WOOD[1:], v)
        for x in (2, 15):
            px[x, y] = WOOD[5] if x == 2 else WOOD[3]
    line(im, [(2, 8), (15, 8)], WOOD[6])
    dot(im, 3, 9, IRON[2])
    dot(im, 14, 9, IRON[2])
    outline(im)
    return ground(im, (1, 13, 17, 18))


def barrel():
    frames = []
    for f in range(FRAMES):
        im = canvas(16, 18)
        px = im.load()
        for y in range(4, 17):
            bulge = math.sin((y - 4) / 12 * math.pi) * 1.4
            left, right = 3 - bulge, 12 + bulge
            for x in range(round(left), round(right) + 1):
                u = (x - left) / (right - left)
                v = 0.92 - abs(u - 0.3) * 1.1
                if round((x - left) * 3.2) % 9 == 0 and 0.1 < u < 0.95:
                    v -= 0.2
                px[x, y] = tone(WOOD[1:], v)
            for hy in (6, 14):
                if y == hy:
                    for x in range(round(left), round(right) + 1):
                        u = (x - left) / (right - left)
                        px[x, y] = tone(IRON, 0.95 - abs(u - 0.25) * 1.2)
        # Open top with rainwater catching the light.
        ImageDraw.Draw(im).ellipse([3, 2, 12, 6], fill=WOOD[3])
        ImageDraw.Draw(im).ellipse([4, 3, 11, 5], fill=WATER[2])
        dot(im, 5 + f % 3 * 2, 4, WATER[4])
        dot(im, 6 + f % 3 * 2, 4, WATER[3])
        line(im, [(5, 2), (10, 2)], WOOD[5])
        outline(im)
        frames.append(ground(im, (1, 14, 15, 18)))
    return strip(frames)


# --- More village props ---------------------------------------------------------

BAMBOO = ramp("#2e3a10", "#56661a", "#86942a", "#b4c048", "#dce27a")
ROPE = ramp("#6a4a2a", "#a8885a", "#d8c094")
BATIK = ramp("#3a1a0c", "#7a3a14", "#b8662a", "#e8a24a")


def wheel(im, cx, cy, r):
    px = im.load()
    for y in range(round(cy - r) - 1, round(cy + r) + 2):
        for x in range(round(cx - r) - 1, round(cx + r) + 2):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r - 1.4 <= d <= r:
                px[x, y] = WOOD[5] if (x - cx) + (y - cy) < 0 else WOOD[2]
    for a in range(0, 360, 45):
        for k in range(1, int(r - 1)):
            x = round(cx + math.cos(math.radians(a)) * k)
            y = round(cy + math.sin(math.radians(a)) * k)
            px[x, y] = WOOD[3]
    blob(im, cx, cy, 1.4, 1.4, IRON, seed=1)


def cart():
    im = canvas(40, 28)
    # Shafts reaching forward to the ground.
    line(im, [(1, 21), (12, 14)], WOOD[4])
    line(im, [(2, 22), (13, 15)], WOOD[2])
    # Load: a heap of produce and a sack under straw.
    blob(im, 24, 9, 9.5, 5.6, STRAW, rough=0.3, seed=4, clip=lambda x, y: y <= 12)
    for i in range(16):
        x = 15 + int(noise(i, 1, 4) * 18)
        y = 5 + int(noise(i, 2, 4) * 7)
        dot(im, x, y, STRAW[4] if i % 2 else STRAW[1])
    for i, (x, y, produce) in enumerate(((18, 9, PUMPKIN), (22, 7.5, PUMPKIN), (27, 8, CABBAGE), (31, 9.5, TOMATO), (25, 10.5, CORN))):
        fruit(im, x, y, 2.2, produce, seed=i, stem=LEAF[2] if produce is not CABBAGE else None)
    blob(im, 34, 8, 3.2, 4.0, BURLAP, seed=6)
    line(im, [(32, 5), (36, 5)], BURLAP[0])
    # Bed of planks with side rails.
    for y in range(12, 19):
        for x in range(12, 38):
            plank = (y - 12) // 2
            v = 0.72 - (y - 12) * 0.05 + (noise(plank, x // 9, 7) - 0.5) * 0.18
            if (y - 12) % 2 == 1 and y > 13:
                v -= 0.25
            dot(im, x, y, tone(WOOD[1:], v))
    line(im, [(12, 12), (37, 12)], WOOD[6])
    for x in (12, 24, 37):
        line(im, [(x, 12), (x, 18)], WOOD[2] if x != 12 else WOOD[5])
    wheel(im, 27, 20, 6.4)
    # Prop stick at the front.
    line(im, [(14, 18), (14, 25)], WOOD[3])
    outline(im)
    return ground(im, (8, 22, 38, 28))


def bamboo_fence():
    im = canvas(20, 20)
    for i, x in enumerate((2, 7, 12, 17)):
        top = 2 + (i % 2) * 2
        for y in range(top, 18):
            dot(im, x, y, BAMBOO[3])
            dot(im, x + 1, y, BAMBOO[2])
            if (y - top) % 5 == 4:
                dot(im, x, y, BAMBOO[1])
                dot(im, x + 1, y, BAMBOO[1])
        dot(im, x, top, BAMBOO[4])
        dot(im, x + 1, top, BAMBOO[1])
    for y in (7, 13):
        line(im, [(0, y), (19, y)], BAMBOO[3])
        line(im, [(0, y + 1), (19, y + 1)], BAMBOO[1])
        for x in (2, 7, 12, 17):
            dot(im, x, y, ROPE[2])
            dot(im, x + 1, y + 1, ROPE[1])
    outline(im)
    return ground(im, (0, 15, 20, 20))


def clothesline():
    frames = []
    for f in range(FRAMES):
        im = canvas(44, 30)
        # Bamboo posts.
        for x in (2, 41):
            for y in range(4, 28):
                dot(im, x, y, BAMBOO[3])
                dot(im, x + 1, y, BAMBOO[2])
                if y % 6 == 3:
                    dot(im, x, y, BAMBOO[1])
                    dot(im, x + 1, y, BAMBOO[1])
            dot(im, x, 4, BAMBOO[4])
        # Sagging rope.
        def rope_y(x):
            u = (x - 3) / 38
            return 6 + round(math.sin(u * math.pi) * 3)
        for x in range(3, 41):
            dot(im, x, rope_y(x), ROPE[1])
        w = sway(f)
        w2 = sway(f, 0.3)
        # A shirt.
        sx = 7
        top = rope_y(sx + 4) + 1
        for y in range(top, top + 9):
            for x in range(sx + 1, sx + 8):
                dx = w if y > top + 5 else 0
                dot(im, x + dx, y, tone(DENIM, 0.8 - (x - sx) * 0.07))
        for y in range(top, top + 4):
            dot(im, sx, y, DENIM[2])
            dot(im, sx + 8, y, DENIM[1])
            dot(im, sx - 1, y + 1, DENIM[2])
            dot(im, sx + 9, y + 1, DENIM[1])
        line(im, [(sx + 3, top), (sx + 5, top)], DENIM[0])
        # A batik sarong, long and swinging most.
        bx = 19
        top = rope_y(bx + 4) + 1
        for y in range(top, top + 14):
            dx = w2 if y > top + 6 else 0
            dx += w2 if y > top + 11 else 0
            for x in range(bx, bx + 9):
                pattern = (x + y * 2) % 6 in (0, 1) or (x - y) % 5 == 0
                c = BATIK[3] if pattern else BATIK[1]
                if x == bx:
                    c = BATIK[2]
                dot(im, x + dx, y, c)
        line(im, [(bx, top + 13 + w2 * 2), (bx + 8, top + 13 + w2 * 2)], BATIK[0])
        # A towel.
        tx = 32
        top = rope_y(tx + 3) + 1
        for y in range(top, top + 7):
            dx = w if y > top + 4 else 0
            for x in range(tx, tx + 6):
                c = CLOTH_RED[3] if (y - top) % 3 else CLOTH_CREAM[3]
                dot(im, x + dx, y, c)
        # Pegs.
        for x in (sx + 2, sx + 6, bx + 1, bx + 7, tx + 1, tx + 4):
            dot(im, x, rope_y(x), WOOD[5])
            dot(im, x, rope_y(x) - 1, WOOD[4])
        outline(im)
        # A basket of laundry below.
        basket(im, 30, 25, 8, CLOTH_CREAM, seed=9)
        outline(im)
        frames.append(ground(im, (0, 24, 44, 30)))
    return strip(frames)


def chicken_coop():
    im = canvas(36, 34)
    px = im.load()
    # Legs.
    for x in (6, 28):
        for y in (24, 25, 26, 27, 28, 29, 30):
            dot(im, x, y, WOOD[3])
            dot(im, x + 1, y, WOOD[2])
    # House body of vertical planks.
    for y in range(11, 25):
        for x in range(5, 31):
            plank = (x - 5) // 3
            v = 0.7 - (x - 5) * 0.012 + (noise(plank, 0, 12) - 0.5) * 0.2 - (y - 11) * 0.01
            if (x - 5) % 3 == 0:
                v -= 0.22
            dot(im, x, y, tone(WOOD[1:], v))
    # Door with straw nest and an egg.
    for y in range(15, 24):
        for x in range(13, 21):
            dot(im, x, y, WOOD[0])
    blob(im, 17, 22, 3.6, 1.6, STRAW, seed=13, clip=lambda x, y: y <= 23)
    blob(im, 16, 20.5, 1.2, 1.5, CLOTH_CREAM[1:], seed=14)
    line(im, [(12, 14), (21, 14)], WOOD[5])
    line(im, [(12, 14), (12, 24)], WOOD[5])
    line(im, [(21, 14), (21, 24)], WOOD[2])
    # Little window.
    for y in range(15, 18):
        for x in range(25, 28):
            dot(im, x, y, WOOD[0])
    dot(im, 25, 15, STRAW[3])
    # Ramp down to the ground.
    for i in range(9):
        x0 = 15 + i
        y = 25 + i
        if y >= im.height - 2:
            break
        line(im, [(x0 - 2, y), (x0 + 3, y)], WOOD[4] if i % 2 else WOOD[3])
    # Roof: red tiles like the houses, with a thick overhang.
    for row in range(5):
        y0 = 2 + row * 2
        half = 9 + row * 2.6
        cx = 18
        for x in range(round(cx - half), round(cx + half) + 1):
            for d in range(2):
                v = 0.85 - d * 0.3 - (x - cx + half) / (2 * half) * 0.3
                if (x + row * 2) % 4 == 0 and d == 1:
                    v -= 0.2
                dot(im, x, y0 + d, tone(ROOF, v))
    line(im, [(2, 12), (34, 12)], ROOF[1])
    line(im, [(10, 1), (26, 1)], ROOF[5])
    # A hen peeking from the door.
    grid(im, [".r.", "WWW", "WkW", "WWo"], {"r": CLOTH_RED[3], "W": CLOTH_CREAM[4], "k": INK, "o": BILL_ORANGE}, 15, 16)
    outline(im)
    return ground(im, (3, 27, 33, 34))


BILL_ORANGE = hexc("#f0a020")


def notice_board():
    frames = []
    for f in range(FRAMES):
        im = canvas(28, 30)
        # Posts and a little roof.
        for x in (4, 22):
            for y in range(5, 28):
                dot(im, x, y, WOOD[4])
                dot(im, x + 1, y, WOOD[2])
        for row in range(3):
            y = 1 + row
            for x in range(1 - row, 28 + row - 1):
                if 0 <= x < 28:
                    dot(im, x, y, tone(ROOF, 0.85 - row * 0.25 - x * 0.008))
        line(im, [(0, 4), (27, 4)], ROOF[1])
        # Cork-coloured board.
        for y in range(7, 20):
            for x in range(3, 25):
                v = 0.55 + (noise(x, y, 15) - 0.5) * 0.2
                dot(im, x, y, tone(BURLAP, v))
        line(im, [(3, 7), (24, 7)], WOOD[5])
        line(im, [(3, 20), (24, 20)], WOOD[2])
        # Notices pinned up; the loose corner of one lifts in the wind.
        notes = [(5, 9, 6, 7, CLOTH_CREAM), (12, 8, 5, 5, ramp("#c8a020", "#f0d050", "#fff0a0", "#fffad0")), (18, 10, 5, 6, CLOTH_CREAM), (11, 14, 6, 5, ramp("#8ab0d0", "#b8d8f0", "#e0f0ff", "#ffffff"))]
        for i, (x0, y0, w, h, colors) in enumerate(notes):
            for y in range(y0, y0 + h):
                for x in range(x0, x0 + w):
                    dot(im, x, y, colors[2] if (y - y0) % 2 else colors[3])
                if y > y0 and (y - y0) % 2 == 0:
                    line(im, [(x0 + 1, y), (x0 + w - 2, y)], colors[0] if i != 1 else WOOD[2])
            dot(im, x0 + w // 2, y0, CLOTH_RED[3])
        lift = (0, 1, 2, 1)[f]
        for k in range(lift):
            dot(im, 23 - k, 16 - k, CLOTH_CREAM[3])
            dot(im, 22 - k, 15 - k, CLOTH_CREAM[2])
        # A small wheat-sheaf symbol on the top notice.
        dot(im, 14, 9, STRAW[1])
        dot(im, 14, 10, STRAW[1])
        dot(im, 13, 9, STRAW[2])
        dot(im, 15, 9, STRAW[2])
        outline(im)
        frames.append(ground(im, (2, 25, 26, 30)))
    return strip(frames)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    hay_heap().save(OUT / "jerami.png")
    hay_stack().save(OUT / "jerami_tumpuk.png")
    flowerbed(
        [(4, 6, "b", PINK), (8, 3, "d", YELLOW), (12, 5, "t", SCARLET), (16, 2, "b", WHITE),
         (20, 5, "l", PURPLE), (24, 3, "b", PINK), (28, 5, "t", YELLOW), (31, 7, "d", WHITE)],
        seed=11,
    ).save(OUT / "bunga.png")
    flowerbed(
        [(4, 5, "t", ORANGE), (8, 2, "b", BLUE), (12, 5, "t", SCARLET), (16, 3, "d", YELLOW),
         (20, 5, "t", PINK), (24, 2, "b", WHITE), (28, 4, "t", ORANGE), (31, 7, "l", BLUE)],
        seed=23,
    ).save(OUT / "bunga_2.png")
    scarecrow().save(OUT / "orangan.png")
    stall().save(OUT / "kios.png")
    well().save(OUT / "sumur.png")
    crate().save(OUT / "peti.png")
    barrel().save(OUT / "tong.png")
    cart().save(OUT / "gerobak.png")
    bamboo_fence().save(OUT / "pagar_bambu.png")
    clothesline().save(OUT / "jemuran.png")
    chicken_coop().save(OUT / "kandang_ayam.png")
    notice_board().save(OUT / "papan_pengumuman.png")


if __name__ == "__main__":
    main()
