#!/usr/bin/env python3
"""Draw quortal's dev textures into data/textures/quortal.

Each colour gets two textures of 128x128 pixels, which cover 64x64 units at
the usual texture scale of 0.5. floor_<colour> is a 64-unit grid with a tick
every 8 units along its lines, and wall_<colour> adds an arrow and the label
UP, pointing to the top of the texture. A map gives each room its own colour.

plug is the editor image of the shader that fills a portal end's opening: a
grid like the floors', in a colour of its own, labelled PLUG.

label_<name> is 512x64 pixels, 256x32 units, and paints the name of one of
the test maps' stations on a wall, in the colour of the station's room.

Needs nothing but Python 3, and draws the same files every time.
"""

import pathlib
import struct
import zlib

SIZE = 128
UNIT = 2  # pixels per unit

COLORS = {
    "red": (176, 64, 64),
    "orange": (196, 112, 48),
    "yellow": (184, 160, 56),
    "green": (80, 152, 72),
    "cyan": (56, 152, 160),
    "blue": (64, 96, 184),
    "purple": (136, 80, 168),
    "gray": (136, 136, 136),
}

PLUG_COLOR = (200, 72, 160)

LABEL_WIDTH = 512
LABEL_HEIGHT = 64

# Each station's label, and the colour of its room
LABELS = {
    "good": "purple",
    "unpaired": "purple",
    "own_partner": "purple",
    "size_mismatch": "purple",
    "no_width": "purple",
    "no_height": "purple",
    "bad_angles": "purple",
    "angle_and_angles": "purple",
}

GLYPHS = {
    "G": [".XXX.", "X...X", "X....", "X.XXX", "X...X", "X...X", ".XXX."],
    "L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
    "P": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
    "U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "a": [".....", ".....", ".XXX.", "....X", ".XXXX", "X...X", ".XXXX"],
    "b": ["X....", "X....", "XXXX.", "X...X", "X...X", "X...X", "XXXX."],
    "c": [".....", ".....", ".XXX.", "X....", "X....", "X...X", ".XXX."],
    "d": ["....X", "....X", ".XXXX", "X...X", "X...X", "X...X", ".XXXX"],
    "e": [".....", ".....", ".XXX.", "X...X", "XXXXX", "X....", ".XXX."],
    "f": ["..XX.", ".X..X", ".X...", "XXX..", ".X...", ".X...", ".X..."],
    "g": [".....", ".....", ".XXXX", "X...X", "X...X", "X...X", ".XXXX", "....X", ".XXX."],
    "h": ["X....", "X....", "X.XX.", "XX..X", "X...X", "X...X", "X...X"],
    "i": ["..X..", ".....", ".XX..", "..X..", "..X..", "..X..", ".XXX."],
    "j": ["...X.", ".....", "..XX.", "...X.", "...X.", "...X.", "...X.", "X..X.", ".XX.."],
    "k": ["X....", "X....", "X..X.", "X.X..", "XX...", "X.X..", "X..X."],
    "l": [".XX..", "..X..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
    "m": [".....", ".....", "XX.X.", "X.X.X", "X.X.X", "X...X", "X...X"],
    "n": [".....", ".....", "X.XX.", "XX..X", "X...X", "X...X", "X...X"],
    "o": [".....", ".....", ".XXX.", "X...X", "X...X", "X...X", ".XXX."],
    "p": [".....", ".....", "XXXX.", "X...X", "X...X", "X...X", "XXXX.", "X....", "X...."],
    "q": [".....", ".....", ".XXXX", "X...X", "X...X", "X...X", ".XXXX", "....X", "....X"],
    "r": [".....", ".....", "X.XX.", "XX..X", "X....", "X....", "X...."],
    "s": [".....", ".....", ".XXXX", "X....", ".XXX.", "....X", "XXXX."],
    "t": [".X...", ".X...", "XXX..", ".X...", ".X...", ".X..X", "..XX."],
    "u": [".....", ".....", "X...X", "X...X", "X...X", "X..XX", ".XX.X"],
    "v": [".....", ".....", "X...X", "X...X", "X...X", ".X.X.", "..X.."],
    "w": [".....", ".....", "X...X", "X...X", "X.X.X", "X.X.X", ".X.X."],
    "x": [".....", ".....", "X...X", ".X.X.", "..X..", ".X.X.", "X...X"],
    "y": [".....", ".....", "X...X", "X...X", "X...X", "X...X", ".XXXX", "....X", ".XXX."],
    "z": [".....", ".....", "XXXXX", "...X.", "..X..", ".X...", "XXXXX"],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "XXXXX"],
}
GLYPH_WIDTH = 5
GLYPH_HEIGHT = 7
DESCENDER = 2  # rows below the line, for g, j, p, q and y

OUTPUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "data" / "textures" / "quortal"


def shade(color, factor):
    return tuple(round(c * factor) for c in color)


def tint(color, factor):
    return tuple(round(c + (255 - c) * factor) for c in color)


def fill(pixels, x0, y0, x1, y1, color):
    """Fill the pixels from (x0, y0) up to, not including, (x1, y1)."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            pixels[y][x] = color


def text_width(text, scale, gap):
    return len(text) * GLYPH_WIDTH * scale + (len(text) - 1) * gap


def draw_text(pixels, text, x0, y0, scale, gap, color):
    """Draw text with its top left corner at (x0, y0), each of its glyphs'
    pixels drawn scale by scale, and gap pixels between glyphs."""
    for glyph in text:
        for row, line in enumerate(GLYPHS[glyph]):
            for column, mark in enumerate(line):
                if mark == "X":
                    x = x0 + column * scale
                    y = y0 + row * scale
                    fill(pixels, x, y, x + scale, y + scale, color)
        x0 += GLYPH_WIDTH * scale + gap


def draw_grid(pixels, color):
    # The texture's edges are the grid's lines, a pixel each side, so that
    # two textures side by side draw a line one unit wide between them
    last = SIZE - 1
    fill(pixels, 0, 0, SIZE, 1, color)
    fill(pixels, 0, last, SIZE, SIZE, color)
    fill(pixels, 0, 0, 1, SIZE, color)
    fill(pixels, last, 0, SIZE, SIZE, color)

    # Ticks every 8 units, 3 units long, and 6 at the line's middle, which
    # meet those of the next texture across the line
    for unit in range(8, 64, 8):
        x = unit * UNIT
        length = (6 if unit == 32 else 3) * UNIT
        fill(pixels, x - 1, 0, x + 1, length, color)
        fill(pixels, x - 1, SIZE - length, x + 1, SIZE, color)
        fill(pixels, 0, x - 1, length, x + 1, color)
        fill(pixels, SIZE - length, x - 1, SIZE, x + 1, color)


def draw_up(pixels, color):
    middle = SIZE // 2

    # The arrow's head, its point at the top, then its shaft
    top, bottom, half_width = 22, 46, 20
    for y in range(top, bottom):
        half = round((y - top) * half_width / (bottom - top))
        fill(pixels, middle - half, y, middle + half, y + 1, color)
    fill(pixels, middle - 4, bottom, middle + 4, 84, color)

    # The label, each of its glyphs' pixels drawn 2 by 2
    draw_text(pixels, "UP", middle - text_width("UP", 2, 4) // 2, 92, 2, 4, color)


def draw_label(name, color):
    pixels = [[color] * LABEL_WIDTH for _ in range(LABEL_HEIGHT)]
    scale, gap = 4, 4
    x0 = (LABEL_WIDTH - text_width(name, scale, gap)) // 2
    y0 = (LABEL_HEIGHT - (GLYPH_HEIGHT + DESCENDER) * scale) // 2
    draw_text(pixels, name, x0, y0, scale, gap, tint(color, 0.55))
    return pixels


def write_png(path, pixels):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    width, height = len(pixels[0]), len(pixels)
    rows = b"".join(b"\0" + bytes(c for pixel in row for c in pixel) for row in pixels)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, color in COLORS.items():
        for kind in ("floor", "wall"):
            pixels = [[color] * SIZE for _ in range(SIZE)]
            draw_grid(pixels, shade(color, 0.55))
            if kind == "wall":
                draw_up(pixels, tint(color, 0.55))
            write_png(OUTPUT_DIR / f"{kind}_{name}.png", pixels)

    pixels = [[PLUG_COLOR] * SIZE for _ in range(SIZE)]
    draw_grid(pixels, shade(PLUG_COLOR, 0.55))
    draw_text(pixels, "PLUG", (SIZE - text_width("PLUG", 2, 4)) // 2,
              (SIZE - GLYPH_HEIGHT * 2) // 2, 2, 4, tint(PLUG_COLOR, 0.55))
    write_png(OUTPUT_DIR / "plug.png", pixels)

    for name, color in LABELS.items():
        write_png(OUTPUT_DIR / f"label_{name}.png", draw_label(name, COLORS[color]))


if __name__ == "__main__":
    main()
