# Paints the wear of the Tokyo vehicles (v0.91, after Henry's retouched pictures of them:
# worn paint with scratches, grime, rust spots, panel seams and rivets, little dents) as
# tileable textures, laid on the paint of every vehicle by scripts/vehicle_kit.gd
# (triplanar, so the models need no unwrapping):
#   assets/tokyo/vehicles/wear_albedo.png  multiplied into the paint (heavy: cars, wrecks)
#   assets/tokyo/vehicles/wear_light.png   the same, a third as strong (the newer bus)
#   assets/tokyo/vehicles/wear_normal.png  seams, scratches, rivets, dents (OpenGL, +Y up)
#   assets/tokyo/vehicles/wear_rough.png   how matt each spot is (multiplies the roughness)
#
#   blender --background --factory-startup --python tools/make_vehicle_wear.py -- [--size 1024] [--seed 7]
#
# One tile is about 1.6 m of the car (VehicleKit.WEAR_TILE). Made with numpy; everything
# wraps round the edges, so the tiles meet without a seam.
import bpy, sys, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "tokyo", "vehicles")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


N = int(arg("--size", "1024"))
rng = np.random.default_rng(int(arg("--seed", "7")))


def noise(scale, power=1.0):
    """Smooth tileable noise 0..1: white noise filtered round the wave length `scale` px."""
    white = rng.standard_normal((N, N))
    fy = np.fft.fftfreq(N)[:, None]
    fx = np.fft.rfftfreq(N)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    keep = np.exp(-(f * scale) ** 2 * 4.0) * (f > 0)
    out = np.fft.irfft2(np.fft.rfft2(white) * keep, s=(N, N))
    out = (out - out.min()) / (out.max() - out.min())
    return out ** power


def line(img, x0, y0, x1, y1, value, width=1, mode="min"):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 1
    xs = np.linspace(x0, x1, steps)
    ys = np.linspace(y0, y1, steps)
    for w in range(width):
        xi = (np.round(xs + w * 0.7).astype(int)) % N
        yi = (np.round(ys + w * 0.7).astype(int)) % N
        if mode == "min":
            img[yi, xi] = np.minimum(img[yi, xi], value)
        else:
            img[yi, xi] = np.maximum(img[yi, xi], value)


def save(name, rgb, colour=True):
    img = bpy.data.images.new(name, N, N, alpha=False)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    rgba = np.ones((N, N, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(rgb, 0.0, 1.0)
    img.pixels.foreach_set(rgba[::-1].ravel())
    path = os.path.abspath(os.path.join(OUT, name + ".png"))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("WROTE", path)


# How dirty and worn each spot is (0 clean .. 1).
grime = noise(90.0, 1.6) * 0.75 + noise(14.0) * 0.25
grime = np.clip((grime - 0.35) * 1.6, 0.0, 1.0)
speck = (noise(1.6) > 0.72).astype(float) * noise(30.0)
# Rust: a few spots with a brown halo, more where it is dirty.
rust_field = noise(40.0) * 0.6 + grime * 0.4
rust = np.clip((rust_field - 0.6) * 5.0, 0.0, 1.0)
halo = np.clip((rust_field - 0.52) * 4.0, 0.0, 1.0) - rust

# Scratches: many fine ones, some deep (to the primer and the metal), mostly level.
scratch = np.ones((N, N))
deep = np.zeros((N, N))
made = 0
while made < 700:
    x, y = rng.uniform(0, N, 2)
    # (Scratches gather where it is worn anyway.)
    if rng.random() > 0.15 + grime[int(y), int(x)]:
        continue
    made += 1
    ang = rng.normal(0.0, 0.5) if rng.random() < 0.7 else rng.uniform(0, np.pi)
    length = rng.uniform(8, 110)
    dx, dy = np.cos(ang) * length, np.sin(ang) * length
    if rng.random() < 0.06:
        line(scratch, x, y, x + dx, y + dy, rng.uniform(0.45, 0.6), 2)
        line(deep, x, y, x + dx, y + dy, 1.0, 2, "max")
    else:
        line(scratch, x, y, x + dx, y + dy, rng.uniform(0.84, 0.93), 1)
# Chipped paint: small dark flakes.
chips = (noise(3.0) > 0.86).astype(float) * (grime > 0.25)

# Panel seams with rivets along them (irregular, like welded plates).
seams = np.zeros((N, N))
rivets = np.zeros((N, N))
yy, xx = np.mgrid[0:N, 0:N]
for y in (int(N * 0.03), int(N * 0.52)):
    line(seams, 0, y, N, y + rng.uniform(-3, 3), 1.0, 2, "max")
    for x in range(0, N, N // 24):
        d = (xx - x) ** 2 + (yy - (y + 9)) ** 2
        rivets = np.maximum(rivets, np.clip(1.0 - d / 9.0, 0, 1))
for x in (int(N * 0.11), int(N * 0.47), int(N * 0.79)):
    line(seams, x, 0, x + rng.uniform(-3, 3), N, 1.0, 2, "max")
    for y in range(0, N, N // 24):
        d = (xx - (x + 9)) ** 2 + (yy - y) ** 2
        rivets = np.maximum(rivets, np.clip(1.0 - d / 9.0, 0, 1))

# Colour (multiplied into the paint): grime darkens and browns a little, rust brown-orange,
# scratches and chips show the grey primer, seams a dark line.
shade = 1.0 - grime * 0.32 - speck * 0.12 - seams * 0.45 - chips * 0.4
shade = np.minimum(shade, scratch)
rgb = np.stack([shade, shade * 0.985, shade * 0.95], axis=-1)
rgb[:, :, 2] -= grime * 0.05
rust_colour = np.array([0.55, 0.30, 0.16])
halo_colour = np.array([0.80, 0.62, 0.48])
rgb = rgb * (1 - halo[..., None] * 0.5) + halo[..., None] * 0.5 * halo_colour * shade[..., None]
rgb = rgb * (1 - rust[..., None]) + rust[..., None] * rust_colour * (0.8 + 0.2 * noise(4.0))[..., None]
save("wear_albedo", rgb)
light = 1.0 - (1.0 - rgb) * 0.35
save("wear_light", light)

# Relief: dents (soft), seams and scratches cut in, rivets standing out, rust rough.
height = noise(120.0) * 2.0 + noise(25.0) * 0.4 - seams * 1.5 - deep * 1.0 - (1.0 - scratch) * 0.6 + rivets * 1.6 + rust * noise(2.0) * 0.8
gx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
gy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
k = 1.6
nx, ny, nz = -gx * k, gy * k, np.ones_like(gx)
length = np.sqrt(nx * nx + ny * ny + nz * nz)
save("wear_normal", np.stack([nx / length * 0.5 + 0.5, ny / length * 0.5 + 0.5, nz / length * 0.5 + 0.5], axis=-1), False)

# Roughness factor: clean paint glossy (0.55), grime and rust matt (1.0), scratches dull.
rough = np.clip(0.55 + grime * 0.35 + rust * 0.45 + (1.0 - scratch) * 0.5 + speck * 0.1, 0.0, 1.0)
save("wear_rough", np.stack([rough] * 3, axis=-1), False)
