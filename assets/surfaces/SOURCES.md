# Surface textures

Generated with the built-in Imagegen tool for Nachtwache. The 1024px wood material is used selectively on furniture, exposed beams and railings; architectural walls, wooden floors and the yard keep their original procedural finish. Concrete remains active, with shared textures and distinct wall, floor and stair finishes. The earth source is retained here but is no longer assigned to the yard. Normal and roughness maps are prepared offline with `tools/build_surface_maps.gd`; the game uses mipmaps and anisotropic filtering, without displacement geometry.

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
