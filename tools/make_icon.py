"""App icon: four glowing square pixels over a pixel field, on a dark purple-to-black radial gradient.

An original abstract mark: four dots in a row (a nod to the pixel/dot motifs
of modern EV design), no logos or photos. Renders at 4x and downsamples.
Usage: python make_icon.py <out.png> [--dark]
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
dark = "--dark" in sys.argv
# --accent=R,G,B tints the whole icon (default: Ion violet).
accent = next((tuple(int(v) for v in a.split("=", 1)[1].split(",")) for a in sys.argv if a.startswith("--accent=")),
              (131, 56, 236))  # Blue Violet
acc = np.array(accent, np.float32)
def mix(c, other, t): return tuple(int(x) for x in (np.array(c, np.float32) * (1 - t) + np.array(other, np.float32) * t))
S, K = 1024, 4
N = S * K

# Background: smooth radial gradient, dark purple at the center to near-black
# at the edges. No texture, so it stays clean at every size.
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
dist = np.clip(np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) / 0.72, 0, 1)[..., None]
# Glow color: the accent's hue, more saturated and dimmed (silver stays neutral).
import colorsys
_h, _s, _v = colorsys.rgb_to_hsv(*(acc / 255))
_val = (0.34 if dark else 0.53) * (0.62 if _s < 0.15 else 1)  # neutral accents glow dimmer
center = np.array(colorsys.hsv_to_rgb(_h, min(1, _s * 1.9), _val), np.float32) * 255
edge = np.array([0x01, 0x00, 0x02] if dark else [0x03, 0x01, 0x06], np.float32)
t = dist ** 1.25
bg = center * (1 - t) + edge * t
paper = "--paper" in sys.argv or "--pastel" in sys.argv  # light themes: no glow, soft drop shadow
pastel = "--pastel" in sys.argv
if pastel:
    bg = (np.array([255, 222, 208], np.float32) * (1 - t) + np.array([214, 210, 255], np.float32) * t)
    bg += np.exp(-(((xx - 0.2) / 0.4) ** 2 + ((yy - 0.9) / 0.35) ** 2))[..., None] * np.array([-30, 10, -5], np.float32)
elif paper:
    bg = np.array([0xF7, 0xF4, 0xEC], np.float32) * (1 - t * 0.6) + np.array([0xE4, 0xDE, 0xD0], np.float32) * (t * 0.6)
img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


# Pixel field: small squares whose brightness ripples out from the dots, so
# the grid fades toward the corners.
field = Image.new("RGBA", (N, N), (0, 0, 0, 0))
draw = ImageDraw.Draw(field)
pitch, size = 34 * K, 20 * K
for gy in range(0, N, pitch):
    for gx in range(0, N, pitch):
        cx, cy = (gx + pitch / 2) / N, (gy + pitch / 2) / N
        # Lit like a pixel lamp: a horizontal band through the dots, fading out.
        band = np.exp(-((cy - 0.5) / 0.11) ** 2) * np.exp(-((cx - 0.5) / 0.5) ** 2)
        a = 0.015 + 0.2 * band
        if a > 0.01:
            x0, y0 = gx + (pitch - size) / 2, gy + (pitch - size) / 2
            draw.rounded_rectangle([x0, y0, x0 + size, y0 + size], radius=3 * K,
                                   fill=((255, 255, 255, int(255 * a * 2.2)) if pastel else (70, 74, 82, int(255 * a * 1.6)) if paper else (*mix(accent, (255, 255, 255), 0.45), int(255 * a))))
img.alpha_composite(field)

# Four square pixels in a row.
r = 40 * K
gap = 150 * K
cx0 = N / 2 - gap * 1.5
cy = N / 2
bloom = Image.new("RGBA", (N, N), (0, 0, 0, 0))
dots = Image.new("RGBA", (N, N), (0, 0, 0, 0))
bd, dd = ImageDraw.Draw(bloom), ImageDraw.Draw(dots)
for i in range(4):
    cx = cx0 + gap * i
    bd.rounded_rectangle([cx - r * 1.15, cy - r * 1.15, cx + r * 1.15, cy + r * 1.15], radius=10 * K, fill=(*mix(accent, (0, 0, 0), 0.05), 230))
    # Square pixels, like the car's lamps, with just a hint of corner rounding.
    dd.rounded_rectangle([cx - r, cy - r, cx + r, cy + r], radius=8 * K, fill=(255, 255, 255, 255))
if paper:
    bloom = Image.new("RGBA", (N, N), (0, 0, 0, 0))  # no glow on paper; a soft drop shadow instead
    bd = ImageDraw.Draw(bloom)
    for i in range(4):
        cx = cx0 + gap * i
        bd.rounded_rectangle([cx - r, cy - r + 10 * K, cx + r, cy + r + 10 * K], radius=8 * K, fill=(0, 0, 0, 70))
img.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(44 * K)))
img.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(16 * K)))
img.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(5 * K)))

# Give each dot a subtle top-lit gradient so it reads as glass, not flat.
shade = np.zeros((N, N, 4), np.float32)
for i in range(4):
    cx = cx0 + gap * i
    x0, x1 = int(cx - r), int(cx + r)
    y0, y1 = int(cy - r), int(cy + r)
    ly = np.linspace(0, 1, y1 - y0)[:, None]
    pastels = [(255, 186, 160), (196, 180, 255), (160, 226, 200), (160, 206, 255)]
    if pastel:
        base = np.array(pastels[i], np.float32)
        col = np.array(mix(pastels[i], (255, 255, 255), 0.45)) * (1 - ly) + base * ly
    else:
        col = (np.array([86, 90, 98]) * (1 - ly) + np.array([38, 40, 46]) * ly) if paper else \
            np.array(mix(accent, (255, 255, 255), 0.62)) * (1 - ly) + acc * ly
    shade[y0:y1, x0:x1, :3] = np.repeat(col[:, None, :], x1 - x0, axis=1).reshape(y1 - y0, x1 - x0, 3)
shade[..., 3] = np.array(dots.getchannel("A"), np.float32)
img.alpha_composite(Image.fromarray(shade.astype(np.uint8), "RGBA"))

img = img.resize((S, S), Image.LANCZOS).convert("RGB")
img.save(out)
print("wrote", out)
