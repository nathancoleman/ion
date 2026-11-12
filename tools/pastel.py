"""Paints a studio car cutout as a pastel painting for the Pastel theme.

Usage: python pastel.py <car-tinted.png> <out.png>
Input is the car already tinted (see the Pastel step in the README) with its
ground shadow. Output keeps transparency so the app's wash shows through.
"""
import sys

import cv2
import numpy as np
from PIL import Image


def kuwahara(img, radius):
    """Painterly smoothing: each pixel takes the mean of its least-varied
    quadrant, which turns detail into flat brush-like patches with crisp edges."""
    k = radius + 1
    mean = cv2.blur(img, (k, k))
    sq = cv2.blur(img * img, (k, k))
    var = (sq - mean * mean).sum(axis=2)
    h, w = var.shape
    pad = lambda a: cv2.copyMakeBorder(a, k, k, k, k, cv2.BORDER_REFLECT)
    pm, pv = pad(mean), pad(var)
    best_mean = np.zeros_like(img)
    best_var = np.full((h, w), np.inf, np.float32)
    c = radius // 2
    for dy in (-c, c):
        for dx in (-c, c):
            m = pm[k + dy:k + dy + h, k + dx:k + dx + w]
            v = pv[k + dy:k + dy + h, k + dx:k + dx + w]
            take = v < best_var
            best_var = np.where(take, v, best_var)
            best_mean = np.where(take[..., None], m, best_mean)
    return best_mean


src, out = sys.argv[1], sys.argv[2]
rgba = np.array(Image.open(src).convert("RGBA")).astype(np.float32) / 255
rgb, alpha = rgba[..., :3], rgba[..., 3]

# Brushwork: two passes of Kuwahara (big strokes, then refinement).
painted = kuwahara(rgb, 6)
painted = kuwahara(painted, 3)

# Keep real contrast so the car reads; just soften the very darkest darks.
painted = np.clip((painted - 0.5) * 1.12 + 0.5, 0, 1)
painted = 0.10 + painted * 0.9

# Warm highlights, cool shadows: a painter's light.
lum = painted.mean(axis=2, keepdims=True)
warm, cool = np.array([1.0, 0.86, 0.74]), np.array([0.62, 0.62, 0.92])
painted = np.clip(painted * (0.75 + 0.25 * (warm * lum + cool * (1 - lum))) * 1.08, 0, 1)

# Canvas/pastel grain.
rng = np.random.default_rng(7)
h, w = alpha.shape
grain = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), 1.0)
strokes = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), sigmaX=7, sigmaY=1.0)
painted = np.clip(painted + (grain * 0.02 + strokes * 0.035)[..., None], 0, 1)

# Slightly painterly edge.
edge = cv2.GaussianBlur(rng.random((h, w)).astype(np.float32), (0, 0), 2)
soft = np.clip(cv2.GaussianBlur(alpha, (0, 0), 1.3) * (0.94 + edge * 0.12), 0, 1)
soft = np.where(alpha > 0.98, 1.0, soft)

Image.fromarray((np.dstack([painted, soft]) * 255).astype(np.uint8), "RGBA").save(out, optimize=True)
print("wrote", out)
