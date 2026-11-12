"""Alternate app icons modeled on the IONIQ 5's Parametric Pixel lamps.

Usage: python make_lamp_icon.py <out.png> --front | --rear
--front: one IONIQ 5 headlamp: a smoked-glass housing with two U-shaped
         light guides, and the silver strip beneath it.
--rear:  the full-width black tail bar with red pixel blocks at each end,
         lit on the diagonal.
Inspired by the lamps, simplified to a few big pixels so it reads at icon size.
Original artwork of the lamp motif; no logos. Renders at 4x and downsamples.
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
rear = "--rear" in sys.argv
S, K = 1024, 4
N = S * K
lit = np.array((255, 46, 40) if rear else (236, 244, 255), np.float32)
glow = (255, 30, 24) if rear else (150, 190, 255)

# Body paint: a dark metallic radial, cooler for the front, warmer for the rear.
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
t = np.clip(np.sqrt((xx - 0.5) ** 2 + (yy - 0.42) ** 2) / 0.75, 0, 1)[..., None] ** 1.2
center = np.array((46, 22, 26) if rear else (34, 38, 48), np.float32)
edge = np.array((6, 3, 4) if rear else (4, 5, 8), np.float32)
bg = center * (1 - t) + edge * t
# A soft horizontal sheen above the band, like light on the hood/liftgate.
bg += (np.exp(-((yy - 0.3) / 0.08) ** 2) * 10)[..., None]
img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

# Gloss-black band across the middle.
band_top, band_bot = (int(N * 0.355), int(N * 0.645)) if rear else (int(N * 0.32), int(N * 0.68))
band = Image.new("RGBA", (N, N), (0, 0, 0, 0))
bd = ImageDraw.Draw(band)
bd.rounded_rectangle([int(N * 0.06), band_top, int(N * 0.94), band_bot], radius=36 * K, fill=(8, 8, 10, 255))
img.alpha_composite(band)
# Reflection highlight along the top edge of the band.
hl = np.zeros((N, N, 4), np.uint8)
hl[band_top + 6 * K:band_top + 10 * K, int(N * 0.10):int(N * 0.90)] = (255, 255, 255, 28)
img.alpha_composite(Image.fromarray(hl, "RGBA"))

# Pixel lamps: a cols x rows grid at each end of the band.
cols, rows = (2, 2) if rear else (1, 1)
pitch = 118 * K if rear else 330 * K
size = 96 * K if rear else 300 * K
unit_w, unit_h = cols * pitch, rows * pitch
cy = (band_top + band_bot) / 2
units = [N * 0.06 + 34 * K, N * 0.94 - 34 * K - unit_w] if rear else [N / 2 - unit_w / 2]


def brightness(c, r):
    if rear:
        # Stair-step pattern like the real tail lamps: lit on a diagonal.
        return 1.0 if (c + r) % 2 == 0 else 0.3
    return 1.0


bloom = Image.new("RGBA", (N, N), (0, 0, 0, 0))
pix = Image.new("RGBA", (N, N), (0, 0, 0, 0))
bdraw, pdraw = ImageDraw.Draw(bloom), ImageDraw.Draw(pix)
for ux in units:
    x_start = ux
    y_start = cy - unit_h / 2
    for r in range(rows):
        for c in range(cols):
            b = brightness(c, r)
            x0 = x_start + c * pitch + (pitch - size) / 2
            y0 = y_start + r * pitch + (pitch - size) / 2
            box = [x0, y0, x0 + size, y0 + size]
            if b > 0.5:
                bdraw.rounded_rectangle(box, radius=(18 if rear else 40) * K, fill=(*glow, 255))
            col = lit * b + np.array((28, 10, 10) if rear else (26, 30, 38)) * (1 - b)
            pdraw.rounded_rectangle(box, radius=(18 if rear else 40) * K, fill=tuple(int(v) for v in col) + (255,))
for radius, strength in ((90 * K, 1), (90 * K, 1), (30 * K, 1), (10 * K, 1)):
    img.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(radius)))
img.alpha_composite(pix)

if not rear:
    # Redraw: the headlamp housing and its two U-shaped light guides.
    img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    x0, x1, y0, y1 = N * 0.07, N * 0.93, N * 0.36, N * 0.60
    housing = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    hd = ImageDraw.Draw(housing)
    hd.rounded_rectangle([x0, y0, x1, y1], radius=40 * K, fill=(10, 12, 16, 255))
    img.alpha_composite(housing)
    # Glass sheen along the top of the housing.
    sheen = np.zeros((N, N, 4), np.uint8)
    sheen[int(y0 + 8 * K):int(y0 + 13 * K), int(x0 + 40 * K):int(x1 - 40 * K)] = (255, 255, 255, 34)
    img.alpha_composite(Image.fromarray(sheen, "RGBA"))
    # Two U-shaped light guides (open at the top), side by side.
    stroke = 30 * K
    lights = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lights)
    gap = 56 * K
    width = (x1 - x0 - 2 * 60 * K - gap) / 2
    top, bottom = y0 + 58 * K, y1 - 52 * K
    for i in range(2):
        left = x0 + 60 * K + i * (width + gap)
        right = left + width
        ld.rectangle([left, top, left + stroke, bottom], fill=(236, 244, 255, 255))
        ld.rectangle([right - stroke, top, right, bottom], fill=(236, 244, 255, 255))
        ld.rectangle([left, bottom - stroke, right, bottom], fill=(236, 244, 255, 255))
    glow_layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    glow_layer.paste((150, 190, 255, 255), mask=lights.getchannel("A"))
    for radius in (80 * K, 30 * K, 10 * K):
        img.alpha_composite(glow_layer.filter(ImageFilter.GaussianBlur(radius)))
    img.alpha_composite(lights)
    # Silver light strip below the lamp.
    strip = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sd = ImageDraw.Draw(strip)
    sd.rounded_rectangle([x0 + 10 * K, y1 + 30 * K, x1 - 10 * K, y1 + 48 * K], radius=9 * K, fill=(200, 206, 214, 220))
    img.alpha_composite(strip)

img.resize((S, S), Image.LANCZOS).convert("RGB").save(out)
print("wrote", out)
