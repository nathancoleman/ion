"""Turns the studio car renders into pencil sketches for the Sketch theme.

Usage: python sketch.py <studio.jpg> <out.png> [--mirror]
Output is graphite on transparent, so it sits on any paper background.
"""
import sys

import cv2
import numpy as np
from PIL import Image, ImageOps

src, out = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGB")
if "--mirror" in sys.argv:
    img = ImageOps.mirror(img)
# Work at 2x so strokes stay fine after the app scales it.
img = img.resize((img.width * 2, img.height * 2), Image.LANCZOS)
gray = np.array(img.convert("L")).astype(np.float32) / 255

# Classic pencil effect: color-dodge the image with its blurred inverse.
inv_blur = cv2.GaussianBlur(1 - gray, (0, 0), 9)
dodge = np.clip(gray / np.maximum(1 - inv_blur, 1e-3), 0, 1)

# Crisper contour strokes on top, slightly broken up like real pencil.
edges = cv2.Canny((gray * 255).astype(np.uint8), 40, 110).astype(np.float32) / 255
edges = cv2.GaussianBlur(edges, (0, 0), 0.8)
rng = np.random.default_rng(3)
grain = rng.normal(1.0, 0.18, gray.shape).astype(np.float32)
strokes = np.clip(edges * grain * 0.85, 0, 1)

# Directional hatching in the dark areas (tires, glass, shadow).
yy, xx = np.mgrid[0:gray.shape[0], 0:gray.shape[1]]
hatch = (np.sin((xx + yy) * 0.9) > 0.55).astype(np.float32)
hatch = cv2.GaussianBlur(hatch, (0, 0), 0.6)
darkness = np.clip((0.55 - gray) / 0.55, 0, 1)

ink = np.clip((1 - dodge) * 2.5 + strokes * 1.6 + hatch * darkness * 0.75 + darkness * 0.25, 0, 1)
ink = np.clip(ink * grain, 0, 1) ** 0.7  # heavier mid-tones
ink[ink < 0.06] = 0  # keep the paper clean

graphite = np.array([24, 25, 30], np.float32)
rgba = np.zeros((*ink.shape, 4), np.uint8)
rgba[..., :3] = graphite
rgba[..., 3] = (ink * 255).astype(np.uint8)
result = Image.fromarray(rgba, "RGBA")
result = result.crop(result.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox())
result.save(out, optimize=True)
print("wrote", out, result.size)
