#!/usr/bin/env python3
"""Generates the open world (3 x 3 km) into assets/world/.

    python3 tools/make_world.py [--seed=4242] [--preview=<png>]

Everything comes from the seed: a fractal relief of rolling hills with wide, flatter
valleys, a mountain ridge in the north-east whose rock breaks into bands of cliffs, hills
round the edge that frame the world; then rain: hundreds of thousands of droplets erode it,
water is routed over the filled surface (priority flood) to find where streams and rivers
run and where hollows hold lakes, and their beds are cut into the ground. Last the masks
that say what grows where. Writes:

    height.r32   heights in metres, float32, WORLD_SAMPLES x WORLD_SAMPLES, rows from north
                 to south (z), columns from west to east (x); the world is centred on 0
    normal.png   surface normals (x, z in red and blue, up in green), 2048 x 2048
    splat.png    red: rock, green: forest (floor and trees), blue: wet ground and banks,
                 alpha: open fields in the lowland; 2048 x 2048
    trees.bin    the trees: x, y, z, turn, size, kind as float32 sixes (kinds: 0-2 firs,
                 3-4 broad-leaved, 5 dead)
    water.r32    float32 water level every 3 m (1025 x 1025), -1000 where it is dry
    world.json   size, spacing, height range, rivers (points x, z, water level, width),
                 lakes (level, bounds), a place to start
    map.png      a coloured relief of it all, for the map in the game

Needs numpy, scipy and Pillow. Deterministic for a seed.
"""
import heapq
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "world")
SIZE = 3072.0
SAMPLES = 2049
SPACING = SIZE / (SAMPLES - 1)
# The coarser grid the relief is shaped, eroded and drained on (3 m).
WORK = 1025
WORK_SPACING = SIZE / (WORK - 1)


def spectral(rng, n, beta, low, cut=None):
    """Fractal noise with a 1/f^beta spectrum, mean 0 and spread 1. `cut`: the number of
    waves across the map above which it fades out (real ground is smooth at small scales;
    without it the slopes come from the finest ripples alone)."""
    white = rng.standard_normal((n, n))
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(np.maximum(f, low), beta * 0.5)
    amp[0, 0] = 0.0
    if cut is not None:
        amp *= np.exp(-(f / cut) ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    out -= out.mean()
    return out / out.std()


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def relief(rng):
    n = WORK
    v, u = np.mgrid[0:n, 0:n] / (n - 1.0)
    # Gently warped coordinates, so that hills do not line up.
    warp_u = spectral(rng, n, 3.0, 2.0, 8) * 0.03
    warp_v = spectral(rng, n, 3.0, 2.0, 8) * 0.03
    def warped(field):
        return ndimage.map_coordinates(field, [np.clip((v + warp_v) * (n - 1), 0, n - 1), np.clip((u + warp_u) * (n - 1), 0, n - 1)], order=1)
    macro = warped(spectral(rng, n, 3.4, 1.5, 9))
    hills = warped(spectral(rng, n, 2.3, 5.0, 40))
    ridge_noise = warped(spectral(rng, n, 2.7, 3.0, 22))
    # Ridges in two octaves, the finer one strongest where the coarse one is high (a ridged
    # multifractal), and broken up by a slow swell so that no ridge runs on unchanged.
    first = (1.0 - np.minimum(np.abs(ridge_noise) * 0.7, 1.0)) ** 2.0
    second = (1.0 - np.minimum(np.abs(warped(spectral(rng, n, 2.5, 8.0, 45))) * 0.7, 1.0)) ** 2.0
    swell = smooth(-1.2, 1.0, spectral(rng, n, 3.0, 2.0, 7))
    ridged = (first * 0.75 + first * second * 0.5) * (0.35 + 0.65 * swell)
    # The mountains stand in the north-east; elsewhere only a hint of them.
    mountains = np.exp(-(((u - 0.76) / 0.3) ** 2 + ((v - 0.24) / 0.27) ** 2))
    mountains = np.clip(mountains * 1.15 + spectral(rng, n, 3.0, 2.0, 8) * 0.08, 0.0, 1.0)
    h = 62.0 + 30.0 * macro + 7.0 * hills + 105.0 * ridged * mountains + 18.0 * ridged * (1.0 - mountains) * 0.4
    # Lowlands are wider and flatter than the hills: room for fields and villages.
    low = 66.0
    h = np.where(h < low, low - (low - h) * 0.55, h)
    # Here and there in the mountains the rock breaks off: a few scarps where the ground
    # drops more steeply, wherever a slow noise crosses a level.
    scarp_noise = spectral(rng, n, 2.8, 3.0, 16)
    scarp = smooth(0.0, 0.08, scarp_noise) - 0.5
    h = h + scarp * 11.0 * mountains * smooth(0.3, 0.7, swell)
    # The land falls a little towards the south-west, where the water leaves the world.
    h = h + (1.0 - u) * -14.0 + v * -22.0
    return h.astype(np.float64), mountains


def erode(h, rng, drops, steps, batch):
    """Droplets that run downhill, carry soil away and set it down where they slow."""
    n = h.shape[0]
    inertia, capacity_k, min_slope = 0.15, 1.2, 0.01
    erode_k, deposit_k, evaporate, gravity = 0.25, 0.25, 0.03, 4.0
    done = 0
    while done < drops:
        count = min(batch, drops - done)
        done += count
        px = rng.uniform(2, n - 3, count)
        py = rng.uniform(2, n - 3, count)
        dx = np.zeros(count)
        dy = np.zeros(count)
        speed = np.ones(count)
        water = np.ones(count)
        sediment = np.zeros(count)
        alive = np.ones(count, bool)
        for _ in range(steps):
            change = np.zeros_like(h)
            ix = px.astype(np.int64)
            iy = py.astype(np.int64)
            fx = px - ix
            fy = py - iy
            h00 = h[iy, ix]
            h10 = h[iy, ix + 1]
            h01 = h[iy + 1, ix]
            h11 = h[iy + 1, ix + 1]
            gx = (h10 - h00) * (1 - fy) + (h11 - h01) * fy
            gy = (h01 - h00) * (1 - fx) + (h11 - h10) * fx
            here = h00 * (1 - fx) * (1 - fy) + h10 * fx * (1 - fy) + h01 * (1 - fx) * fy + h11 * fx * fy
            dx = dx * inertia - gx * (1 - inertia)
            dy = dy * inertia - gy * (1 - inertia)
            length = np.sqrt(dx * dx + dy * dy)
            still = length < 1e-9
            if still.any():
                angle = rng.uniform(0, 2 * np.pi, still.sum())
                dx[still] = np.cos(angle)
                dy[still] = np.sin(angle)
                length[still] = 1.0
            dx /= length
            dy /= length
            nx = px + dx
            ny = py + dy
            alive &= (nx > 1) & (nx < n - 2) & (ny > 1) & (ny < n - 2)
            nx = np.clip(nx, 1, n - 2.001)
            ny = np.clip(ny, 1, n - 2.001)
            jx = nx.astype(np.int64)
            jy = ny.astype(np.int64)
            gx2 = nx - jx
            gy2 = ny - jy
            there = h[jy, jx] * (1 - gx2) * (1 - gy2) + h[jy, jx + 1] * gx2 * (1 - gy2) + h[jy + 1, jx] * (1 - gx2) * gy2 + h[jy + 1, jx + 1] * gx2 * gy2
            dh = there - here
            capacity = np.maximum(-dh, min_slope) * speed * water * capacity_k
            uphill = dh > 0
            full = sediment > capacity
            deposit = np.where(uphill, np.minimum(dh, sediment), np.where(full, (sediment - capacity) * deposit_k, 0.0))
            take = np.where(~uphill & ~full, np.minimum((capacity - sediment) * erode_k, -dh), 0.0)
            amount = np.clip(deposit - take, -0.12, 0.12) * alive
            sediment = sediment + (take - deposit) * alive
            for wx, wy, ox, oy in ((1 - fx, 1 - fy, 0, 0), (fx, 1 - fy, 1, 0), (1 - fx, fy, 0, 1), (fx, fy, 1, 1)):
                np.add.at(change, (iy + oy, ix + ox), amount * wx * wy)
            speed = np.minimum(np.sqrt(np.maximum(speed * speed - dh * gravity, 0.0)), 4.0)
            water *= (1 - evaporate)
            px, py = nx, ny
            # Spread what was moved a little, so that it leaves gullies, not pits; the
            # ground changes at every step, so that droplets see each other's work.
            h += ndimage.gaussian_filter(change, 1.0)
        print("  erosion %d / %d droplets" % (done, drops), flush=True)
    return h


def drain(h):
    """Fills every hollow to its spill point (priority flood from the edge) and routes the
    water over that surface: where each cell drains to, and how much water gathers."""
    n = h.shape[0]
    filled = h.copy()
    done = np.zeros_like(h, bool)
    lumps = ndimage.gaussian_filter(np.random.default_rng(7).standard_normal(h.shape), 12.0)
    lumps = (lumps - lumps.min()) / (lumps.max() - lumps.min())
    cost = (2e-5 * (1.0 + 60.0 * lumps ** 3)).tolist()
    heap = []
    for i in range(n):
        for j in (0, n - 1):
            for (a, b) in ((i, j), (j, i)):
                if not done[a, b]:
                    done[a, b] = True
                    heapq.heappush(heap, (filled[a, b], a, b))
    offsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    order = []
    flat = filled.tolist()
    seen = done.tolist()
    while heap:
        level, a, b = heapq.heappop(heap)
        order.append((a, b))
        for da, db in offsets:
            c, d = a + da, b + db
            if 0 <= c < n and 0 <= d < n and not seen[c][d]:
                seen[c][d] = True
                # A tiny slope over filled flats, so that water still finds its way out:
                # uneven, so that it winds over them instead of running straight.
                value = max(flat[c][d], level + cost[c][d])
                flat[c][d] = value
                heapq.heappush(heap, (value, c, d))
    filled = np.array(flat)
    # Each cell drains into its lowest neighbour on the filled surface.
    pad = np.pad(filled, 1, constant_values=-1e9)
    best = np.full((n, n), np.inf)
    target = np.zeros((n, n, 2), np.int64)
    rows, cols = np.mgrid[0:n, 0:n]
    for da, db in offsets:
        neighbour = pad[1 + da:1 + da + n, 1 + db:1 + db + n]
        drop = (neighbour - filled) / (np.sqrt(da * da + db * db))
        better = drop < best
        best = np.where(better, drop, best)
        target[..., 0] = np.where(better, rows + da, target[..., 0])
        target[..., 1] = np.where(better, cols + db, target[..., 1])
    flow = np.ones(n * n)
    down_a = target[..., 0].ravel()
    down_b = target[..., 1].ravel()
    # From the highest cell down, each hands its water on.
    for a, b in reversed(order):
        k = a * n + b
        c, d = down_a[k], down_b[k]
        if 0 <= c < n and 0 <= d < n:
            flow[c * n + d] += flow[k]
    return filled, flow.reshape(n, n), target


def spill(h):
    """The level water would stand at on every cell: each hollow filled to where it spills
    over (priority flood from the edge, flat filled)."""
    n = h.shape[0]
    level = h.tolist()
    seen = [[False] * n for _ in range(n)]
    heap = []
    for i in range(n):
        for (a, b) in ((i, 0), (i, n - 1), (0, i), (n - 1, i)):
            if not seen[a][b]:
                seen[a][b] = True
                heapq.heappush(heap, (level[a][b], a, b))
    while heap:
        value, a, b = heapq.heappop(heap)
        for da, db in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            c, d = a + da, b + db
            if 0 <= c < n and 0 <= d < n and not seen[c][d]:
                seen[c][d] = True
                if level[c][d] < value:
                    level[c][d] = value
                heapq.heappush(heap, (level[c][d], c, d))
    return np.array(level)


def rivers_from(filled, flow, target, spacing):
    """Traces streams and rivers from where enough water has gathered down to the edge or
    into a larger river. Returns polylines of (row, col, catchment in km2)."""
    n = filled.shape[0]
    area = flow * spacing * spacing / 1e6
    stream = area > 0.16
    lines = []
    taken = np.zeros_like(stream)
    # Sources: stream cells whose upstream neighbours are not streams.
    upstream = np.zeros_like(flow)
    ta = target[..., 0].ravel()
    tb = target[..., 1].ravel()
    inside = (ta >= 0) & (ta < n) & (tb >= 0) & (tb < n)
    s = stream.ravel()
    np.add.at(upstream.ravel(), (ta[inside & s] * n + tb[inside & s]), 1)
    sources = np.argwhere(stream & (upstream == 0))
    # Longest first, so that rivers are traced whole and tributaries end on them.
    sources = sorted(sources.tolist(), key=lambda rc: -filled[rc[0], rc[1]])
    for a, b in sources:
        points = []
        while 0 <= a < n and 0 <= b < n:
            points.append((a, b, area[a, b]))
            if taken[a, b] and len(points) > 1:
                break
            taken[a, b] = True
            a, b = target[a, b]
        if len(points) > 12:
            lines.append(points)
    return lines


def chaikin(points, rounds=3):
    pts = np.array(points, float)
    for _ in range(rounds):
        if len(pts) < 3:
            break
        q = pts[:-1] * 0.75 + pts[1:] * 0.25
        r = pts[:-1] * 0.25 + pts[1:] * 0.75
        mid = np.empty((len(q) * 2, pts.shape[1]))
        mid[0::2] = q
        mid[1::2] = r
        pts = np.vstack([pts[:1], mid, pts[-1:]])
    return pts


def main():
    seed = 4242
    preview = None
    for arg in sys.argv[1:]:
        if arg.startswith("--seed="):
            seed = int(arg[7:])
        elif arg.startswith("--preview="):
            preview = arg[10:]
    rng = np.random.default_rng(seed)
    print("relief", flush=True)
    work, mountains = relief(rng)
    def slopes(h, spacing):
        gz, gx = np.gradient(h, spacing)
        s = np.sqrt(gx * gx + gz * gz)
        return "slope median %.3f, 90%% %.3f, 99%% %.3f" % (np.median(s), np.percentile(s, 90), np.percentile(s, 99))
    print("relief " + slopes(work, WORK_SPACING), flush=True)
    if "--fast" not in sys.argv:
        print("erosion", flush=True)
        work = erode(work, rng, drops=480000, steps=40, batch=40000)
        print("eroded " + slopes(work, WORK_SPACING), flush=True)
    print("water", flush=True)
    # The water finds its way over a slightly unsettled copy of the ground, so that
    # it winds over the flats instead of running in straight lines.
    wander = ndimage.gaussian_filter(rng.standard_normal(work.shape), 7.0)
    broad = ndimage.gaussian_filter(rng.standard_normal(work.shape), 22.0)
    unsettled = work + wander / wander.std() * 1.2 + broad / broad.std() * 2.2
    filled, flow, target = drain(unsettled)
    filled = np.maximum(filled - (unsettled - work), work)
    # Of the hollows the flood filled, a few of a fair size stay lakes; the others are
    # filled with silt up to their spill point and become flat valley floors.
    hollow = (filled - work) > 1.5
    labels, count = ndimage.label(hollow)
    sizes = ndimage.sum(hollow, labels, range(1, count + 1)) * WORK_SPACING * WORK_SPACING
    candidates = [i + 1 for i in np.argsort(-sizes) if 9000.0 < sizes[i] < 260000.0]
    keep = candidates[:3]
    lake_work = np.isin(labels, keep)
    silt = hollow & ~lake_work
    work = np.where(silt, filled - ndimage.gaussian_filter(rng.standard_normal(work.shape), 4.0) * 0.15 - 0.05, work)
    print("kept %d of %d hollows as lakes" % (len(keep), count), flush=True)
    lines = rivers_from(filled, flow, target, WORK_SPACING)
    # Up to the full resolution, with a little fine relief on top.
    print("detail", flush=True)
    zoom = (SAMPLES - 1) / (WORK - 1)
    height = ndimage.zoom(work, zoom, order=3)[:SAMPLES, :SAMPLES]
    fine = spectral(rng, SAMPLES, 2.0, 60.0, 500)
    height += fine * 0.35
    fill_full = ndimage.zoom(filled, zoom, order=1)[:SAMPLES, :SAMPLES]
    # Rivers: smooth lines in metres with a width and a water level that only falls.
    print("rivers", flush=True)
    rivers = []
    centre = np.zeros(height.shape, bool)
    level_at = np.zeros(height.shape)
    width_at = np.zeros(height.shape)
    for line in lines:
        raw = np.array([(b * WORK_SPACING, a * WORK_SPACING, c) for a, b, c in line], float)
        # A gliding average takes the corners of the grid out of the line (ends stay).
        if len(raw) > 9:
            soft = raw.copy()
            soft[:, :2] = ndimage.uniform_filter1d(raw[:, :2], 9, axis=0, mode="nearest")
            soft[0], soft[-1] = raw[0], raw[-1]
            raw = soft
        pts = chaikin(raw, 3)
        # About every 4 m.
        keep = [0]
        travelled = 0.0
        for i in range(1, len(pts)):
            travelled += np.hypot(*(pts[i, :2] - pts[i - 1, :2]))
            if travelled >= 4.0 or i == len(pts) - 1:
                keep.append(i)
                travelled = 0.0
        pts = pts[keep]
        out = []
        last = 1e9
        for x, z, catchment in pts:
            c = min(SAMPLES - 1, max(0, int(round(x / SPACING))))
            r = min(SAMPLES - 1, max(0, int(round(z / SPACING))))
            width = float(np.clip(3.0 + 7.5 * np.sqrt(catchment), 3.0, 26.0))
            level = min(last, float(fill_full[r, c]) - 0.55)
            last = level
            out.append([float(x - SIZE / 2), float(z - SIZE / 2), level, width])
        rivers.append(out)
        # Their middle lines on the grid, with what each point carries.
        for i in range(len(out) - 1):
            ax, az, al, aw = out[i]
            bx, bz, bl, bw = out[i + 1]
            steps = int(np.hypot(bx - ax, bz - az) / (SPACING * 0.5)) + 1
            for t in np.linspace(0, 1, steps):
                c = int(round((ax + (bx - ax) * t + SIZE / 2) / SPACING))
                r = int(round((az + (bz - az) * t + SIZE / 2) / SPACING))
                if 0 <= r < SAMPLES and 0 <= c < SAMPLES:
                    centre[r, c] = True
                    level_at[r, c] = al + (bl - al) * t
                    width_at[r, c] = aw + (bw - aw) * t
    distance, (near_r, near_c) = ndimage.distance_transform_edt(~centre, return_indices=True)
    distance = distance * SPACING
    level = level_at[near_r, near_c]
    width = width_at[near_r, near_c]
    half = width * 0.5
    depth = 0.9 + width * 0.07
    bed = np.where(distance <= half, level - depth * (1.0 - (distance / np.maximum(half, 0.1)) ** 2), level + 0.25 + (distance - half) * 0.32)
    # The valley sides ease into the untouched land.
    carved = np.minimum(height, bed)
    height = height + (carved - height) * smooth(half + 45.0, half + 18.0, distance)
    water_mask = distance <= half
    # Where water stands and how high (river levels first, lakes added below; -1000 is dry).
    surface = np.where(distance <= half + 1.5, level, -1000.0)
    # Lakes: where water stands on the finished ground. Its hollows are flooded to their
    # spill points; those of a fair size and depth are lakes, the small ones are filled with
    # silt. (So that every lake lies in a basin with a shore all round, also where a river
    # was cut through it.)
    print("lakes", flush=True)
    coarse = height[::2, ::2]
    brim = spill(coarse)
    standing = (brim - coarse) > 0.05
    labels, count = ndimage.label(standing)
    lakes = []
    lake_work = np.zeros_like(standing)
    silt_work = np.zeros_like(standing)
    # The ten largest that are deep enough; a lake in every dip would be too many.
    areas = ndimage.sum(standing, labels, range(1, count + 1)) * WORK_SPACING * WORK_SPACING
    depths = ndimage.maximum(brim - coarse, labels, range(1, count + 1))
    chosen = set(int(i) + 1 for i in np.argsort(-areas) if areas[i] >= 15000.0 and depths[i] > 2.0)
    chosen = set(sorted(chosen, key=lambda i: -areas[i - 1])[:10])
    for index in range(1, count + 1):
        cells = labels == index
        if index in chosen:
            lake_work |= cells
            rows, cols = np.nonzero(cells)
            lakes.append({"level": float(brim[cells].mean()), "bounds": [float(cols.min() * WORK_SPACING - SIZE / 2 - 10), float(rows.min() * WORK_SPACING - SIZE / 2 - 10), float(cols.max() * WORK_SPACING - SIZE / 2 + 10), float(rows.max() * WORK_SPACING - SIZE / 2 + 10)]})
        else:
            silt_work |= cells
    up = lambda a: ndimage.zoom(a.astype(float), zoom, order=0)[:SAMPLES, :SAMPLES] > 0.5
    brim_full = ndimage.zoom(brim, zoom, order=1)[:SAMPLES, :SAMPLES]
    silt_full = up(ndimage.binary_dilation(silt_work, iterations=1))
    height = np.where(silt_full, np.maximum(height, brim_full - 0.03), height)
    lake_mask = up(lake_work) & (height < brim_full - 0.02)
    surface = np.where(up(ndimage.binary_dilation(lake_work, iterations=2)) & (height < brim_full + 0.3), np.maximum(surface, brim_full), surface)
    print("%d lakes, %d hollows silted" % (len(lakes), count - len(lakes)), flush=True)
    # Masks.
    print("masks", flush=True)
    gz, gx = np.gradient(height, SPACING)
    slope = np.sqrt(gx * gx + gz * gz)
    normal = np.stack([-gx, np.ones_like(gx), -gz], -1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    rock = smooth(0.62, 1.05, slope)
    rock = np.maximum(rock, smooth(0.45, 0.8, slope) * ndimage.zoom(mountains, zoom, order=1)[:SAMPLES, :SAMPLES])
    water_any = water_mask | lake_mask
    to_water = ndimage.distance_transform_edt(~water_any) * SPACING
    wet = smooth(9.0, 0.0, to_water) * (1 - rock)
    clusters = ndimage.zoom(spectral(rng, WORK, 2.5, 3.0, 40), zoom, order=1)[:SAMPLES, :SAMPLES]
    detail = ndimage.zoom(spectral(rng, WORK, 1.8, 20.0, 160), zoom, order=1)[:SAMPLES, :SAMPLES]
    lowland = smooth(78.0, 64.0, height) * smooth(0.12, 0.03, slope)
    forest_score = clusters * 0.9 + detail * 0.25 + slope * 1.2 + (height - 80.0) / 60.0 - lowland * 1.3
    forest = smooth(0.15, 0.55, forest_score) * (1 - rock * 0.9) * smooth(6.0, 16.0, to_water)
    fields = lowland * (1 - forest) * smooth(14.0, 30.0, to_water)
    def to8(a):
        return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    os.makedirs(OUT, exist_ok=True)
    height.astype("<f4").tofile(os.path.join(OUT, "height.r32"))
    crop = slice(0, SAMPLES - 1)
    Image.fromarray(to8(normal[crop, crop] * 0.5 + 0.5)[..., [0, 1, 2]], "RGB").save(os.path.join(OUT, "normal.png"))
    splat = np.stack([to8(rock), to8(forest), to8(np.maximum(wet, water_any * 1.0)), to8(fields)], -1)[crop, crop]
    Image.fromarray(splat, "RGBA").save(os.path.join(OUT, "splat.png"))
    surface[::2, ::2].astype("<f4").tofile(os.path.join(OUT, "water.r32"))
    # Trees: in the forest close together and mixed (firs on the heights, broad-leaved
    # trees lower down, a few dead ones), in the open now and then one alone; none on rock,
    # in the water or right at its edge.
    print("trees", flush=True)
    cell = 5.5
    grid = int(SIZE / cell)
    gv, gu = np.mgrid[0:grid, 0:grid]
    tx = (gu + rng.uniform(0.1, 0.9, gu.shape)) * cell
    tz = (gv + rng.uniform(0.1, 0.9, gv.shape)) * cell
    tc = np.clip((tx / SPACING).astype(int), 0, SAMPLES - 1)
    tr = np.clip((tz / SPACING).astype(int), 0, SAMPLES - 1)
    # Out in the open: copses and lines of trees along a slow noise, rarely one alone.
    copse = smooth(0.62, 0.8, ndimage.zoom(spectral(rng, WORK, 2.2, 6.0, 90), zoom, order=1)[:SAMPLES, :SAMPLES] * 0.25 + 0.5)
    density = forest[tr, tc] * 0.82 + copse[tr, tc] * 0.35 * (1 - forest[tr, tc]) + 0.0025
    density *= (rock[tr, tc] < 0.35) & (to_water[tr, tc] > 7.0) & (slope[tr, tc] < 1.1)
    placed = rng.uniform(0, 1, gu.shape) < density
    tx, tz, tr, tc = tx[placed], tz[placed], tr[placed], tc[placed]
    ty = height[tr, tc]
    high = smooth(70.0, 140.0, ty)
    roll = rng.uniform(0, 1, len(tx))
    kind = np.where(roll < 0.04, 5, np.where(rng.uniform(0, 1, len(tx)) < 0.25 + high * 0.6, rng.integers(0, 3, len(tx)), rng.integers(3, 5, len(tx))))
    size = rng.uniform(0.75, 1.3, len(tx)) * np.where(kind >= 3, 0.95, 1.0)
    turn = rng.uniform(0, 2 * np.pi, len(tx))
    trees = np.stack([tx - SIZE / 2, ty, tz - SIZE / 2, turn, size, kind.astype(float)], -1).astype("<f4")
    trees.tofile(os.path.join(OUT, "trees.bin"))
    # A place to start: on open, gentle ground in the south-west lowland, looking north-east.
    score = (1 - forest) * (1 - rock) * smooth(0.12, 0.02, slope) * (to_water > 30)
    v, u = np.mgrid[0:SAMPLES, 0:SAMPLES] / (SAMPLES - 1.0)
    score *= np.exp(-(((u - 0.32) / 0.12) ** 2 + ((v - 0.66) / 0.12) ** 2))
    # With no tree within 30 m, so that the first view is open.
    stand = np.zeros((SAMPLES, SAMPLES))
    stand[np.clip(((trees[:, 2] + SIZE / 2) / SPACING).astype(int), 0, SAMPLES - 1), np.clip(((trees[:, 0] + SIZE / 2) / SPACING).astype(int), 0, SAMPLES - 1)] = 1.0
    score *= ndimage.maximum_filter(stand, size=41) < 0.5
    r, c = np.unravel_index(np.argmax(score), score.shape)
    start = [float(c * SPACING - SIZE / 2), float(height[r, c]), float(r * SPACING - SIZE / 2)]
    info = {"seed": seed, "size": SIZE, "samples": SAMPLES, "spacing": SPACING,
            "height_min": float(height.min()), "height_max": float(height.max()),
            "rivers": rivers, "lakes": lakes, "start": start,
            "forest_share": float((forest > 0.5).mean()), "rock_share": float((rock > 0.5).mean()),
            "trees": int(len(trees))}
    with open(os.path.join(OUT, "world.json"), "w") as f:
        json.dump(info, f, separators=(",", ":"))
    # The map: hill shading, green forest, grey rock, blue water, pale fields.
    light = np.clip(normal[..., 0] * -0.45 + normal[..., 1] * 0.75 + normal[..., 2] * -0.45, 0, 1)
    base = np.stack([0.42 + 0.0 * light, 0.5 + 0.0 * light, 0.3 + 0.0 * light], -1)
    tint = (height - height.min()) / (height.max() - height.min())
    base = base * (0.75 + tint[..., None] * 0.5)
    base = base * (1 - fields[..., None]) + np.array([0.72, 0.68, 0.45]) * fields[..., None]
    base = base * (1 - forest[..., None] * 0.8) + np.array([0.16, 0.3, 0.14]) * forest[..., None] * 0.8
    base = base * (1 - rock[..., None]) + np.array([0.55, 0.53, 0.5]) * rock[..., None]
    base = base * (0.45 + 0.75 * light[..., None])
    base = np.where(water_any[..., None], np.array([0.2, 0.38, 0.55]), base)
    contour = (np.mod(height, 10.0) < 0.35) & (slope < 2.0)
    base = np.where(contour[..., None], base * 0.82, base)
    Image.fromarray(to8(base[crop, crop])).resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, "map.png"))
    if preview:
        Image.fromarray(to8(base[crop, crop])).resize((1024, 1024), Image.LANCZOS).save(preview)
    print("WORLD heights %.1f..%.1f m, %d rivers, %d lakes, forest %.0f%%, rock %.0f%%, %d trees, start %s" % (height.min(), height.max(), len(rivers), len(lakes), info["forest_share"] * 100, info["rock_share"] * 100, len(trees), [round(v, 1) for v in start]))


if __name__ == "__main__":
    main()
