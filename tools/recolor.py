"""Clean up and recolor IONIQ 5 cutouts.

Source photos: Wikimedia Commons, "Hyundai IONIQ 5 Long Range Prestige NE1 PE
Atlas White Matte" by Damian B Oh, CC BY-SA 4.0. Outputs are derivatives
under the same license.

The source car is matte white, so paint = bright, unsaturated pixels. We map
their luminance onto each target paint color and leave glass, tires, trim and
lights alone.
"""
import sys

import cv2
import numpy as np
from PIL import Image

PAINTS = {
    "abyss-black": (0x16, 0x18, 0x1C),
    "atlas-white": (0xE9, 0xEA, 0xE7),
    "cyber-gray": (0x8D, 0x91, 0x96),
    "ecotronic-gray": (0x4B, 0x4F, 0x53),
    "shooting-star": (0x6F, 0x73, 0x77),
    "gravity-gold": (0x5E, 0x5A, 0x53),
    "lucid-blue": (0x58, 0x6C, 0x7E),
    "digital-teal": (0x3C, 0x54, 0x57),
    "mystic-olive": (0x5A, 0x61, 0x50),
    "ultimate-red": (0x8E, 0x1C, 0x22),
    "biophilic-blue": (0x2F, 0x4A, 0x57),
}


def load(path):
    rgba = np.array(Image.open(path).convert("RGBA")).astype(np.float32) / 255
    return rgba[..., :3], rgba[..., 3]


def inpaint(rgb, mask):
    img = (rgb * 255).astype(np.uint8)
    out = cv2.inpaint(img, mask.astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    return out.astype(np.float32) / 255


def clean_front34(rgb, alpha):
    h, w = alpha.shape
    # Show placard on the bumper: remove its dark lettering, keep a blank plate.
    face = np.zeros((h, w), bool)
    face[875:995, 3262:3585] = True
    lum = rgb.mean(axis=2)
    text = face & (lum < 0.6)
    text = cv2.dilate(text.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
    rgb = inpaint(rgb, text)
    # Charging cable and open charge-port flap at the rear: inpaint what sits on
    # the fender, cut away what sticks out past the body.
    ys, xs = np.mgrid[0:h, 0:w]
    # Approximate rear edge of the body: (160,500) -> (75,900) in full-res pixels.
    edge_x = 160 + (ys - 500) * (75 - 160) / (900 - 500)
    outside = (xs < edge_x) & (ys > 480) & (ys < 920)
    alpha = np.where(outside, 0, alpha)
    flap = (ys > 495) & (ys < 640) & (xs >= edge_x) & (xs < 240)
    rgb = inpaint(rgb, flap)
    return rgb, alpha


# Studio views: glass and wheels read as "bright, unsaturated" like the white
# paint, so they're masked out by hand. Glass is polygons in percent of the
# image; wheels and body-colored mirrors are ellipses (cx, cy, rx, ry) as
# fractions of the image. Keyed by the source file's stem.
STUDIO_MASKS = {
    "front_m": {
        "glass": [[(32.2, 20.2), (61, 19.6), (68, 24), (75.5, 33.5), (70, 34.6), (35.3, 34.8), (33, 28)],
                  [(12.2, 32.4), (12.8, 28), (14.6, 22.6), (17, 20.4), (22, 19.6), (28.4, 19.8), (28.9, 24), (29.6, 34.2), (22, 33.8)]],
        "wheels": [(0.068, 0.585, 0.038, 0.125), (0.388, 0.67, 0.065, 0.155)],
        "trim": [[(44.5, 47.5), (70, 48.5), (95.5, 46.5), (96, 52), (70, 53.5), (46, 52.5)],      # lamp band
                 [(57, 63.5), (75, 61.5), (96, 59.5), (96, 62), (75, 64), (58, 66)],              # grille surround
                 [(45, 70.5), (60, 71.5), (80, 70), (96, 67), (96, 71), (80, 74), (60, 76), (46, 74.5)],  # skid
                 [(55.5, 64), (60, 63.5), (60, 70.5), (56, 70)],                                  # chevron
                 [(30.5, 72), (31.3, 60), (32.8, 52), (34.7, 47), (37, 44.6), (39, 43.6), (40.5, 44.2),
                  (41.8, 46.5), (43, 51), (44.8, 62), (46, 72)],                                # near arch
                 [(2.3, 58), (2.8, 50), (3.8, 46), (5.5, 44.5), (7.5, 44.5), (9, 46.5), (9.8, 52), (10, 58)],      # far arch
                 [(9.5, 57), (20, 59), (30.5, 62), (30.5, 69), (20, 66), (10, 63)]],               # sill
        "keep": [(0.268, 0.335, 0.055, 0.03)],
    },
    "side": {
        "glass": [[(39.8, 40.2), (40, 36.6), (41.2, 34.8), (43, 33.4), (45.5, 32.2), (48, 31.2), (55, 30.4), (70, 30.1), (74, 31),
                   (75.5, 39.8), (55, 40.6)],
                  [(23, 42), (30, 38.8), (36, 35.9), (40.8, 33.9), (39.5, 40), (33, 40.5), (25, 41.9)]],
        "trim": [[(28, 61.2), (71.5, 60.6), (71.5, 66), (28, 66.8)],                      # silver sill
                 [(43.6, 33.2), (45.8, 31.2), (48, 30.2), (55, 29.4), (70, 29.1), (74.8, 30.3), (75.5, 31.3),
                  (75, 31.8), (74, 31.2), (70, 30.3), (55, 30.6), (48, 31.4), (45.8, 32.4), (44.2, 34)],  # window surround
                 [(37.6, 34.2), (43.6, 31.4), (48, 29.9), (48, 31.1), (43.8, 32.6), (38.2, 35.8)],
                 [(9.5, 64), (9.8, 56), (11, 52), (13.5, 49.5), (17, 48), (20, 47.8), (23.5, 48.6), (26, 50.5),
                  (27.3, 53.5), (27.8, 57), (28, 64)],                                  # front arch
                 [(73, 64), (73.6, 56), (75.5, 51.5), (78, 49), (82, 48.3), (86, 49), (89, 51.5), (90.8, 55), (91.3, 64)],
                 [(2, 56), (10, 57.5), (10, 66), (2.5, 65)],                              # front bumper lower
                 [(88.5, 57), (97.5, 55.5), (97.5, 64), (89.5, 66)]],                     # rear bumper lower
        "wheels": [(0.180, 0.615, 0.072, 0.104), (0.823, 0.618, 0.077, 0.103)],
        "keep": [(0.37, 0.395, 0.03, 0.025)],
    },
    "rear": {
        "glass": [[(10.3, 34.2), (16.5, 22.2), (21, 21.2), (47, 21.6), (53.5, 24.6), (50, 34.8)],
                  [(60.6, 21.4), (66, 20.8), (74, 22), (80, 28), (85.3, 35.5), (84, 37), (75, 36.2), (60.8, 35.2), (60.5, 30)]],
        "wheels": [(0.137, 0.755, 0.078, 0.06), (0.595, 0.685, 0.068, 0.16), (0.935, 0.59, 0.038, 0.13)],
        "trim": [[(5, 40), (48, 40.5), (49.5, 46), (6, 46)],                                     # tail bar
                 [(2.5, 56), (20, 56.5), (48, 57), (54, 60), (55, 71), (30, 72), (5, 70), (2.5, 62)],  # bumper
                 [(54.5, 72), (55, 58), (56, 52), (58, 48), (60, 46.3), (62, 45.8), (63.5, 46.3), (64.6, 48),
                  (65.5, 51), (66.2, 56), (67, 72)],                                                                     # near arch
                 [(67, 64), (72, 61), (89, 59), (90, 62), (89, 65), (72, 67), (68, 69)],           # sill
                 [(90.5, 60), (91.5, 50), (93, 45.5), (95, 42.5), (96.8, 43.5), (97.5, 47), (97.5, 60)]],  # far arch
        "keep": [(0.87, 0.345, 0.025, 0.03)],
    },
}


def studio_exclusion(view, shape):
    """1 where pixels must keep the photo's own (neutral) color: glass, wheels and trim."""
    masks = STUDIO_MASKS.get(view)
    h, w = shape
    out = np.zeros((h, w), np.float32)
    if not masks:
        return out
    for poly in masks["glass"]:
        cv2.fillPoly(out, [np.array([[x * w / 100, y * h / 100] for x, y in poly], np.int32)], 1.0)
    for poly in masks.get("trim", []):  # black/silver trim, cladding and lamps
        cv2.fillPoly(out, [np.array([[x * w / 100, y * h / 100] for x, y in poly], np.int32)], 1.0)
    for cx, cy, rx, ry in masks["wheels"]:
        cv2.ellipse(out, (int(cx * w), int(cy * h)), (int(rx * w), int(ry * h)), 0, 0, 360, 1.0, -1)
    for cx, cy, rx, ry in masks.get("keep", []):  # mirror caps are body color
        cv2.ellipse(out, (int(cx * w), int(cy * h)), (int(rx * w), int(ry * h)), 0, 0, 360, 0.0, -1)
    return cv2.GaussianBlur(out, (0, 0), 2)


def recolor(rgb, alpha, target, white_point=0.86, glass=True, exclude=None):
    hsv = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    sat = hsv[..., 1] / 255
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    # Paint: unsaturated and bright-ish. Very bright pixels are lamps.
    paint = np.clip((0.22 - sat) / 0.1, 0, 1) * np.clip((lum - 0.38) / 0.12, 0, 1)
    if exclude is None:
        # Very bright pixels are lamps. Studio views mask their lamps by hand,
        # so there the brightest highlights on the body still get painted.
        paint *= np.clip((0.985 - lum) / 0.03, 0, 1)
    paint = cv2.GaussianBlur(paint, (0, 0), 1.2)
    if exclude is not None:
        paint *= 1 - exclude

    target = np.array(target, np.float32) / 255
    shade = np.clip(lum / white_point, 0, 1.25)
    # Keep highlights alive on dark paints so the shape still reads.
    highlight = np.clip(shade - 0.95, 0, 1)[..., None] * (0.6 if exclude is None else 0.35)
    painted = target[None, None, :] * (shade[..., None] ** 1.15) + highlight
    # Neutralize the show lighting (purple glass, bronze wheels) on everything
    # that isn't paint or a lamp.
    gray = lum[..., None].repeat(3, axis=2)
    lamp = np.clip((lum - 0.9) / 0.08, 0, 1)[..., None] * (1 if exclude is None else 0)
    neutral = rgb * 0.15 + gray * 0.85
    base = neutral * (1 - lamp) + rgb * lamp
    out = base * (1 - paint[..., None]) + np.clip(painted, 0, 1) * paint[..., None]
    if glass:
        out = tint_glass(out, alpha, paint)
    return out, alpha


# Greenhouse region in percent of the car's bounding box. Generous on purpose:
# only non-paint pixels inside it are tinted, so the glass edges come from the
# photo itself and the body-colored A-pillar stays painted.
GREENHOUSE = [(9.3, 27.8), (9.8, 12), (13, 7.2), (18, 5.4), (26, 4.2), (33.5, 1.4), (46, 1.2),
              (56, 3.2), (63, 7), (69, 13.5), (73, 21), (76, 28), (45, 28.2)]


def tint_glass(rgb, alpha, paint):
    ys, xs = np.where(alpha > 8 / 255)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    w, h = x1 - x0, y1 - y0
    pts = np.array([[x0 + x * w / 100, y0 + y * h / 100] for x, y in GREENHOUSE], np.int32)
    region = np.zeros(alpha.shape, np.uint8)
    cv2.fillPoly(region, [pts], 1)
    region = cv2.GaussianBlur(region.astype(np.float32), (0, 0), 2)
    # Glass = inside the greenhouse and not paint. Grow the not-paint area a
    # touch so the tint meets the window seals without a gray halo.
    # Bright interior reflections look like paint to the color test; real paint
    # inside the greenhouse (the A-pillar) is one big piece connected to the
    # body, so drop small isolated paint blobs.
    solid = (paint > 0.5).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
    big = np.zeros(count, bool)
    big[1:] = stats[1:, cv2.CC_STAT_AREA] > alpha.size * 0.004
    body_paint = np.where(big[labels], paint, 0).astype(np.float32)
    not_paint = cv2.erode(1 - body_paint, np.ones((3, 3), np.uint8))
    glass = np.clip(region * not_paint, 0, 1)[..., None]
    lum = rgb.mean(axis=2, keepdims=True)
    yy = ((np.arange(rgb.shape[0]) - y0) / h)[:, None, None]
    reflection = np.clip(0.12 - yy * 0.35, 0, 0.12)
    smoked = np.clip(lum * 0.12 + reflection + np.array([0.03, 0.032, 0.04]), 0, 1)
    return rgb * (1 - glass) + smoked * glass


def repair_alpha(alpha, lum):
    """White pillars against the white studio wall come out of the cutout
    half-transparent. Anything near the car's top half that isn't wall white
    in the photo is car, so make it opaque."""
    car = (alpha > 0.5).astype(np.uint8)
    near = cv2.dilate(car, np.ones((15, 15), np.uint8)).astype(bool)
    ys = np.where(car)[0]
    upper = np.arange(alpha.shape[0])[:, None] < ys.min() + (ys.max() - ys.min()) * 0.5
    solid = np.clip((0.975 - lum) / 0.04, 0, 1) * near * upper
    return np.maximum(alpha, cv2.GaussianBlur(solid.astype(np.float32), (0, 0), 0.7))


def save(rgb, alpha, path, width=None):
    rgba = np.dstack([rgb, alpha])
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    img = img.crop(bbox)
    if width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    img.save(path, optimize=True)


if __name__ == "__main__":
    # python recolor.py <cutout.png> <outdir> [--rear|--studio --prefix=car-front] [--source=<photo>]
    #   default:  the front three-quarter showroom photo (cleanup + glass tint)
    #   --studio: a studio render on white (already clean, dark glass); --rear is
    #             the same with prefix car-rear. --source recovers its ground shadow.
    src, outdir = sys.argv[1], sys.argv[2]
    rear = "--rear" in sys.argv or "--studio" in sys.argv
    custom_prefix = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--prefix=")), None)
    rgb, alpha = load(src)
    if rear:
        prefix, width, white = custom_prefix or "car-rear", 1200, 0.80
        # Recover the studio ground shadow: the source sits on pure white, so
        # anything darker outside the car is shadow. Needs a --full cutout and
        # the original photo (passed as --source=<path>).
        source = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--source=")), None)
        if source:
            photo = np.array(Image.open(source).convert("RGB")).astype(np.float32) / 255
            lum = photo.mean(axis=2)
            filled = repair_alpha(alpha, lum)
            # The cutout blanked those pixels, so take their color from the photo.
            rgb = np.where((filled - alpha)[..., None] > 0.02, photo, rgb)
            alpha = filled
            car = alpha > 0.5
            ys = np.where(alpha > 0.5)[0]
            below_top = np.arange(alpha.shape[0])[:, None] > (ys.min() + (ys.max() - ys.min()) * 0.55)
            shadow = np.clip((0.985 - lum) / 0.55, 0, 1) * (~car) * below_top
            shadow = cv2.GaussianBlur(shadow, (0, 0), 1.0)
            rgb = rgb * alpha[..., None]                      # shadow pixels go black
            # Shadow fills right up to the car's edge so no halo shows between them.
            alpha = np.maximum(alpha, shadow * 0.9 * (1 - alpha))
            alpha = np.clip(alpha + shadow * 0.9 * (alpha < 0.5) * 0, 0, 1)
        # Studio render is small; upscale before recoloring and sharpen a touch.
        img = Image.fromarray((np.dstack([rgb, alpha]) * 255).astype(np.uint8), "RGBA")
        img = img.resize((img.width * 2, img.height * 2), Image.LANCZOS)
        arr = np.array(img).astype(np.float32) / 255
        blur = cv2.GaussianBlur(arr[..., :3], (0, 0), 1.4)
        rgb = np.clip(arr[..., :3] * 1.5 - blur * 0.5, 0, 1)
        alpha = arr[..., 3]
        import os
        view = os.path.basename(src).replace("_full.png", "").replace(".png", "")
        exclude = studio_exclusion(view, alpha.shape)
    else:
        prefix, width, white = "car", 1400, 0.86
        exclude = None
        rgb, alpha = clean_front34(rgb, alpha)
        save(rgb, alpha, f"{outdir}/clean.png", width)
    for name, color in PAINTS.items():
        r, a = recolor(rgb, alpha, color, white_point=white, glass=not rear, exclude=exclude)
        save(r, a, f"{outdir}/{prefix}-{name}.png", width)
        print("wrote", prefix, name)
