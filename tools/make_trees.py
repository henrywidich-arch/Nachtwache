#!/usr/bin/env python3
"""Builds the trees of the forest (mission 1 and 2) into assets/models/forest/.

    python3 tools/make_trees.py <folder with the Poly Haven textures> [--only=Fir_1,...]

Poly Haven's own trees (fir_tree_01, pine_tree_01, ...) are scans of millions of
triangles, so these are built from their textures instead: firs and pines out of cards of
the real twigs, broad-leaf trees out of single leaves, dead trees out of bare branches,
every trunk wearing a bark of Poly Haven. All CC0 (see assets/models/forest/LIZENZ_*.txt).

The folder holds <asset>/<texture>.jpg|png as tools/fetch_tex.py saved them (fir_tree_01,
pine_tree_01, island_tree_02, tree_small_02, dead_tree_trunk_02). Output per tree is a
glTF (positions, normals, uvs, vertex colours that darken the inside of a crown) with a
bark material and a cut-out material for needles and leaves, plus shared textures. Needs
numpy, scipy and Pillow. Deterministic.
"""
import base64
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "models", "forest")
TEX = os.path.join(OUT, "textures")

# ---------------------------------------------------------------- textures

# Where the usable pieces lie on the twig and leaf sheets of Poly Haven (x0, y0, x1, y1 in
# pixels of the 1024 sheet): sprays with their foot at the bottom, single leaves.
FIR_SPRAYS = [(190, 40, 440, 325), (660, 35, 960, 380), (320, 410, 655, 800), (650, 465, 975, 850), (510, 262, 640, 410)]
PINE_SPRAYS = [(25, 40, 235, 460)]
LEAVES = [(16, 20, 149, 410), (169, 20, 346, 402), (369, 31, 495, 372), (710, 20, 836, 424), (222, 590, 364, 1010), (432, 617, 575, 1000), (17, 644, 187, 990)]


def bleed(rgb, alpha):
    solid = alpha > 0.5
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    out = rgb[iy, ix]
    soft = np.stack([ndimage.gaussian_filter(out[..., c], 2.0) for c in range(3)], -1)
    return np.where(solid[..., None], rgb, soft)


def cut_sheet(folder, asset, diffuse, alpha, rects, name, darken=(1.0, 1.0, 1.0), mask=None):
    """The sheet with everything but the chosen pieces cut away."""
    rgb = np.asarray(Image.open(os.path.join(folder, asset, diffuse)).convert("RGB"), dtype=np.float32) / 255.0
    a = np.asarray(Image.open(os.path.join(folder, asset, alpha)).convert("L"), dtype=np.float32) / 255.0
    keep = np.zeros_like(a)
    for x0, y0, x1, y1 in rects:
        keep[y0:y1, x0:x1] = 1.0
    a = a * keep
    if mask:
        # The sheet's own mask of where the spray is (it has gaps along the stem): closed up,
        # it cuts the bark that lies next to the spray out of the picture.
        m = np.asarray(Image.open(os.path.join(folder, asset, mask)).convert("L"), dtype=np.float32) > 128
        m = ndimage.binary_closing(ndimage.binary_dilation(m, iterations=3), iterations=8)
        a = a * m
    rgb = bleed(rgb, a)
    data = np.concatenate([np.clip(rgb * np.array(darken, dtype=np.float32), 0, 1), a[..., None]], -1)
    Image.fromarray((data * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(TEX, name), optimize=True)


def bark_tile(folder, asset, diffuse, normal, crop, name, size=1024):
    """A bark that tiles: the cut mirrored over both axes (the normal map's slopes with it)."""
    d = np.asarray(Image.open(os.path.join(folder, asset, diffuse)).convert("RGB"), dtype=np.float32) / 255.0
    n = np.asarray(Image.open(os.path.join(folder, asset, normal)).convert("RGB"), dtype=np.float32) / 255.0
    if crop:
        x0, y0, x1, y1 = crop
        d, n = d[y0:y1, x0:x1], n[y0:y1, x0:x1]

    def mirror(img, normal_map):
        right = img[:, ::-1].copy()
        if normal_map:
            right[..., 0] = 1.0 - right[..., 0]
        top = np.concatenate([img, right], 1)
        bottom = top[::-1].copy()
        if normal_map:
            bottom[..., 1] = 1.0 - bottom[..., 1]
        return np.concatenate([top, bottom], 0)

    for img, normal_map, suffix in [(d, False, "_diff.png"), (n, True, "_nor.png")]:
        tile = mirror(img, normal_map)
        pic = Image.fromarray((np.clip(tile, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").resize((size, size), Image.LANCZOS)
        pic.save(os.path.join(TEX, name + suffix), optimize=True)


def build_textures(folder):
    os.makedirs(TEX, exist_ok=True)
    cut_sheet(folder, "fir_tree_01", "twig_diff.jpg", "twig_alpha.png", FIR_SPRAYS, "fir_needles.png")
    cut_sheet(folder, "pine_tree_01", "twig_diff.jpg", "twig_alpha.png", PINE_SPRAYS, "pine_needles.png", darken=(0.72, 0.9, 0.72), mask="twig_mask.png")
    cut_sheet(folder, "island_tree_02", "leaves_diff.jpg", "leaves_alpha.png", LEAVES, "leaves.png")
    bark_tile(folder, "fir_tree_01", "trunk_c_diff.jpg", "trunk_c_nor_gl.jpg", (10, 580, 350, 1010), "bark_fir")
    bark_tile(folder, "pine_tree_01", "trunk_a_diff.jpg", "trunk_a_nor_gl.jpg", (10, 580, 340, 1010), "bark_pine")
    bark_tile(folder, "tree_small_02", "Diffuse.jpg", "nor_gl.jpg", None, "bark_birch")
    bark_tile(folder, "dead_tree_trunk_02", "Diffuse.jpg", "nor_gl.jpg", None, "bark_dead")


# ---------------------------------------------------------------- geometry

def unit(v):
    v = np.asarray(v, dtype=np.float64)
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else np.array([0.0, 1.0, 0.0])


def rotate(v, axis, angle):
    axis = unit(axis)
    c, s = math.cos(angle), math.sin(angle)
    return v * c + np.cross(axis, v) * s + axis * np.dot(axis, v) * (1 - c)


class Part:
    """One primitive: positions, normals, uvs, colours, triangles."""

    def __init__(self):
        self.p, self.n, self.uv, self.c, self.i = [], [], [], [], []

    def vertex(self, p, n, uv, c):
        self.p.append(p)
        self.n.append(unit(n))
        self.uv.append(uv)
        self.c.append(c)
        return len(self.p) - 1

    def tri(self, a, b, c):
        self.i += [a, b, c]


def tube(part, pts, radii, sides, tile, shade=1.0, tint=(1.0, 1.0, 1.0), cap_top=False):
    """A tapering tube along the polyline `pts`: bark on `tile` (metres across, along)."""
    pts = [np.asarray(p, dtype=np.float64) for p in pts]
    count = len(pts)
    tangents = []
    for k in range(count):
        a = pts[max(k - 1, 0)]
        b = pts[min(k + 1, count - 1)]
        tangents.append(unit(b - a))
    side = unit(np.cross(tangents[0], [0.31, 0.0, 0.95]))
    ring_first = len(part.p)
    along = 0.0
    wraps = max(1, int(round(2 * math.pi * max(radii[0], 0.03) / tile[0])))
    for k in range(count):
        if k > 0:
            along += float(np.linalg.norm(pts[k] - pts[k - 1]))
            side = unit(side - tangents[k] * np.dot(side, tangents[k]))
        other = np.cross(tangents[k], side)
        for j in range(sides + 1):
            a = 2 * math.pi * j / sides
            radial = side * math.cos(a) + other * math.sin(a)
            part.vertex(pts[k] + radial * radii[k], radial, (wraps * j / sides, along / tile[1]), (shade * tint[0], shade * tint[1], shade * tint[2], 1.0))
    for k in range(count - 1):
        for j in range(sides):
            a = ring_first + k * (sides + 1) + j
            b = a + 1
            c = a + sides + 1
            d = c + 1
            part.tri(a, c, b)
            part.tri(b, c, d)
    if cap_top:
        tip = part.vertex(pts[-1] + tangents[-1] * radii[-1] * 0.5, tangents[-1], (0.5, along / tile[1]), (shade, shade, shade, 1.0))
        base = ring_first + (count - 1) * (sides + 1)
        for j in range(sides):
            part.tri(base + j, tip, base + j + 1)


def card(part, base, axis, side, length, width, rect, normal, shade, tint=(1.0, 1.0, 1.0), sheet=1024.0, flip=False):
    """A flat piece of a texture: foot of the cut-out at `base`, running along `axis`,
    `width` across."""
    x0, y0, x1, y1 = rect
    u0, u1 = x0 / sheet, x1 / sheet
    v0, v1 = y0 / sheet, y1 / sheet
    if flip:
        u0, u1 = u1, u0
    half = side * width * 0.5
    tip = base + axis * length
    col = (shade * tint[0], shade * tint[1], shade * tint[2], 1.0)
    a = part.vertex(base - half, normal, (u0, v1), col)
    b = part.vertex(base + half, normal, (u1, v1), col)
    c = part.vertex(tip - half, normal, (u0, v0), col)
    d = part.vertex(tip + half, normal, (u1, v0), col)
    part.tri(a, b, c)
    part.tri(b, d, c)


def crown_normal(point, axis_x, axis_z, up=0.7, out=0.55):
    radial = np.array([point[0] - axis_x, 0.0, point[2] - axis_z])
    if np.linalg.norm(radial) < 1e-6:
        radial = np.array([1.0, 0.0, 0.0])
    return unit(np.array([0.0, up, 0.0]) + unit(radial) * out)


def rect_aspect(rect):
    return (rect[2] - rect[0]) / (rect[3] - rect[1])


# ---------------------------------------------------------------- the species

def trunk_path(rng, height, lean, steps=14, wobble=0.12):
    """Centre line of a trunk: leaning, with a slow bend."""
    phase = rng.uniform(0, math.tau)
    tilt = rng.uniform(0, math.tau)
    pts = []
    for k in range(steps + 1):
        t = k / steps
        bend = lean * t * t + wobble * math.sin(t * 3.1 + phase) * t
        pts.append(np.array([math.cos(tilt) * bend, height * t, math.sin(tilt) * bend]))
    return pts


def at_height(pts, height_fraction):
    t = height_fraction * (len(pts) - 1)
    k = min(int(t), len(pts) - 2)
    f = t - k
    return pts[k] * (1 - f) + pts[k + 1] * f, unit(pts[k + 1] - pts[k])


def build_fir(rng, height, narrow, dead_foot):
    bark, needles = Part(), Part()
    r0 = 0.32 * height / 14.0
    pts = trunk_path(rng, height, rng.uniform(-0.5, 0.5) * height / 14.0, 16, 0.1)
    radii = []
    for k, p in enumerate(pts):
        t = k / (len(pts) - 1)
        radii.append(r0 * (1 - t) ** 0.8 * (1.0 + 0.9 * math.exp(-t * height / 0.7)) + 0.012)
    tube(bark, pts, radii, 10, (1.8, 3.0), 1.0)
    crown_start = 0.15 + (0.22 if dead_foot else 0.0)
    spacing = (0.4 + 0.1 * rng.random()) * height / 14.0
    l_max = (0.2 - 0.04 * narrow) * height
    h = crown_start * height
    while h < height * 0.985:
        t = (h / height - crown_start) / (1 - crown_start)
        centre, tangent = at_height(pts, h / height)
        count = 8 if t < 0.55 else (7 if t < 0.8 else 5)
        yaw0 = rng.uniform(0, math.tau)
        for b in range(count):
            yaw = yaw0 + math.tau * b / count + rng.uniform(-0.25, 0.25)
            length = l_max * (1 - t) ** 0.85 * rng.uniform(0.8, 1.15) + 0.35
            if t > 0.93:
                length *= 0.8
            flat = np.array([math.cos(yaw), 0.0, math.sin(yaw)])
            pitch = math.radians(-22 + 38 * t + rng.uniform(-8, 8))
            segments = max(2, int(round(length / 0.85)))
            point = centre + flat * r0 * 0.4 * (1 - t)
            direction = unit(flat * math.cos(pitch) + np.array([0, math.sin(pitch), 0]))
            for sgm in range(segments):
                seg_len = length / segments
                # The branch curls up towards its tip.
                direction = unit(direction + np.array([0, 0.12 + 0.22 * t, 0]) * (sgm / segments))
                side = unit(np.cross(direction, [0, 1, 0]))
                for roll in (-40, 0, 40):
                    s2 = rotate(side, direction, math.radians(roll + rng.uniform(-8, 8)))
                    rect = FIR_SPRAYS[rng.integers(len(FIR_SPRAYS))]
                    scale = rng.uniform(1.2, 1.55)
                    ln = seg_len * scale * 1.3
                    wd = ln * rect_aspect(rect) * 1.15
                    mid = point + direction * seg_len * 0.5
                    normal = crown_normal(mid, pts[0][0], pts[0][2])
                    shade = (0.4 + 0.6 * ((sgm + 0.5) / segments)) * rng.uniform(0.85, 1.0)
                    if t < 0.06 and dead_foot:
                        shade *= 0.7
                    card(needles, point, direction, s2, ln, wd, rect, normal, shade, flip=rng.random() < 0.5)
                point = point + direction * seg_len
            # A last spray pointing straight on, at the tip.
            rect = FIR_SPRAYS[rng.integers(len(FIR_SPRAYS))]
            side = unit(np.cross(direction, [0, 1, 0]))
            normal = crown_normal(point, pts[0][0], pts[0][2])
            ln = 0.9 * (1 - 0.5 * t)
            card(needles, point - direction * 0.1, direction, side, ln, ln * rect_aspect(rect), rect, normal, 1.0)
        h += spacing * (1 - 0.3 * t)
    # The leader.
    top, tangent = at_height(pts, 1.0)
    for k in range(2):
        rect = FIR_SPRAYS[0]
        side = rotate(np.array([1.0, 0, 0]), [0, 1, 0], math.pi * k / 2)
        card(needles, top - np.array([0, 0.5, 0]), np.array([0, 1.0, 0]), side, 1.8, 1.8 * rect_aspect(rect), rect, [0, 1, 0.2], 1.0)
    return bark, needles


def wood(part, start, direction, length, r0, r1, sides, tile, rng, shade=1.0, bend=0.0, steps=4):
    """A bare limb; returns its points."""
    pts = [np.asarray(start, dtype=np.float64)]
    d = unit(direction)
    for k in range(steps):
        d = unit(d + np.array([rng.normal(0, bend), rng.normal(0, bend) * 0.6, rng.normal(0, bend)]))
        pts.append(pts[-1] + d * (length / steps))
    radii = [r0 + (r1 - r0) * (k / steps) for k in range(steps + 1)]
    tube(part, pts, radii, sides, tile, shade)
    return pts, d


def build_pine(rng, height, crooked):
    bark, needles = Part(), Part()
    r0 = 0.3 * height / 14.0
    pts = trunk_path(rng, height, rng.uniform(-1, 1) * (1.2 if crooked else 0.5) * height / 14.0, 18, 0.35 if crooked else 0.18)
    radii = []
    for k in range(len(pts)):
        t = k / (len(pts) - 1)
        radii.append(r0 * (1 - 0.82 * t) * (1.0 + 0.8 * math.exp(-t * height / 0.8)) + 0.02)
    tube(bark, pts, radii, 10, (1.6, 2.4), 1.0)
    crown = 0.5 if not crooked else 0.42
    branches = 24 if not crooked else 20
    for b in range(branches):
        t = rng.uniform(crown, 0.98)
        centre, tangent = at_height(pts, t)
        yaw = rng.uniform(0, math.tau)
        flat = np.array([math.cos(yaw), 0.0, math.sin(yaw)])
        up_ward = 0.25 + 0.9 * (t - crown) / (1 - crown) + rng.uniform(-0.1, 0.2)
        length = (3.6 - 2.4 * (t - crown) / (1 - crown)) * height / 14.0 * rng.uniform(0.7, 1.2)
        direction = unit(flat + np.array([0, up_ward * 0.7, 0]))
        limb, last = wood(bark, centre, direction, length, 0.09 * height / 14.0, 0.022, 5, (0.5, 1.0), rng, 1.0, 0.12)
        tufts = rng.integers(5, 8)
        for k in range(tufts):
            f = 0.4 + 0.6 * k / max(1, tufts - 1)
            idx = min(int(f * (len(limb) - 1)), len(limb) - 1)
            spot = limb[idx] + np.array([0, 0.15, 0])
            size = rng.uniform(1.2, 1.7) * (1.0 if k == tufts - 1 else 0.85)
            # A pom-pom of long needles: sprays running out from its middle in every
            # direction but down.
            for c in range(6):
                out_dir = unit(np.array([rng.normal(), abs(rng.normal()) * 0.8 - 0.1, rng.normal()]))
                s = rotate(unit(np.cross(out_dir, [0, 1, 0])), out_dir, rng.uniform(0, math.tau))
                rect = PINE_SPRAYS[0]
                ln = size
                wd = ln * rect_aspect(rect) * 1.25
                normal = crown_normal(spot, pts[0][0], pts[0][2], 0.9, 0.35)
                shade = (0.5 + 0.5 * f) * rng.uniform(0.9, 1.0)
                card(needles, spot, out_dir, s, ln, wd, rect, normal, shade)
    # Short dead stubs along the bare lower trunk.
    for b in range(10):
        t = rng.uniform(0.18, crown)
        centre, tangent = at_height(pts, t)
        yaw = rng.uniform(0, math.tau)
        d = unit(np.array([math.cos(yaw), -0.1 + rng.uniform(0, 0.3), math.sin(yaw)]))
        wood(bark, centre, d, rng.uniform(0.3, 0.9), 0.04, 0.012, 4, (0.5, 1.0), rng, 0.9, 0.05, 2)
    return bark, needles


def leaf_cluster(part, centre, rng, count, radius, axis_x, axis_z, size, shade):
    for k in range(count):
        offset = np.array([rng.normal(0, radius), rng.normal(0, radius * 0.7), rng.normal(0, radius)])
        base = centre + offset
        hang = unit(np.array([rng.normal(0, 0.5), -rng.uniform(0.1, 1.0), rng.normal(0, 0.5)]) + unit(offset) * 0.5)
        rect = LEAVES[rng.integers(len(LEAVES))]
        side = unit(np.cross(hang, [rng.normal(), rng.normal(), rng.normal()]))
        ln = size * rng.uniform(0.8, 1.3)
        wd = ln * rect_aspect(rect)
        normal = crown_normal(base, axis_x, axis_z, 0.8, 0.45)
        tone = rng.uniform(0.8, 1.05)
        card(part, base, -hang, side, ln, wd, rect, normal, shade * tone, tint=(1.0, rng.uniform(0.95, 1.05), 0.9), flip=rng.random() < 0.5)


def limbs(rng, bark, leaves, start, direction, length, radius, depth, axis, dead, scale):
    """Recursive limbs; at the tips leaf clusters (or nothing, when dead)."""
    steps = 4
    pts, last = wood(bark, start, direction, length, radius, radius * (0.55 if depth > 0 else 0.4), 6 if radius > 0.07 else (4 if radius > 0.03 else 3), (1.0, 2.0), rng, 1.0, 0.06 if dead else 0.09, steps)
    if depth == 0:
        if not dead:
            leaf_cluster(leaves, pts[-1] + last * 0.1, rng, int(rng.integers(20, 30)), 0.7 * scale, axis[0], axis[1], 0.7 * scale, 1.0)
        elif rng.random() < 0.7:
            for k in range(2):
                d = unit(last + np.array([rng.normal(0, 0.7), rng.uniform(-0.2, 0.5), rng.normal(0, 0.7)]))
                wood(bark, pts[-1], d, length * 0.5, radius * 0.4, 0.012, 3, (0.5, 1.0), rng, 0.8, 0.1, 2)
        return
    forks = int(rng.integers(2, 4))
    for k in range(forks):
        f = 0.5 + 0.5 * k / forks
        idx = min(int(f * steps), steps)
        spread = math.radians(rng.uniform(25, 55))
        axis_rot = unit(np.cross(last, [rng.normal(), 0.2, rng.normal()]))
        d = rotate(last, axis_rot, spread * (1 if k % 2 == 0 else -1) + rng.normal(0, 0.15))
        d = unit(d + np.array([0, 0.25 if not dead else 0.1, 0]))
        limbs(rng, bark, leaves, pts[idx], d, length * rng.uniform(0.6, 0.85), radius * 0.62, depth - 1, axis, dead, scale)
    # The limb goes on straight, too.
    limbs(rng, bark, leaves, pts[-1], unit(last + np.array([0, 0.15, 0])), length * 0.6, radius * 0.55, depth - 1, axis, dead, scale)


def build_broadleaf(rng, height, wide):
    bark, leaves = Part(), Part()
    r0 = 0.27 * height / 11.0
    trunk_height = height * (0.38 if wide else 0.45)
    pts = trunk_path(rng, trunk_height, rng.uniform(-0.3, 0.3), 8, 0.1)
    radii = [r0 * (1 - 0.35 * k / (len(pts) - 1)) * (1.0 + 0.8 * math.exp(-k * 0.9)) for k in range(len(pts))]
    tube(bark, pts, radii, 10, (1.2, 2.0), 1.0)
    top = pts[-1]
    count = 5 if wide else 4
    yaw0 = rng.uniform(0, math.tau)
    for k in range(count):
        yaw = yaw0 + math.tau * k / count + rng.uniform(-0.3, 0.3)
        flat = np.array([math.cos(yaw), 0, math.sin(yaw)])
        d = unit(flat * (1.0 if wide else 0.6) + np.array([0, 1.1 if wide else 1.6, 0]))
        limbs(rng, bark, leaves, top - np.array([0, 0.15, 0]), d, height * (0.36 if wide else 0.32), r0 * 0.6, 2, (top[0], top[2]), False, height / 11.0)
    return bark, leaves


def build_dead(rng, height, forked):
    bark = Part()
    r0 = 0.3 * height / 9.0
    pts = trunk_path(rng, height * (0.65 if forked else 1.0), rng.uniform(-0.5, 0.5), 12, 0.2)
    radii = [r0 * (1 - 0.7 * k / (len(pts) - 1)) * (1.0 + 0.9 * math.exp(-k * 0.8)) + 0.02 for k in range(len(pts))]
    tube(bark, pts, radii, 9, (1.6, 2.4), 1.0)
    axis = (pts[0][0], pts[0][2])
    for b in range(8 if not forked else 5):
        t = rng.uniform(0.35, 0.95)
        centre, tangent = at_height(pts, t)
        yaw = rng.uniform(0, math.tau)
        d = unit(np.array([math.cos(yaw), rng.uniform(0.2, 1.1), math.sin(yaw)]))
        limbs(rng, bark, Part(), centre, d, rng.uniform(1.4, 2.8) * height / 9.0, 0.09 * height / 9.0, 2, axis, True, 1.0)
    if forked:
        top = pts[-1]
        for k in range(2):
            d = unit(np.array([(-1) ** k * 0.45, 1.0, rng.normal(0, 0.2)]))
            limbs(rng, bark, Part(), top, d, height * 0.4, r0 * 0.5, 3, axis, True, 1.0)
    else:
        limbs(rng, bark, Part(), pts[-1], np.array([0.15, 1.0, 0.0]), height * 0.12, 0.05, 1, axis, True, 1.0)
    return bark, None


# ---------------------------------------------------------------- glTF

def write_gltf(name, bark, foliage, bark_name, foliage_name):
    buffer = bytearray()
    views, accessors, primitives = [], [], []
    materials = [
        {"name": f"Bark_{bark_name}", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.95}, "normalTexture": {"index": 1}},
    ]
    textures = [{"source": 0, "sampler": 0}, {"source": 1, "sampler": 0}]
    images = [{"uri": f"textures/bark_{bark_name}_diff.png"}, {"uri": f"textures/bark_{bark_name}_nor.png"}]
    if foliage is not None and foliage.p:
        materials.append({"name": f"Leaves_{foliage_name}", "alphaMode": "MASK", "alphaCutoff": 0.5, "doubleSided": True, "pbrMetallicRoughness": {"baseColorTexture": {"index": 2}, "metallicFactor": 0.0, "roughnessFactor": 0.72}})
        textures.append({"source": 2, "sampler": 0})
        images.append({"uri": f"textures/{foliage_name}.png"})

    def add(part, material):
        pos = np.asarray(part.p, dtype=np.float32)
        nrm = np.asarray(part.n, dtype=np.float32)
        uv = np.asarray(part.uv, dtype=np.float32)
        col = np.asarray(part.c, dtype=np.float32)
        idx = np.asarray(part.i, dtype=np.uint32)
        refs = {}
        for key, arr, ctype, kind in [("POSITION", pos, 5126, "VEC3"), ("NORMAL", nrm, 5126, "VEC3"), ("TEXCOORD_0", uv, 5126, "VEC2"), ("COLOR_0", col, 5126, "VEC4")]:
            offset = len(buffer)
            buffer.extend(arr.tobytes())
            views.append({"buffer": 0, "byteOffset": offset, "byteLength": arr.nbytes, "target": 34962})
            acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(arr), "type": kind}
            if key == "POSITION":
                acc["min"] = pos.min(0).tolist()
                acc["max"] = pos.max(0).tolist()
            accessors.append(acc)
            refs[key] = len(accessors) - 1
        offset = len(buffer)
        buffer.extend(idx.tobytes())
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": idx.nbytes, "target": 34963})
        accessors.append({"bufferView": len(views) - 1, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
        primitives.append({"attributes": refs, "indices": len(accessors) - 1, "material": material, "mode": 4})

    add(bark, 0)
    if foliage is not None and foliage.p:
        add(foliage, 1)
    doc = {
        "asset": {"version": "2.0", "generator": "tools/make_trees.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": primitives}],
        "materials": materials,
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "textures": textures,
        "images": images,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"uri": f"{name}.bin", "byteLength": len(buffer)}],
    }
    with open(os.path.join(OUT, f"{name}.bin"), "wb") as f:
        f.write(buffer)
    with open(os.path.join(OUT, f"{name}.gltf"), "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    triangles = (len(bark.i) + (len(foliage.i) if foliage is not None else 0)) // 3
    return triangles


TREES = {
    # name: (builder, args, bark, foliage sheet)
    "Fir_1": (lambda r: build_fir(r, 15.0, 0.0, False), "fir", "fir_needles"),
    "Fir_2": (lambda r: build_fir(r, 12.5, 1.0, False), "fir", "fir_needles"),
    "Fir_3": (lambda r: build_fir(r, 17.0, 0.4, True), "fir", "fir_needles"),
    "Pine_A": (lambda r: build_pine(r, 17.0, False), "pine", "pine_needles"),
    "Pine_B": (lambda r: build_pine(r, 14.0, True), "pine", "pine_needles"),
    "Birch_A": (lambda r: build_broadleaf(r, 11.0, False), "birch", "leaves"),
    "Oak_B": (lambda r: build_broadleaf(r, 12.0, True), "birch", "leaves"),
    "DeadTree_A": (lambda r: build_dead(r, 9.0, False), "dead", "leaves"),
    "DeadTree_B": (lambda r: build_dead(r, 11.0, True), "dead", "leaves"),
}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = a.split("=", 1)[1].split(",")
    folder = args[0]
    os.makedirs(OUT, exist_ok=True)
    build_textures(folder)
    for index, (name, (builder, bark_name, sheet)) in enumerate(TREES.items()):
        if only and name not in only:
            continue
        rng = np.random.default_rng(3300 + index * 17)
        bark, foliage = builder(rng)
        count = write_gltf(name, bark, foliage, bark_name, sheet)
        print(f"{name}: {count} triangles")


if __name__ == "__main__":
    main()
