#!/usr/bin/env python3
"""Builds the surface textures of the farm (mission 1) into assets/surfaces/farm/.

    python3 tools/make_farm_surfaces.py [--only=siding,floor,...] [--preview=<png>]

Every set is seamless and has an albedo (sRGB), a normal map (OpenGL, Y+) and a
roughness map. Wood, earth and concrete start from the photographs in assets/surfaces;
everything else is built from tileable noise and cell patterns. The game samples them in
world space (see scripts/farm_surface.gdshader), so one texture covers `METRES` metres.
Needs numpy, scipy and Pillow. The output is deterministic.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SOURCE = os.path.join(ROOT, "assets", "surfaces")
OUT = os.path.join(SOURCE, "farm")
N = 1024


# ---------------------------------------------------------------- helpers

def load(name, size=N):
    image = Image.open(os.path.join(SOURCE, name)).convert("RGB")
    if image.size != (size, size):
        image = image.resize((size, size), Image.LANCZOS)
    return np.asarray(image, dtype=np.float32) / 255.0


def lum(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def norm01(a):
    lo, hi = np.percentile(a, 0.5), np.percentile(a, 99.5)
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0.0, 1.0)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def noise(rng, size=N, scale=8.0, stretch=(1.0, 1.0), beta=2.0, octaves=None):
    """Tileable fractal noise in 0..1. `scale` is the number of main features across
    the tile, `stretch` makes them longer along (x, y), `beta` the spectral falloff."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * size * stretch[1]
    fx = np.fft.fftfreq(size)[None, :] * size * stretch[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(np.maximum(f, scale * 0.5), beta * 0.5)
    amp *= np.exp(-(f / (size * 0.45)) ** 2)
    amp[0, 0] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return norm01(out)


def blur(a, sigma):
    return ndimage.gaussian_filter(a, sigma, mode="wrap")


def normal_from_height(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, ny / length, nz / length], -1) * 0.5 + 0.5


def cells(rng, count, size=N, aspect=1.0, jitter=1.0, rows=None):
    """Tileable Voronoi cells. Returns (id, d1, d2) per pixel; d in tile units.
    `aspect` > 1 makes cells wider than tall. With `rows` the seeds sit in courses."""
    if rows:
        per_row = max(1, count // rows)
        seeds = []
        for r in range(rows):
            shift = rng.uniform(0, 1.0 / per_row)
            for c in range(per_row):
                seeds.append(((c + 0.5 + rng.uniform(-0.35, 0.35) * jitter) / per_row + shift,
                              (r + 0.5 + rng.uniform(-0.18, 0.18) * jitter) / rows))
        seeds = np.array(seeds) % 1.0
    else:
        seeds = rng.uniform(0, 1, (count, 2))
    ids = np.arange(len(seeds))
    tiled, tiled_ids = [], []
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            tiled.append(seeds + [ox, oy])
            tiled_ids.append(ids)
    tiled = np.concatenate(tiled)
    tiled_ids = np.concatenate(tiled_ids)
    scale = np.array([1.0, aspect])
    tree = cKDTree(tiled * scale)
    g = (np.arange(size) + 0.5) / size
    px, py = np.meshgrid(g, g)
    query = np.stack([px.ravel(), py.ravel()], -1) * scale
    dist, index = tree.query(query, k=2)
    cell = tiled_ids[index[:, 0]].reshape(size, size)
    return cell, dist[:, 0].reshape(size, size), dist[:, 1].reshape(size, size)


def strokes(rng, canvas, count, length, width, angle, angle_spread, value, curve=0.0):
    """Draws soft lines (blades, fibres, scratches) into `canvas`, wrapping at the edges.
    `value` is added along each line. Returns the coverage."""
    size = canvas.shape[0]
    cover = np.zeros_like(canvas)
    for _ in range(count):
        x, y = rng.uniform(0, size, 2)
        a = angle + rng.uniform(-angle_spread, angle_spread)
        l = length * rng.uniform(0.5, 1.3)
        w = width * rng.uniform(0.6, 1.4)
        steps = max(2, int(l))
        bend = rng.uniform(-curve, curve)
        for s in range(steps):
            t = s / steps
            aa = a + bend * t
            xx = int(x + np.cos(aa) * l * t) % size
            yy = int(y + np.sin(aa) * l * t) % size
            r = max(0, int(w * (1.0 - t * 0.6)))
            ys = np.arange(yy - r, yy + r + 1) % size
            xs = np.arange(xx - r, xx + r + 1) % size
            cover[np.ix_(ys, xs)] = np.maximum(cover[np.ix_(ys, xs)], 1.0 - t * 0.5)
    canvas += cover * value
    return cover


def rotate_grain(rgb):
    """Turns a texture with vertical grain into one with horizontal grain."""
    return np.ascontiguousarray(np.rot90(rgb, 1, axes=(0, 1)))


def save(name, albedo, height, normal_strength, roughness):
    os.makedirs(OUT, exist_ok=True)
    albedo = np.clip(albedo, 0, 1)
    Image.fromarray((albedo * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_albedo.jpg"), quality=93, subsampling=0)
    normal = normal_from_height(height, normal_strength)
    Image.fromarray((normal * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.jpg"), quality=90, subsampling=0)
    rough = np.clip(roughness, 0, 1)
    Image.fromarray((rough * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(OUT, name + "_roughness.jpg"), quality=92)
    linear = np.power(albedo, 2.2)
    print("%-8s mean sRGB %s  mean linear luminance %.3f" % (name, np.round(albedo.mean((0, 1)), 3), lum(linear).mean()))
    return albedo


# ---------------------------------------------------------------- the surfaces

def siding(rng):
    """Weathered clapboards: silvered oak with flakes of old cream paint."""
    wood = rotate_grain(load("wood_albedo.png"))
    grey = lum(wood)[..., None]
    silver = wood * 0.45 + grey * np.array([0.98, 0.98, 1.0]) * 0.55
    silver = silver * 1.05 + 0.03
    # Paint peels along the grain: long flakes, more of it in some places than others.
    flakes = norm01(blur(noise(rng, scale=10, stretch=(8.0, 1.0), beta=2.2), (1.0, 4.0)))
    region = noise(rng, scale=3, beta=2.6)
    paint = smooth(0.7, 0.72, flakes * 0.55 + region * 0.55)
    paint *= 0.8 + 0.2 * noise(rng, scale=120, beta=0.8)
    paint_colour = np.array([0.74, 0.72, 0.65]) * (0.9 + 0.1 * noise(rng, scale=40)[..., None])
    albedo = silver * (1 - paint[..., None]) + paint_colour * paint[..., None]
    # Dark lines in the cracks of the grain and a dirty film.
    grain = norm01(blur(grey[..., 0], 0.7))
    cracks = smooth(0.18, 0.02, grain)
    albedo *= (1 - cracks[..., None] * 0.55)
    dirt = noise(rng, scale=5, beta=2.2)
    albedo *= (0.84 + 0.22 * dirt[..., None])
    height = grain * 0.7 + paint * 0.35 - cracks * 0.6
    roughness = 0.88 - paint * 0.2 + (1 - grain) * 0.06
    return save("siding", albedo, blur(height, 0.6), 7.0, roughness)


def floor(rng):
    """Worn oak floorboards: darker, oiled, scuffed, polished where people walk."""
    wood = rotate_grain(load("wood_albedo.png"))
    grey = lum(wood)
    warm = wood * np.array([1.04, 0.97, 0.86])
    wear = noise(rng, scale=4, beta=2.0)
    albedo = warm * (0.82 + 0.28 * wear[..., None])
    # Fine scratches across the grain and dark nail holes in a loose rhythm.
    scratch = np.zeros((N, N), np.float32)
    strokes(rng, scratch, 420, 46, 0.0, np.pi / 2, 0.5, 1.0)
    scratch = blur(scratch, 0.6)
    albedo += scratch[..., None] * 0.035
    grain = norm01(blur(grey, 0.8))
    cracks = smooth(0.16, 0.02, grain)
    albedo *= (1 - cracks[..., None] * 0.5)
    grime = smooth(0.55, 0.85, noise(rng, scale=9, beta=1.8))
    albedo *= (1 - grime[..., None] * 0.18)
    height = grain * 0.6 - cracks * 0.5 - scratch * 0.2
    roughness = 0.52 + (1 - wear) * 0.26 + grime * 0.12 + scratch * 0.1
    return save("floor", albedo, blur(height, 0.6), 5.0, roughness)


def panel(rng):
    """Inner face of the walls: the same boards, never weathered, with an old oiled
    finish gone honey-dark, smoke darkening some of them."""
    wood = rotate_grain(load("wood_albedo.png"))
    grey = lum(wood)
    albedo = wood * np.array([1.06, 0.98, 0.86]) * 0.85 + grey[..., None] * 0.15
    grain = norm01(blur(grey, 0.8))
    cracks = smooth(0.15, 0.02, grain)
    albedo *= (1 - cracks[..., None] * 0.4)
    smoke = noise(rng, scale=4, beta=2.2)
    albedo *= (0.86 + 0.2 * smoke[..., None])
    height = grain * 0.5 - cracks * 0.45
    roughness = 0.66 + (1 - grain) * 0.12 + smoke * 0.06
    return save("panel", albedo, blur(height, 0.6), 4.5, roughness)


def planks(rng):
    """Upright barn and shed planks: the oak, rougher, with water stains."""
    wood = load("wood_albedo.png")
    grey = lum(wood)
    albedo = wood * 0.7 + grey[..., None] * 0.3
    stains = noise(rng, scale=6, stretch=(1.0, 4.0), beta=2.0)
    albedo *= (0.78 + 0.32 * stains[..., None])
    grain = norm01(blur(grey, 0.8))
    cracks = smooth(0.17, 0.02, grain)
    albedo *= (1 - cracks[..., None] * 0.55)
    height = grain * 0.7 - cracks * 0.6
    roughness = 0.84 + (1 - grain) * 0.1
    return save("planks", albedo, blur(height, 0.6), 7.0, roughness)


def stone(rng):
    """Fieldstone masonry laid in rough courses, deep grey mortar between."""
    concrete = load("concrete_albedo.png")
    micro = norm01(lum(concrete))
    cell, d1, d2 = cells(rng, 90, aspect=1.7, rows=9, jitter=1.6)
    # Polygons with their corners rounded off: the nearer of the cell edge and a circle
    # a little smaller than the cell around the seed.
    size_of = np.zeros(cell.max() + 1)
    np.maximum.at(size_of, cell.ravel(), d1.ravel())
    radius = size_of[cell] * 0.82
    edge = np.minimum(d2 - d1, (radius - d1) * 0.9)
    wobble = noise(rng, scale=26, beta=1.6)
    edge = edge + (wobble - 0.5) * 0.022
    mortar = smooth(0.011, 0.003, edge)
    dome = smooth(0.0, 0.035, edge) ** 0.6
    # Chips, flat faces and a little crumble where the stones meet.
    facets = noise(rng, scale=48, beta=1.2)
    dome = dome * (0.85 + 0.15 * facets)
    palette = np.array([
        [0.50, 0.48, 0.45], [0.55, 0.53, 0.49], [0.43, 0.42, 0.41], [0.53, 0.49, 0.43],
        [0.40, 0.40, 0.40], [0.58, 0.56, 0.52], [0.48, 0.45, 0.40], [0.52, 0.52, 0.50],
        [0.46, 0.42, 0.38]])
    pick = rng.integers(0, len(palette), cell.max() + 1)
    shade = rng.uniform(0.86, 1.1, cell.max() + 1)
    colour = palette[pick[cell]] * shade[cell][..., None]
    blotch = noise(rng, scale=14, beta=1.8)
    colour *= (0.82 + 0.3 * blotch[..., None]) * (0.8 + 0.35 * micro[..., None])
    lichen = smooth(0.7, 0.86, noise(rng, scale=10, beta=1.6)) * dome
    colour = colour * (1 - lichen[..., None] * 0.5) + np.array([0.46, 0.5, 0.36]) * lichen[..., None] * 0.5
    mortar_colour = np.array([0.33, 0.32, 0.30]) * (0.8 + 0.4 * micro[..., None])
    albedo = colour * (1 - mortar[..., None]) + mortar_colour * mortar[..., None]
    albedo *= (0.72 + 0.28 * dome[..., None])
    height = dome * 0.75 + micro * 0.18 + blotch * 0.12
    roughness = 0.9 - dome * 0.08 + mortar * 0.08
    return save("stone", albedo, blur(height, 0.8), 14.0, roughness)


def shingle(rng):
    """Old asphalt roofing: mineral grit, tab slits, streaks running down, moss."""
    grit = noise(rng, scale=200, beta=0.6)
    speck = (rng.uniform(0, 1, (N, N)) > 0.985).astype(np.float32)
    speck = blur(speck, 0.5) * 2.0
    base = 0.36 + grit[..., None] * 0.22 + speck[..., None] * 0.18
    albedo = base * np.array([0.98, 0.98, 1.02])
    # Down-slope water streaks: the slope runs along the v axis.
    streaks = noise(rng, scale=24, stretch=(1.0, 14.0), beta=1.8)
    albedo *= (0.76 + 0.34 * streaks[..., None])
    # Tab slits every third of a metre (the courses themselves are geometry).
    x = (np.arange(N) + 0.5) / N
    tabs = np.zeros((N, N), np.float32)
    rows = 8
    for r in range(rows):
        shift = rng.uniform(0, 1)
        y0, y1 = int(r * N / rows), int((r + 1) * N / rows)
        phase = (x * 6 + shift) % 1.0
        slit = smooth(0.012, 0.004, np.abs(phase - 0.5) - 0.0)  # thin dark slit
        tabs[y0:y1] = slit[None, :]
    tabs = blur(tabs, 0.8)
    tabs *= 0.0
    moss_mask = 0.75 * smooth(0.66, 0.84, noise(rng, scale=7, beta=2.2) * 0.7 + noise(rng, scale=40, beta=1.2) * 0.3)
    moss = np.array([0.27, 0.30, 0.18]) * (0.7 + 0.5 * noise(rng, scale=90, beta=1.0)[..., None])
    albedo = albedo * (1 - moss_mask[..., None]) + moss * moss_mask[..., None]
    height = grit * 0.4 + speck * 0.2 - tabs * 0.8 + moss_mask * 0.3
    roughness = 0.86 + grit * 0.08 - speck * 0.1 + moss_mask * 0.06
    return save("shingle", albedo, blur(height, 0.5), 5.0, roughness)


def metal(rng):
    """Painted sheet metal gone to rust: chipped paint, rust blooms and runs, scratches."""
    base_noise = noise(rng, scale=12, beta=2.0)
    paint = np.ones((N, N, 3), np.float32) * (0.68 + 0.12 * base_noise[..., None])
    chips = noise(rng, scale=40, beta=1.3)
    region = noise(rng, scale=4, beta=2.4)
    runs = noise(rng, scale=30, stretch=(1.0, 10.0), beta=1.6)
    rust_amount = region * 0.45 + chips * 0.4 + runs * 0.3
    rust = smooth(0.71, 0.76, rust_amount)
    bloom = smooth(0.58, 0.72, rust_amount) * (1 - rust)
    rust_tone = noise(rng, scale=60, beta=1.2)
    rust_colour = np.stack([0.34 + rust_tone * 0.2, 0.19 + rust_tone * 0.09, 0.11 + rust_tone * 0.04], -1)
    stained = paint * (1 - bloom[..., None] * 0.35) + np.array([0.5, 0.33, 0.2]) * bloom[..., None] * 0.35
    albedo = stained * (1 - rust[..., None]) + rust_colour * rust[..., None]
    scratch = np.zeros((N, N), np.float32)
    strokes(rng, scratch, 160, 70, 0.0, 0.0, np.pi, 1.0)
    scratch = blur(scratch, 0.5) * (1 - rust)
    albedo += scratch[..., None] * 0.12
    grime = noise(rng, scale=6, beta=2.0)
    albedo *= (0.82 + 0.25 * grime[..., None])
    pits = noise(rng, scale=180, beta=0.5)
    height = (1 - rust) * 0.35 + rust * pits * 0.5 + bloom * 0.08 - scratch * 0.15
    roughness = 0.5 + rust * 0.42 + bloom * 0.15 - scratch * 0.18 + grime * 0.08
    return save("metal", albedo, blur(height, 0.6), 5.0, roughness)


def meadow(rng):
    """Ground of the yard: dark soil under matted, half dead grass and moss."""
    earth = load("earth_albedo.png")
    soil = earth * 0.8
    blades = np.zeros((N, N), np.float32)
    for angle, count in ((0.3, 2600), (2.1, 2600), (4.0, 2600)):
        strokes(rng, blades, count, 26, 0.6, angle, 1.2, 1.0, curve=0.6)
    blades = np.clip(blur(blades, 0.6), 0, 1)
    patch = noise(rng, scale=5, beta=2.2)
    cover = np.clip(blades * (0.45 + patch * 0.9), 0, 1)
    hue = noise(rng, scale=16, beta=1.6)
    green = np.array([0.30, 0.34, 0.16])
    straw = np.array([0.46, 0.41, 0.26])
    grass = green * (1 - hue[..., None]) + straw * hue[..., None]
    grass *= (0.65 + 0.5 * noise(rng, scale=160, beta=0.8)[..., None])
    moss_mask = smooth(0.55, 0.8, noise(rng, scale=8, beta=2.0)) * (1 - cover)
    moss = np.array([0.22, 0.28, 0.12])
    albedo = soil * (1 - cover[..., None]) + grass * cover[..., None]
    albedo = albedo * (1 - moss_mask[..., None] * 0.7) + moss * moss_mask[..., None] * 0.7
    height = norm01(lum(earth)) * 0.4 + cover * 0.6 + moss_mask * 0.3
    roughness = 0.94 - cover * 0.04
    return save("meadow", albedo, blur(height, 0.6), 6.0, roughness)


def dirt(rng):
    """Trodden farm track: compacted soil, gravel pressed into it, ruts of mud."""
    earth = load("earth_albedo.png")
    cell, d1, d2 = cells(rng, 1400)
    pebble = smooth(0.0045, 0.0015, d1) * (rng.uniform(0, 1, cell.max() + 1) > 0.45)[cell]
    tone = rng.uniform(0.45, 0.75, cell.max() + 1)[cell]
    gravel = np.stack([tone, tone * 0.97, tone * 0.92], -1)
    mud = noise(rng, scale=5, beta=2.2)
    albedo = earth * (0.95 + 0.2 * mud[..., None])
    albedo = albedo * (1 - pebble[..., None]) + gravel * pebble[..., None]
    height = norm01(lum(earth)) * 0.5 + pebble * 0.5 + mud * 0.2
    roughness = 0.9 - pebble * 0.12
    return save("dirt", albedo, blur(height, 0.6), 8.0, roughness)


def fabric(rng):
    """Coarse woven upholstery: a twill weave with pilling and worn patches."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    threads = 256
    u = x * threads / N
    v = y * threads / N
    warp = 0.5 + 0.5 * np.cos(u * 2 * np.pi)
    weft = 0.5 + 0.5 * np.cos(v * 2 * np.pi)
    twill = ((np.floor(u) + np.floor(v)) % 4 < 2).astype(np.float32)
    weave = np.where(twill > 0.5, warp, weft)
    fuzz = noise(rng, scale=160, beta=0.8)
    worn = noise(rng, scale=5, beta=2.2)
    albedo = np.ones((N, N, 3)) * (0.72 + 0.18 * weave[..., None] + 0.1 * fuzz[..., None])
    albedo *= (0.85 + 0.25 * worn[..., None])
    height = weave * 0.6 + fuzz * 0.3
    roughness = 0.96 - weave * 0.04
    return save("fabric", albedo, blur(height, 0.4), 4.0, roughness)


def straw(rng):
    """Pressed hay: dense blond fibres, mostly running one way, darker gaps."""
    stems = np.zeros((N, N), np.float32)
    strokes(rng, stems, 7000, 110, 0.8, 0.0, 0.3, 1.0, curve=0.25)
    stems = np.clip(blur(stems, 0.5), 0, 1)
    shade = noise(rng, scale=12, beta=1.8)
    dry = np.array([0.80, 0.68, 0.40])
    old = np.array([0.55, 0.47, 0.30])
    hue = noise(rng, scale=30, beta=1.4)
    colour = dry * (1 - hue[..., None]) + old * hue[..., None]
    albedo = colour * (0.45 + 0.65 * stems[..., None]) * (0.85 + 0.25 * shade[..., None])
    height = stems
    roughness = 0.9 - stems * 0.08
    return save("straw", albedo, blur(height, 0.4), 6.0, roughness)


def carpaint(rng):
    """Old vehicle paint: mostly whole, sun-faded in patches, fine scratches and a few
    blooms of rust breaking through."""
    peel = noise(rng, scale=180, beta=0.7)
    fade = noise(rng, scale=4, beta=2.4)
    albedo = np.ones((N, N, 3), np.float32) * (0.72 + 0.1 * fade[..., None] + 0.02 * peel[..., None])
    spots = noise(rng, scale=26, beta=1.4) * 0.6 + noise(rng, scale=5, beta=2.2) * 0.5
    rust = smooth(0.78, 0.82, spots)
    halo = smooth(0.7, 0.8, spots) * (1 - rust)
    tone = noise(rng, scale=70, beta=1.1)
    rust_colour = np.stack([0.36 + tone * 0.2, 0.2 + tone * 0.08, 0.11 + tone * 0.04], -1)
    albedo = albedo * (1 - halo[..., None] * 0.3) + np.array([0.45, 0.3, 0.2]) * halo[..., None] * 0.3
    albedo = albedo * (1 - rust[..., None]) + rust_colour * rust[..., None]
    scratch = np.zeros((N, N), np.float32)
    strokes(rng, scratch, 260, 50, 0.0, 0.2, 0.6, 1.0)
    scratch = blur(scratch, 0.45) * (1 - rust)
    albedo += scratch[..., None] * 0.1
    height = peel * 0.15 + rust * 0.4 + tone * rust * 0.3 - scratch * 0.2
    roughness = 0.42 + fade * 0.2 + rust * 0.45 + scratch * 0.15
    return save("carpaint", albedo, blur(height, 0.5), 3.0, roughness)


def glove(rng):
    """Synthetic leather of a field glove: a fine pebbled grain, creases where the hand
    bends, a little wear. Near white: the hands tint it."""
    cell, d1, d2 = cells(rng, 9000)
    pebble = smooth(0.0, 0.012, d2 - d1) * 0.8 + smooth(0.006, 0.0, d1) * 0.2
    creases = noise(rng, scale=14, stretch=(1.0, 6.0), beta=1.4)
    creases = smooth(0.62, 0.72, creases)
    wear = noise(rng, scale=5, beta=2.2)
    albedo = np.ones((N, N, 3), np.float32) * (0.8 + 0.1 * pebble[..., None] - 0.12 * creases[..., None])
    albedo *= (0.9 + 0.15 * wear[..., None])
    height = pebble * 0.6 - creases * 0.5
    roughness = 0.62 - pebble * 0.1 + creases * 0.15 + (1 - wear) * 0.08
    return save("glove", albedo, blur(height, 0.6), 6.0, roughness)


def cliff(rng):
    """Bare rock of a cliff: big blocks split by irregular cracks, each a facet that
    leans its own way, fine grain on them, lighter water streaks and lichen."""
    grain = norm01(lum(load("concrete_albedo.png")))
    cell, d1, d2 = cells(rng, 34, aspect=0.75, jitter=1.0)
    wobble = noise(rng, scale=22, beta=1.5)
    edge = d2 - d1 + (wobble - 0.5) * 0.035
    cracks = smooth(0.006, 0.001, edge)
    chips = smooth(0.03, 0.012, edge) * 0.4
    y, x = np.mgrid[0:N, 0:N].astype(np.float32) / N
    lean_x = rng.uniform(-1, 1, cell.max() + 1)[cell]
    lean_y = rng.uniform(-1, 1, cell.max() + 1)[cell]
    facet = (x * lean_x + y * lean_y) * 6.0
    facet = facet - np.floor(facet)
    facet = blur(facet, 1.0)
    tone_shift = rng.uniform(0.86, 1.12, cell.max() + 1)[cell]
    lumps = noise(rng, scale=16, beta=1.6)
    base = np.array([0.5, 0.48, 0.44]) * tone_shift[..., None]
    albedo = base * (0.78 + 0.22 * grain[..., None]) * (0.85 + 0.25 * lumps[..., None])
    streaks = smooth(0.58, 0.82, noise(rng, scale=16, stretch=(1.0, 5.0), beta=1.8))
    albedo = albedo * (1 - streaks[..., None] * 0.18)
    lichen = smooth(0.66, 0.82, noise(rng, scale=9, beta=1.8)) * (1 - cracks)
    albedo = albedo * (1 - lichen[..., None] * 0.5) + np.array([0.57, 0.58, 0.42]) * lichen[..., None] * 0.5
    albedo *= (1 - cracks[..., None] * 0.38 - chips[..., None] * 0.12)
    height = facet * 0.35 + lumps * 0.4 + grain * 0.25 - cracks * 1.0 - chips * 0.4
    roughness = 0.87 + grain * 0.06 - lichen * 0.04
    return save("cliff", albedo, blur(height, 0.8), 9.0, roughness)


def forest_floor(rng):
    """The floor under trees: dark earth under needles, fallen leaves and twigs, moss."""
    earth = load("earth_albedo.png") * 0.6
    needles = np.zeros((N, N), np.float32)
    strokes(rng, needles, 9000, 22, 0.4, 0.0, np.pi, 1.0, curve=0.2)
    needles = np.clip(blur(needles, 0.5), 0, 1)
    leaves = np.zeros((N, N), np.float32)
    cell, d1, d2 = cells(rng, 900, aspect=1.8)
    gather = noise(rng, scale=6, beta=2.0)
    leaf = smooth(0.011, 0.004, d1) * (rng.uniform(0, 1, cell.max() + 1)[cell] < gather * 0.9)
    leaf_tone = rng.uniform(0, 1, cell.max() + 1)[cell]
    leaf_colour = np.stack([0.36 + leaf_tone * 0.16, 0.25 + leaf_tone * 0.08, 0.14 + leaf_tone * 0.04], -1)
    twigs = np.zeros((N, N), np.float32)
    strokes(rng, twigs, 220, 90, 1.2, 0.0, np.pi, 1.0, curve=0.5)
    twigs = np.clip(blur(twigs, 0.6), 0, 1)
    moss = smooth(0.6, 0.78, noise(rng, scale=6, beta=2.0))
    needle_colour = np.array([0.44, 0.32, 0.2]) * (0.8 + 0.3 * noise(rng, scale=90, beta=0.9)[..., None])
    albedo = earth * (1 - needles[..., None]) + needle_colour * needles[..., None]
    albedo = albedo * (1 - leaf[..., None]) + leaf_colour * leaf[..., None]
    albedo = albedo * (1 - twigs[..., None]) + np.array([0.3, 0.22, 0.15]) * twigs[..., None]
    albedo = albedo * (1 - moss[..., None] * 0.75) + np.array([0.24, 0.32, 0.12]) * moss[..., None] * 0.75
    height = needles * 0.3 + leaf * 0.5 + twigs * 0.6 + moss * 0.4
    roughness = 0.92 - leaf * 0.08
    return save("forest_floor", albedo, blur(height, 0.5), 6.0, roughness)


def field(rng):
    """Open grassland of the lowland: dry, pale stalks among green, bare soil between."""
    earth = load("earth_albedo.png") * 0.75
    dry = np.zeros((N, N), np.float32)
    for angle in (0.4, 1.9, 3.3):
        strokes(rng, dry, 2600, 34, 0.7, angle, 0.9, 1.0, curve=0.4)
    dry = np.clip(blur(dry, 0.5), 0, 1)
    green = np.zeros((N, N), np.float32)
    strokes(rng, green, 3200, 24, 0.6, 1.2, 1.4, 1.0, curve=0.5)
    green = np.clip(blur(green, 0.5), 0, 1)
    patch = noise(rng, scale=5, beta=2.2)
    straw = np.array([0.62, 0.55, 0.34]) * (0.8 + 0.3 * noise(rng, scale=60, beta=1.0)[..., None])
    grass = np.array([0.33, 0.4, 0.18]) * (0.8 + 0.3 * noise(rng, scale=70, beta=1.0)[..., None])
    albedo = earth * (1 - dry[..., None]) + straw * dry[..., None]
    albedo = albedo * (1 - green[..., None] * (0.4 + patch[..., None] * 0.6)) + grass * green[..., None] * (0.4 + patch[..., None] * 0.6)
    height = dry * 0.5 + green * 0.5
    roughness = 0.93
    return save("field", albedo, blur(height, 0.5), 5.0, roughness + np.zeros((N, N)))


def save_picture(name, albedo, height=None, strength=3.0, quality=92):
    os.makedirs(OUT, exist_ok=True)
    albedo = np.clip(albedo, 0, 1)
    Image.fromarray((albedo * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_albedo.jpg"), quality=quality, subsampling=0)
    if height is not None:
        normal = normal_from_height(height, strength)
        Image.fromarray((normal * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.jpg"), quality=90, subsampling=0)
    print("%-8s %dx%d picture" % (name, albedo.shape[1], albedo.shape[0]))
    return albedo


def persian(rng, field, ground, accent):
    """A hand-knotted rug laid out like a Persian one: a field with a medallion and corner
    pieces, small flowers all over, a wide border with rosettes between guard stripes.
    Drawn knot by knot, then worn down in the middle and soiled at the edges."""
    kw, kh = 320, 260
    y, x = np.mgrid[0:kh, 0:kw].astype(np.float32)
    u = (x + 0.5) / kw * 2 - 1
    v = (y + 0.5) / kh * 2 - 1
    ivory = np.array([0.82, 0.75, 0.6])
    gold = np.array([0.74, 0.52, 0.2])
    navy = np.array(ground)
    red = np.array(field)
    dark = np.array([0.1, 0.06, 0.05])
    green = np.array(accent)
    img = np.zeros((kh, kw, 3), np.float32)
    # Abrash: bands where the dyed wool came from another batch.
    bands = np.repeat(noise(rng, 256, scale=10, stretch=(1.0, 0.05), beta=1.6)[:kh // 2 + 1, :1], 2, 0)[:kh]
    img[:] = red * (0.85 + 0.3 * bands[..., None])
    ax, ay = np.abs(u), np.abs(v)
    edge = np.maximum(ax, ay * 1.0)
    # Borders measured from the outside in.
    dx, dy = 1 - ax, 1 - ay
    d = np.minimum(dx * kw, dy * kh) / kw  # in rug widths
    def put(mask, colour):
        img[mask] = colour
    put(d < 0.012, dark)
    guard_out = (d >= 0.012) & (d < 0.032)
    put(guard_out, ivory)
    dots = guard_out & ((np.floor(x / 3) + np.floor(y / 3)) % 2 == 0) & ((x + y) % 5 < 2)
    put(dots, red * 0.8)
    main = (d >= 0.032) & (d < 0.105)
    put(main, navy)
    # Rosettes along the main border.
    along = np.where(dx * kw < dy * kh, (v + 1) * kh, (u + 1) * kw)
    across = (d - 0.0685) / 0.036
    period = 26.0
    t = (along % period) / period - 0.5
    ring = np.sqrt((t * period / kw / 0.036) ** 2 + across ** 2)
    angle = np.arctan2(across, t)
    petal = 0.62 + 0.25 * np.cos(angle * 6)
    put(main & (ring < petal), gold)
    put(main & (ring < petal * 0.55), red * 1.1)
    put(main & (ring < 0.16), ivory)
    vine = main & (np.abs(across - 0.55 * np.sin((along / period) * np.pi * 2)) < 0.09) & (ring > petal)
    put(vine, green)
    guard_in = (d >= 0.105) & (d < 0.122)
    put(guard_in, ivory)
    put(guard_in & ((x + 2 * y) % 6 < 2), green)
    put((d >= 0.122) & (d < 0.128), dark)
    inner = d >= 0.128
    # Small flowers on a lattice over the field.
    gu = (u * 9) % 1.0 - 0.5
    gv = (v * 7 + np.floor(u * 9) * 0.5) % 1.0 - 0.5
    fr = np.sqrt(gu ** 2 + gv ** 2)
    fa = np.arctan2(gv, gu)
    flower = inner & (fr < 0.2 + 0.08 * np.cos(fa * 5))
    put(flower, navy * 1.1)
    put(inner & (fr < 0.08), gold)
    leaf = inner & (np.abs(gu - gv) < 0.04) & (fr > 0.24) & (fr < 0.42)
    put(leaf, green)
    # Corner pieces of the field.
    cu = (ax - 1.0) / 0.55
    cv = (ay - 1.0) / 0.5
    corner = inner & (cu ** 2 + cv ** 2 < 0.62 ** 2)
    put(corner, navy)
    put(corner & (np.abs(np.sqrt(cu ** 2 + cv ** 2) - 0.5) < 0.03), ivory)
    put(corner & ((np.floor(x / 4) + np.floor(y / 4)) % 3 == 0) & (cu ** 2 + cv ** 2 < 0.42 ** 2), gold * 0.9)
    # The medallion: a scalloped diamond in layers, a rosette in its heart.
    ma = np.arctan2(v, u * 0.82)
    mr = ax / 0.46 + ay / 0.56
    scallop = 1.0 + 0.07 * np.cos(ma * 18)
    put(inner & (mr < scallop), dark)
    put(inner & (mr < scallop * 0.96), navy)
    put(inner & (np.abs(mr - 0.72) < 0.035), ivory)
    put(inner & (mr < 0.62), red * 1.05)
    put(inner & (np.abs(mr - 0.45) < 0.04), gold)
    rr = np.sqrt((u / 0.46) ** 2 + (v / 0.56) ** 2)
    ra = np.arctan2(v, u)
    put(inner & (rr < 0.24 + 0.06 * np.cos(ra * 8)), ivory)
    put(inner & (rr < 0.15 + 0.04 * np.cos(ra * 8 + 0.4)), navy)
    put(inner & (rr < 0.06), gold)
    for k in range(4):
        cx, cy = np.cos(k * np.pi / 2) * 0.62, np.sin(k * np.pi / 2) * 0.62
        pr = np.sqrt((u / 0.46 - cx) ** 2 + (v / 0.56 - cy) ** 2)
        put(inner & (pr < 0.09), green)
        put(inner & (pr < 0.04), ivory)
    # Each knot a little different; then up to the picture size.
    img *= (0.9 + 0.2 * rng.uniform(0, 1, (kh, kw, 1)))
    big = np.asarray(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((1024, 832), Image.NEAREST), np.float32) / 255.0
    yy, xx = np.mgrid[0:832, 0:1024].astype(np.float32)
    knot = (0.5 + 0.5 * np.cos(xx / 1024 * kw * 2 * np.pi)) * (0.5 + 0.5 * np.cos(yy / 832 * kh * 2 * np.pi))
    big *= (0.88 + 0.16 * knot[..., None])
    big = ndimage.gaussian_filter(big, (0.6, 0.6, 0))
    # Wear: the pile is thin where people walked, the edges darkened by dirt.
    walk = np.asarray(Image.fromarray((noise(rng, 256, scale=3, beta=2.6) * 255).astype(np.uint8)).resize((1024, 832), Image.BILINEAR), np.float32) / 255.0
    uu = np.abs(xx / 1024 * 2 - 1)
    vv = np.abs(yy / 832 * 2 - 1)
    worn = smooth(0.55, 0.95, walk) * (1 - np.maximum(uu, vv) ** 2) * 0.28
    weft = np.array([0.62, 0.55, 0.45])
    grey = big.mean(-1, keepdims=True)
    big = big * (1 - worn[..., None]) + (grey * 0.5 + weft * 0.5) * worn[..., None]
    dirt = smooth(0.7, 1.0, np.maximum(uu, vv)) * 0.25
    big *= (1 - dirt[..., None])
    height = knot * 0.5 * (1 - worn) + (1 - worn) * 0.3
    return big, height


def rug_red(rng):
    albedo, height = persian(rng, [0.5, 0.075, 0.065], [0.08, 0.1, 0.22], [0.16, 0.3, 0.27])
    return save_picture("rug_red", albedo, height, 2.5)


def rug_blue(rng):
    albedo, height = persian(rng, [0.1, 0.13, 0.26], [0.42, 0.07, 0.06], [0.55, 0.42, 0.2])
    return save_picture("rug_blue", albedo, height, 2.5)


def landscape(rng, sky_top, sky_low, sun, hills, water, trees, moon=False, storm=False):
    """An old oil painting: sky, ranges of hills fading into haze, a lake that mirrors
    them, firs in front; brush strokes, yellowed varnish and fine cracks over it."""
    w, h = 768, 576
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    yn = y / h
    xn = x / w
    horizon = 0.56
    sky = np.array(sky_top) * (1 - yn[..., None] / horizon) + np.array(sky_low) * (yn[..., None] / horizon)
    img = sky.copy()
    clouds = noise(rng, 512, scale=6, stretch=(4.0, 1.0), beta=2.0)
    clouds = np.asarray(Image.fromarray((clouds * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 255.0
    cloud_amount = smooth(0.45, 0.8, clouds) * (yn < horizon) * (0.9 if storm else 0.5)
    cloud_colour = np.array(sky_low) * 0.6 + np.array(sky_top) * 0.4 if storm else np.array(sky_low) * 1.1
    img = img * (1 - cloud_amount[..., None]) + cloud_colour * cloud_amount[..., None]
    sx, sy = 0.68, horizon - 0.14
    sd = np.sqrt(((xn - sx) * w / h) ** 2 + (yn - sy) ** 2)
    if not storm:
        glow = np.exp(-sd * (9 if moon else 5)) * 0.6
        img += np.array(sun) * glow[..., None]
        img[sd < (0.035 if moon else 0.05)] = np.array(sun) * 1.2
    far = np.array(sky_low) * 0.75 + np.array(hills) * 0.25
    for layer, (base, rough, tone) in enumerate([(0.47, 0.06, far), (0.51, 0.05, np.array(hills) * 0.9 + far * 0.1), (0.55, 0.035, np.array(hills) * 0.6)]):
        line = noise(rng, 256, scale=3 + layer * 2, beta=2.2)[0]
        line = ndimage.gaussian_filter1d(line, 5 - layer, mode="wrap")
        line = norm01(line)
        line = np.interp(np.linspace(0, 255, w), np.arange(256), line)
        top = (base + (line - 0.5) * rough * 3) * h
        mask = (y > top[None, :]) & (yn < horizon + 0.003)
        img[mask] = tone
    # The lake: what lies above the shore, mirrored, darker and broken by ripples.
    shore = int(horizon * h)
    depth = h - shore
    mirror = img[max(0, shore - depth):shore][::-1]
    if mirror.shape[0] < depth:
        mirror = np.concatenate([mirror, np.repeat(mirror[-1:], depth - mirror.shape[0], 0)])
    ripple = (np.sin(y[shore:] * 0.9 + noise(rng, 256, scale=20, beta=1.2)[:1, :1] * 3) * 0.5 + 0.5)
    shift = (ripple * 3).astype(int)
    lake = np.take_along_axis(mirror, np.clip(np.arange(w)[None, :] + shift, 0, w - 1)[..., None].repeat(3, 2), 1)
    img[shore:] = lake * 0.55 + np.array(water) * 0.45
    img[shore:shore + 2] = np.array(hills) * 0.5
    # Firs and a meadow in front.
    meadow = (yn > 0.82 + 0.03 * np.sin(xn * 7))
    img[meadow] = np.array(trees) * 1.3
    for k in range(9):
        tx = rng.uniform(0.0, 1.0) if k > 1 else (0.06 if k == 0 else 0.93)
        tall = rng.uniform(0.25, 0.5)
        foot = 0.86 + rng.uniform(0, 0.08)
        rel = (foot - yn) / tall
        half = (0.16 + 0.05 * np.abs(np.sin(rel * 26))) * (1 - rel) * tall
        tree = (rel > 0) & (rel < 1) & (np.abs(xn - tx) * w / h < half)
        img[tree] = np.array(trees) * rng.uniform(0.7, 1.0)
    # Brush strokes, yellowed varnish, cracks and a dark edge.
    strokes_n = noise(rng, 512, scale=60, stretch=(3.0, 1.0), beta=1.0)
    strokes_n = np.asarray(Image.fromarray((strokes_n * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 255.0
    img *= (0.9 + 0.2 * strokes_n[..., None])
    img = ndimage.gaussian_filter(img, (1.0, 1.0, 0))
    img = img * np.array([1.0, 0.94, 0.78]) * 0.92
    cell, d1, d2 = cells(rng, 5000, size=1024)
    crack = smooth(0.0009, 0.0, d2 - d1) * 0.5
    crack = np.asarray(Image.fromarray((crack * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 255.0
    img *= (1 - crack[..., None] * 0.25)
    vign = np.sqrt(((xn - 0.5) * 1.4) ** 2 + ((yn - 0.5) * 1.6) ** 2)
    img *= (1 - smooth(0.5, 1.0, vign)[..., None] * 0.45)
    return img


def painting_lake(rng):
    return save_picture("painting_lake", landscape(rng, [0.22, 0.27, 0.42], [0.86, 0.55, 0.32], [1.0, 0.75, 0.4], [0.32, 0.28, 0.3], [0.2, 0.22, 0.28], [0.08, 0.12, 0.08]))


def painting_moon(rng):
    return save_picture("painting_moon", landscape(rng, [0.03, 0.05, 0.1], [0.2, 0.26, 0.36], [0.92, 0.92, 0.82], [0.12, 0.15, 0.2], [0.06, 0.08, 0.12], [0.03, 0.05, 0.05], moon=True))


def painting_storm(rng):
    return save_picture("painting_storm", landscape(rng, [0.2, 0.22, 0.24], [0.55, 0.52, 0.44], [0.9, 0.8, 0.6], [0.3, 0.32, 0.22], [0.25, 0.27, 0.27], [0.12, 0.14, 0.07], storm=True))


def macro(rng):
    """Three independent large blotch patterns (R, G, B) that break up tiling."""
    size = 512
    a = noise(rng, size, scale=3, beta=2.4)
    b = noise(rng, size, scale=6, beta=2.0)
    c = noise(rng, size, scale=12, stretch=(1.0, 3.0), beta=1.8)
    image = np.stack([a, b, c], -1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((image * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, "macro.png"))
    print("macro    512px")


def gravel(rng):
    """A gravel path: small rounded stones of muted greys and browns, packed in damp
    soil that shows between them, a few bigger ones, and patches of bare earth."""
    earth = load("earth_albedo.png")
    soil = earth * 0.62
    albedo = soil.copy()
    height = norm01(lum(earth)) * 0.15
    roughness = np.full((N, N), 0.93)
    # Three sizes, the large stones first; each stone a round, slightly squashed blob
    # around its seed, of its own size, so that soil stays between them.
    for count, keep in ((700, 0.6), (2600, 0.75), (8000, 0.8)):
        cell, d1, d2 = cells(rng, count)
        spacing = (1.0 / count) ** 0.5
        radius = rng.uniform(0.3, 0.48, cell.max() + 1)[cell] * spacing
        inside = np.clip(1.0 - d1 / radius, 0.0, 1.0)
        stone = smooth(0.0, 0.18, inside) * (rng.uniform(0, 1, cell.max() + 1) < keep)[cell]
        dome = np.sqrt(inside)
        grey = rng.uniform(0.28, 0.56, cell.max() + 1)
        warm = rng.uniform(0.0, 0.07, cell.max() + 1)
        colour = np.stack([grey + warm, grey + warm * 0.55, grey - warm * 0.2], -1)[cell]
        # Lit from above, darker towards their rim; dirt clings to some.
        colour = colour * (0.62 + 0.45 * dome[..., None])
        dirty = (rng.uniform(0, 1, cell.max() + 1) < 0.3)[cell]
        colour = np.where(dirty[..., None], colour * 0.6 + soil * 0.4, colour)
        on_top = stone * (dome * 0.8 + 0.2 > height)
        albedo = albedo * (1 - on_top[..., None]) + colour * on_top[..., None]
        height = np.maximum(height, (0.2 + dome * 0.8) * stone)
        roughness = roughness * (1 - on_top) + rng.uniform(0.55, 0.78, cell.max() + 1)[cell] * on_top
    bare = smooth(0.6, 0.78, noise(rng, scale=4, beta=2.4))
    albedo = albedo * (1 - bare[..., None] * 0.55) + soil * bare[..., None] * 0.55
    height = height * (1 - bare * 0.45)
    return save("gravel", albedo, blur(height, 0.6), 7.0, roughness)


SETS = {"siding": siding, "floor": floor, "planks": planks, "stone": stone, "shingle": shingle,
        "metal": metal, "meadow": meadow, "dirt": dirt, "fabric": fabric, "straw": straw, "macro": macro,
        "panel": panel, "carpaint": carpaint, "rug_red": rug_red, "rug_blue": rug_blue,
        "painting_lake": painting_lake, "painting_moon": painting_moon, "painting_storm": painting_storm,
        "glove": glove, "cliff": cliff, "forest_floor": forest_floor, "field": field, "gravel": gravel}


def main():
    only = list(SETS)
    preview = None
    for arg in sys.argv[1:]:
        if arg.startswith("--only="):
            only = arg[7:].split(",")
        elif arg.startswith("--preview="):
            preview = arg[10:]
    done = []
    for index, name in enumerate(SETS):
        if name in only:
            # Each set has its own dice, so building one alone gives the same result.
            result = SETS[name](np.random.default_rng(7100 + index))
            if result is not None:
                done.append((name, result))
    if preview and done:
        tile = 384
        sheet = Image.new("RGB", (tile * min(4, len(done)), tile * ((len(done) + 3) // 4)))
        for i, (name, albedo) in enumerate(done):
            im = Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).resize((tile, tile), Image.LANCZOS)
            sheet.paste(im, ((i % 4) * tile, (i // 4) * tile))
        sheet.save(preview)


if __name__ == "__main__":
    main()
