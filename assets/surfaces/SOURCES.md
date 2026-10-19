# Surface textures

Generated with the built-in Imagegen tool for Nachtwache. The 1024px wood material is used directly on furniture, exposed beams and railings; on the farm of mission 1 it is also the base of the walls, floors and planks (see Farm surfaces below), while mission 2 keeps its procedural finish. Concrete remains active, with shared textures and distinct wall, floor and stair finishes. The earth source is the base of the farm's meadow and dirt tracks. Normal and roughness maps are prepared offline with `tools/build_surface_maps.gd`; the game uses mipmaps and anisotropic filtering, without displacement geometry.

Each material has three saved assets in this directory:

| Material | Albedo | Normal | Roughness |
|---|---|---|---|
| Wood | `wood_albedo.png` | `wood_normal.png` | `wood_roughness.png` |
| Concrete | `concrete_albedo.png` | `concrete_normal.png` | `concrete_roughness.png` |
| Earth | `earth_albedo.png` | `earth_normal.png` | `earth_roughness.png` |

The following are the exact generation prompts for the three albedo sources.

## wood

Use case: photorealistic-natural. Asset type: seamless square PBR albedo texture for a realistic first-person survival game. Output a single 1024x1024 flat material texture, orthographic straight-on capture with totally even diffuse illumination, no directional shadows, no perspective, no vignette, no frame, no text. Make all four edges tile seamlessly and keep detail uniformly distributed. Rich sharp microstructure, natural restrained contrast, no blurry regions, no baked specular highlights. Material: aged oak wood used on farmhouse interior walls and floors, dense elongated grain flowing vertically, occasional modest knots and fine natural fissures, weathered brown and grey fibres, tiny dents. A continuous wood surface, not a board layout: no plank gaps or regular grid. Preserve fine woody fibres at close range without exaggerated black lines.

## concrete

Use case: photorealistic-natural. Asset type: seamless square PBR albedo texture for a realistic first-person survival game. Output a single 1024x1024 flat material texture, orthographic straight-on capture with totally even diffuse illumination, no directional shadows, no perspective, no vignette, no frame, no text. Make all four edges tile seamlessly and keep detail uniformly distributed. Rich sharp microstructure, natural restrained contrast, no blurry regions, no baked specular highlights. Material: old poured basement concrete, neutral mid grey, small aggregate, fine pores and pinholes, scattered shallow hairline cracks and tiny chips. Restrained irregular mineral variation and natural mottling, tactile stone grit. No large structural breaks, no repeated tile grid, no graffiti, no walls or room view.

## earth

Use case: photorealistic-natural. Asset type: seamless square PBR albedo texture for a realistic first-person survival game. Output a single 1024x1024 flat material texture, orthographic straight-on capture with totally even diffuse illumination, no directional shadows, no perspective, no vignette, no frame, no text. Make all four edges tile seamlessly and keep detail uniformly distributed. Rich sharp microstructure, natural restrained contrast, no blurry regions, no baked specular highlights. Material: compacted farmyard earth, warm neutral dark brown soil, many small grey and brown pebbles embedded into the surface, fine grains, tiny clods and shallow unevenness, occasional short dry plant fibres. Real ground material, not a landscape. No large rocks, grass clumps, footprints or isolated focal objects.

## Farm surfaces (mission 1)

`assets/surfaces/farm/` holds the surfaces of the farm: siding, panel (inner face of the walls), floor, planks, stone, shingle, metal, carpaint, meadow, dirt, fabric and straw, each with `_albedo`, `_normal` (OpenGL) and `_roughness`, plus `macro.png` (large blotches that break up repeats). The same script draws the pictures that are laid on with ordinary UVs: the Persian rugs `rug_red` and `rug_blue` (albedo and normal) and the oil paintings `painting_lake`, `painting_moon` and `painting_storm`. They are built by `tools/make_farm_surfaces.py` (numpy, scipy, Pillow): the wood, earth and concrete sets above are their base, everything else is tileable noise and cell patterns. The build is deterministic; rerun it after changing the script. The game lays them on in world space with `scripts/farm_surface.gdshader`, which also makes the open wet in the rain (see `CabinMap._build_farm_materials`). Their imports use VRAM compression with mipmaps, and normal compression for the normal maps: textures loaded from code are never detected as 3D by the editor.

Furniture, lamps and tools of the farm also come as models from Poly Haven (CC0) in `assets/models/polyhaven/`, placed by `CabinMap._model`; see the licence file there.
