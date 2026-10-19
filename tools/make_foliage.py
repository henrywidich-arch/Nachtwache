#!/usr/bin/env python3
"""Builds the textures of the farm's ground cover (mission 1) into assets/foliage/.

    python3 tools/make_foliage.py [--preview=<png>]

Everything starts from the Poly Haven plants in assets/models/polyhaven (CC0):
- <plant>_cutout_1k.png next to each plant's textures: its colour with the cut-out of
  its leaves in the alpha channel. Poly Haven's glTF files carry the cut-out as a separate
  picture that Godot does not read; the colour runs on into the cut-away parts, so that
  their edges do not darken from afar.
- grass_cards.png: four columns of 512 x 1024, each a card of grass blades cut from
  grass_medium_02 (lush, mixed, tall with seed heads, dry). CabinMap._build_grass crosses
  such cards into clumps.
- leaf_litter.png: four squares of 512 (2 x 2) of fallen, browned leaves and twigs for
  the ground under the trees, cut from shrub_02 and shrub_03.
Needs numpy, scipy and Pillow. The output is deterministic.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HAVEN = os.path.join(ROOT, "assets", "models", "polyhaven")
OUT = os.path.join(ROOT, "assets", "foliage")
PLANTS = ["fern_02", "weed_plant_02", "shrub_02", "shrub_03", "shrub_sorrel_01",
          "celandine_01", "dandelion_01"]


def load_plant(name):
    folder = os.path.join(HAVEN, name, "textures")
    rgb = np.asarray(Image.open(os.path.join(folder, f"{name}_diff_1k.jpg")).convert("RGB"), dtype=np.float32) / 255.0
    alpha = np.asarray(Image.open(os.path.join(folder, f"{name}_alpha_1k.png")).convert("L"), dtype=np.float32) / 255.0
    return rgb, alpha


def bleed(rgb, alpha):
    """Colour of the nearest leaf in the cut-away parts, blurred a little."""
    solid = alpha > 0.5
    if not solid.any():
        return rgb
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    out = rgb[iy, ix]
    soft = np.stack([ndimage.gaussian_filter(out[..., c], 3.0) for c in range(3)], -1)
    return np.where(solid[..., None], rgb, soft)


def save_rgba(path, rgb, alpha):
    data = np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    Image.fromarray((data * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)


def islands(rgb, alpha, min_pixels):
    """Every separate piece of the cut-out: [rgb, alpha] cropped to it."""
    labels, count = ndimage.label(alpha > 0.5)
    pieces = []
    for index, box in enumerate(ndimage.find_objects(labels)):
        own = labels[box] == index + 1
        if own.sum() < min_pixels:
            continue
        # A little of the soft edge around the piece belongs to it.
        grown = ndimage.binary_dilation(own, iterations=2)
        pieces.append([rgb[box].copy(), alpha[box] * grown])
    return pieces


def to_image(rgb, alpha):
    data = np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    return Image.fromarray((data * 255.0).astype(np.uint8), "RGBA")


def paste(canvas, piece, x, y):
    """Lays an RGBA float piece over the canvas (premultiplied over), x/y its top left."""
    h, w = piece.shape[:2]
    H, W = canvas.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    part = piece[y0 - y:y1 - y, x0 - x:x1 - x]
    a = part[..., 3:4]
    below = canvas[y0:y1, x0:x1]
    out_a = a + below[..., 3:4] * (1.0 - a)
    out_rgb = (part[..., :3] * a + below[..., :3] * below[..., 3:4] * (1.0 - a)) / np.maximum(out_a, 1e-5)
    canvas[y0:y1, x0:x1] = np.concatenate([out_rgb, out_a], -1)


def blade_image(piece, height, width_scale, lean_deg, shade):
    """A blade standing on its root (the bottom of the piece), so tall, leaning."""
    rgb, alpha = piece
    image = to_image(rgb * shade, alpha)
    h, w = rgb.shape[:2]
    scale = height / h
    image = image.resize((max(2, int(w * scale * width_scale)), max(2, int(height))), Image.LANCZOS)
    # Turned about the middle of its foot, which ends up at the bottom middle of the result.
    big = Image.new("RGBA", (image.width * 2 + 2 * int(height), image.height * 2), (0, 0, 0, 0))
    big.paste(image, (big.width // 2 - image.width // 2, big.height // 2 - image.height))
    big = big.rotate(lean_deg, resample=Image.BICUBIC, center=(big.width / 2, big.height / 2))
    box = big.getbbox()
    data = np.asarray(big, dtype=np.float32) / 255.0
    return data, (big.width // 2, big.height // 2), box


def grass_card(rng, blades, dry_blades, kind, size=(512, 1024)):
    W, H = size
    canvas = np.zeros((H, W, 4), dtype=np.float32)
    plan = {
        # count, shortest and tallest blade (share of the card), share of dry ones, spread
        "lush": (64, 0.3, 0.9, 0.05, 0.22),
        "mixed": (58, 0.28, 0.94, 0.3, 0.24),
        "tall": (50, 0.45, 0.97, 0.22, 0.2),
        "dry": (52, 0.28, 0.9, 0.85, 0.26),
    }[kind]
    count, low, high, dry_share, spread = plan
    for i in range(count):
        dry = rng.random() < dry_share
        piece = dry_blades[rng.integers(len(dry_blades))] if dry else blades[rng.integers(len(blades))]
        # The ones at the back first, a little darker; the front ones stand in the light.
        depth = i / max(1, count - 1)
        height = H * rng.uniform(low, high) * (0.75 + 0.25 * depth)
        foot = rng.normal(0.0, spread * 0.5)
        lean = float(np.clip(-foot * 80.0 + rng.normal(0.0, 8.0), -20.0, 20.0))
        shade = (0.62 + 0.38 * depth) * rng.uniform(0.9, 1.08)
        width = rng.uniform(0.24, 0.42) * (0.85 if kind == "tall" else 1.0)
        data, (cx, cy), box = blade_image(piece, height, width, lean, shade)
        if box is None:
            continue
        x = int(W * (0.5 + foot)) - cx
        y = H - 2 - cy
        paste(canvas, data, x, y)
    if kind == "tall":
        # Seed heads on thin stalks over the blades.
        for i in range(7):
            foot = rng.normal(0.0, 0.1)
            top = rng.uniform(0.02, 0.2)
            draw_seed_stalk(canvas, rng, W * (0.5 + foot), H - 2, W * (0.5 + foot * 1.8 + rng.normal(0, 0.05)), H * top)
    return canvas


def draw_seed_stalk(canvas, rng, x0, y0, x1, y1):
    H, W = canvas.shape[:2]
    steps = int(abs(y0 - y1))
    straw = np.array([0.62, 0.58, 0.4]) * rng.uniform(0.75, 1.0)
    for s in range(steps):
        t = s / steps
        bend = np.sin(t * np.pi) * rng.uniform(-1.5, 1.5)
        x = x0 + (x1 - x0) * t * t + bend
        y = y0 + (y1 - y0) * t
        r = 1.6 - t * 0.6
        stamp(canvas, x, y, r, straw * (0.7 + 0.3 * t), 1.0)
    # The head: a narrow ear of spikelets along the last part of the stalk.
    length = abs(y0 - y1) * rng.uniform(0.14, 0.22)
    for k in range(26):
        t = k / 25.0
        x = x1 + rng.normal(0, 1.2)
        y = y1 + length * t
        side = (1 if k % 2 == 0 else -1) * rng.uniform(2.0, 5.0) * (1.0 - t * 0.4)
        stamp(canvas, x + side, y, rng.uniform(2.0, 3.4), straw * rng.uniform(0.75, 1.1), 1.0, stretch=2.4)


def stamp(canvas, x, y, r, colour, opacity, stretch=1.0):
    H, W = canvas.shape[:2]
    ry = r * stretch
    xs = slice(max(0, int(x - r - 2)), min(W, int(x + r + 3)))
    ys = slice(max(0, int(y - ry - 2)), min(H, int(y + ry + 3)))
    if xs.stop <= xs.start or ys.stop <= ys.start:
        return
    gy, gx = np.mgrid[ys, xs]
    d = np.sqrt(((gx - x) / r) ** 2 + ((gy - y) / ry) ** 2)
    a = np.clip((1.0 - d) * 2.5, 0, 1)[..., None] * opacity
    region = canvas[ys, xs]
    out_a = a + region[..., 3:4] * (1 - a)
    rgb = (colour[None, None, :] * a + region[..., :3] * region[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-5)
    canvas[ys, xs] = np.concatenate([rgb, out_a], -1)


DEAD = [np.array(c) / 255.0 for c in [(92, 62, 34), (120, 82, 40), (70, 50, 32), (138, 104, 56), (84, 70, 44), (58, 40, 26)]]


def dead_leaf(rng, piece, size):
    rgb, alpha = piece
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.55 + rgb[..., 2] * 0.15
    detail = lum / max(lum[alpha > 0.5].mean(), 1e-3) if (alpha > 0.5).any() else lum
    base = DEAD[rng.integers(len(DEAD))] * rng.uniform(0.8, 1.15)
    # Some leaves still keep a little of their green or are almost black from the rain.
    if rng.random() < 0.15:
        base = base * 0.45 + np.array([0.22, 0.24, 0.12]) * 0.55
    if rng.random() < 0.2:
        base = base * 0.5
    tinted = np.clip(detail[..., None] * base[None, None, :], 0, 1)
    image = to_image(tinted, alpha)
    h, w = rgb.shape[:2]
    scale = size / max(h, w)
    image = image.resize((max(2, int(w * scale)), max(2, int(h * scale))), Image.LANCZOS)
    image = image.rotate(rng.uniform(0, 360), resample=Image.BICUBIC, expand=True)
    return np.asarray(image, dtype=np.float32) / 255.0


def litter_tile(rng, leaves, size=512, count=70):
    canvas = np.zeros((size, size, 4), dtype=np.float32)
    # Twigs and pine needles first, the leaves over them.
    for i in range(18):
        x0, y0 = rng.uniform(40, size - 40, 2)
        turn = rng.uniform(0, np.pi)
        length = rng.uniform(25, 120) if i < 6 else rng.uniform(14, 34)
        colour = np.array([0.24, 0.17, 0.11]) * rng.uniform(0.6, 1.2)
        steps = int(length)
        for s in range(steps):
            t = s / max(1, steps)
            x = x0 + np.cos(turn) * length * (t - 0.5)
            y = y0 + np.sin(turn) * length * (t - 0.5)
            stamp(canvas, x, y, (2.6 if i < 6 else 1.1) * (1.0 - 0.4 * t), colour, 1.0)
    for i in range(count):
        # Fewer towards the edge of the square, so that its patches have no corners.
        r = np.sqrt(rng.random()) * size * 0.42
        a = rng.uniform(0, 2 * np.pi)
        x, y = size / 2 + np.cos(a) * r, size / 2 + np.sin(a) * r
        leaf = dead_leaf(rng, leaves[rng.integers(len(leaves))], rng.uniform(34, 76))
        h, w = leaf.shape[:2]
        paste(canvas, leaf, int(x - w / 2), int(y - h / 2))
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    preview = None
    for arg in sys.argv[1:]:
        if arg.startswith("--preview="):
            preview = arg.split("=", 1)[1]
    for name in PLANTS:
        rgb, alpha = load_plant(name)
        save_rgba(os.path.join(HAVEN, name, "textures", f"{name}_cutout_1k.png"), bleed(rgb, alpha), alpha)
    rgb, alpha = load_plant("grass_medium_02")
    pieces = islands(rgb, alpha, 2500)
    # Blades stand upright on the sheet; the one lying across it is left out.
    upright = [p for p in pieces if p[0].shape[0] > p[0].shape[1] * 3 and p[0].shape[0] > 400]
    green, dry = [], []
    for piece in upright:
        mask = piece[1] > 0.5
        colour = piece[0][mask].mean(0)
        (dry if colour[0] > colour[1] * 1.06 else green).append(piece)
    # Dead blades are bleached and browned copies of the green ones besides the dry ones.
    for piece in list(green):
        lum = (piece[0] @ np.array([0.3, 0.55, 0.15]))[..., None]
        dry.append([np.clip(lum * np.array([1.18, 1.0, 0.68]) * 1.05, 0, 1), piece[1]])
    rng = np.random.default_rng(1907)
    cards = [grass_card(rng, green, dry or green, kind) for kind in ["lush", "mixed", "tall", "dry"]]
    sheet = np.concatenate(cards, 1)
    save_rgba(os.path.join(OUT, "grass_cards.png"), bleed(sheet[..., :3], sheet[..., 3]), sheet[..., 3])
    leaves = []
    for name, ids in [("shrub_03", None), ("shrub_02", None)]:
        rgb, alpha = load_plant(name)
        for piece in islands(rgb, alpha, 3000):
            h, w = piece[0].shape[:2]
            # Leaves, not the stems and sprigs (long and thin) or the sheets of many leaves.
            if max(h, w) < 380 and min(h, w) > 30 and max(h, w) / min(h, w) < 4.5:
                leaves.append(piece)
    tiles = [litter_tile(rng, leaves) for _ in range(4)]
    litter = np.concatenate([np.concatenate(tiles[:2], 1), np.concatenate(tiles[2:], 1)], 0)
    save_rgba(os.path.join(OUT, "leaf_litter.png"), bleed(litter[..., :3], litter[..., 3]), litter[..., 3])
    print("grass blades:", len(green), "green,", len(dry), "dry; litter leaves:", len(leaves))
    if preview:
        shown = []
        for path in [os.path.join(OUT, "grass_cards.png"), os.path.join(OUT, "leaf_litter.png")]:
            image = Image.open(path).convert("RGBA")
            back = Image.new("RGBA", image.size, (24, 28, 40, 255))
            back.alpha_composite(image)
            shown.append(back.convert("RGB").resize((image.width // 2, image.height // 2)))
        out = Image.new("RGB", (shown[0].width + shown[1].width, max(s.height for s in shown)))
        out.paste(shown[0], (0, 0))
        out.paste(shown[1], (shown[0].width, 0))
        out.save(preview)


if __name__ == "__main__":
    main()
