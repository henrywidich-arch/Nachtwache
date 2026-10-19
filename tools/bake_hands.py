#!/usr/bin/env python3
"""Bakes the hands and arms of the first-person view into smooth surfaces.

    python3 tools/bake_hands.py <shapes.json> <out folder>

Run by tools/bake_hands.gd, which writes the shapes (round cones, ellipsoids, boxes, as
WeaponView notes them) and turns the result into Godot meshes. Each set of shapes is one
hand or arm; the shapes of a material (glove, pad, sleeve) are melted into one another with
a smooth union of their distance fields and the surface taken out with marching cubes.
Writes <key>.bin per set: for each material its name, then positions, normals, colours
(float32) and the triangle indices (int32), wound for Godot (clockwise is front).
Needs numpy and scikit-image.
"""
import json
import os
import struct
import sys

import numpy as np
from skimage.measure import marching_cubes

# Size of a voxel and how softly shapes melt together, per material (metres).
VOXEL = {"glove": 0.003, "pad": 0.0022, "sleeve": 0.0075}
SOFT = {"glove": 0.003, "pad": 0.002, "sleeve": 0.009}


def basis_of(flat):
    # Godot's Basis given column by column (x, y, z).
    return np.array(flat, dtype=np.float64).reshape(3, 3).T


def round_cone(p, a, b, r1, r2):
    """Distance to a cone with rounded ends between a (radius r1) and b (radius r2)."""
    ba = b - a
    l2 = float(ba @ ba)
    if l2 < 1e-12:
        return np.linalg.norm(p - a, axis=-1) - max(r1, r2)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    q = pa * l2 - y[..., None] * ba
    x2 = np.einsum("...i,...i->...", q, q)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d_end = np.sqrt(x2 + z2) * il2 - r2
    d_start = np.sqrt(x2 + y2) * il2 - r1
    d_side = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d_end, np.where(np.sign(y) * a2 * y2 < k, d_start, d_side))


def ellipsoid(p, centre, radii, frame):
    # Into the ellipsoid's own frame (its basis may scale; undo that too).
    inverse = np.linalg.inv(frame)
    local = (p - centre) @ inverse.T
    q = local / radii
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(local / (radii * radii), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def rounded_box(p, centre, size, frame):
    inverse = np.linalg.inv(frame)
    local = (p - centre) @ inverse.T
    half = np.array(size) * 0.5
    rad = float(np.min(half)) * 0.45
    q = np.abs(local) - (half - rad)
    outside = np.linalg.norm(np.maximum(q, 0.0), axis=-1)
    inside = np.minimum(np.max(q, axis=-1), 0.0)
    return outside + inside - rad


def distance(shape, p):
    t = shape["t"]
    if t == "cone":
        return round_cone(p, np.array(shape["a"]), np.array(shape["b"]), shape["r0"], shape["r1"])
    if t == "egg":
        return ellipsoid(p, np.array(shape["center"]), np.array(shape["radii"]), basis_of(shape["basis"]))
    return rounded_box(p, np.array(shape["center"]), shape["size"], basis_of(shape["basis"]))


def bounds(shape):
    """A box that holds the shape."""
    if shape["t"] == "cone":
        a, b = np.array(shape["a"]), np.array(shape["b"])
        r = max(shape["r0"], shape["r1"])
        return np.minimum(a, b) - r, np.maximum(a, b) + r
    frame = basis_of(shape["basis"])
    centre = np.array(shape["center"])
    half = np.array(shape["radii"] if shape["t"] == "egg" else np.array(shape["size"]) * 0.5)
    reach = np.abs(frame) @ half
    return centre - reach, centre + reach


def smooth_min(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def bake_group(shapes, key):
    voxel = VOXEL[key]
    soft = SOFT[key]
    lows, highs = zip(*(bounds(s) for s in shapes))
    low = np.min(lows, axis=0) - 4 * voxel - soft
    high = np.max(highs, axis=0) + 4 * voxel + soft
    count = np.ceil((high - low) / voxel).astype(int) + 1
    field = np.full(count, 1.0, dtype=np.float32)
    for shape in shapes:
        a, b = bounds(shape)
        i0 = np.clip(np.floor((a - soft - low) / voxel).astype(int) - 1, 0, count - 1)
        i1 = np.clip(np.ceil((b + soft - low) / voxel).astype(int) + 2, 0, count)
        axes = [low[d] + np.arange(i0[d], i1[d]) * voxel for d in range(3)]
        gx, gy, gz = np.meshgrid(*axes, indexing="ij")
        points = np.stack([gx, gy, gz], -1)
        d = distance(shape, points).astype(np.float32)
        part = field[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]]
        field[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]] = smooth_min(part, d, soft)
    if field.min() >= 0.0:
        return None
    verts, faces, normals, _ = marching_cubes(-field, level=0.0, spacing=(voxel, voxel, voxel))
    verts = verts + low
    # Normals from the field itself, pointing out.
    def field_at(points):
        value = distance(shapes[0], points)
        for shape in shapes[1:]:
            value = smooth_min(value, distance(shape, points), soft)
        return value
    eps = voxel * 0.5
    grad = np.zeros_like(verts)
    for d in range(3):
        step = np.zeros(3)
        step[d] = eps
        grad[:, d] = field_at(verts + step) - field_at(verts - step)
    normals = grad / np.maximum(np.linalg.norm(grad, axis=1, keepdims=True), 1e-12)
    # The colour of the nearest shape.
    nearest = np.stack([distance(s, verts) for s in shapes], 1)
    colours = np.array([s["c"] for s in shapes])[np.argmin(nearest, axis=1)]
    # Wound clockwise as seen from outside (Godot's front faces).
    v0, v1, v2 = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    facing = np.einsum("ij,ij->i", np.cross(v1 - v0, v2 - v0), normals[faces[:, 0]])
    if np.mean(facing > 0) > 0.5:
        faces = faces[:, [0, 2, 1]]
    return verts.astype(np.float32), normals.astype(np.float32), colours.astype(np.float32), faces.astype(np.int32)


def main():
    source, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    sets = json.load(open(source))
    seen = set()
    for entry in sets:
        key = entry["key"]
        if key in seen:
            continue
        seen.add(key)
        groups = {}
        for shape in entry["shapes"]:
            groups.setdefault(shape["k"], []).append(shape)
        blocks = []
        triangles = 0
        for material, shapes in groups.items():
            if material not in VOXEL:
                continue
            baked = bake_group(shapes, material)
            if baked is None:
                continue
            verts, normals, colours, faces = baked
            triangles += len(faces)
            print("  %s %s %d triangles, %d shapes" % (key, material, len(faces), len(shapes)), flush=True)
            name = material.encode()
            blocks.append(struct.pack("<I", len(name)) + name + struct.pack("<II", len(verts), faces.size)
                          + verts.tobytes() + normals.tobytes() + colours.tobytes() + faces.tobytes())
        with open(os.path.join(out, key + ".bin"), "wb") as f:
            f.write(struct.pack("<I", len(blocks)))
            for block in blocks:
                f.write(block)
        print("HAND %s %d triangles" % (key, triangles), flush=True)


if __name__ == "__main__":
    main()
