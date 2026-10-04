# Scales textures down for the game.
# Run: blender --background --factory-startup --python blender_resize.py -- <size> <in> <out> [<in> <out> ...]
import bpy, sys

args = sys.argv[sys.argv.index("--") + 1:]
size = int(args[0])
for i in range(1, len(args) - 1, 2):
    image = bpy.data.images.load(args[i])
    before = tuple(image.size)
    if before[0] > size:
        image.scale(size, size)
    image.filepath_raw = args[i + 1]
    image.file_format = "PNG"
    image.save()
    print("RESIZED", args[i], before, "->", tuple(image.size), args[i + 1])
