"""Generates the Matalino app icons (launcher + adaptive layers).

Run from the matalino/ folder:  python3 tools/gen_icons.py
Needs Pillow. Draws at 4x and downsamples for smooth edges.
"""
from PIL import Image, ImageDraw

BG = (14, 15, 19, 255)
TILE = (32, 35, 44, 255)
GOLD = (247, 185, 64, 255)
BLUE = (79, 139, 255, 255)
MINT = (46, 230, 166, 255)
PINK = (255, 107, 139, 255)
VIOLET = (176, 124, 255, 255)

SS = 4


def emblem(size, inset):
    """3x3 tile mark: five lit tiles (one per game color) forming an M."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    area = big * (1 - 2 * inset)
    gap = area * 0.07
    cell = (area - 2 * gap) / 3
    x0 = y0 = big * inset
    lit = {(0, 0): GOLD, (2, 0): BLUE, (1, 1): MINT, (0, 2): PINK, (2, 2): VIOLET,
           (0, 1): GOLD, (2, 1): BLUE}
    for r in range(3):
        for c in range(3):
            x = x0 + c * (cell + gap)
            y = y0 + r * (cell + gap)
            col = lit.get((c, r), TILE)
            d.rounded_rectangle([x, y, x + cell, y + cell], radius=cell * 0.28, fill=col)
    return img


def save(img, size, path):
    img.resize((size, size), Image.LANCZOS).save(path)


def main():
    # Legacy launcher icon: rounded dark square with the emblem.
    n = 192
    big = Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle([0, 0, n * SS - 1, n * SS - 1], radius=n * SS * 0.22, fill=BG)
    big.alpha_composite(emblem(n, 0.2))
    save(big, 192, "assets/icons/icon_192.png")
    save(big, 256, "icon.png")

    # Adaptive icon: emblem within the 66% safe zone, plain background.
    save(emblem(432, 0.27), 432, "assets/icons/adaptive_fg_432.png")
    Image.new("RGBA", (432, 432), BG).save("assets/icons/adaptive_bg_432.png")


if __name__ == "__main__":
    main()
