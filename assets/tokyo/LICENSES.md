# Tokio-Simulationshalle: Herkunft und Lizenzen der Assets

## Fremde, freie Assets (CC0)

| Dateien | Quelle | Autor | Lizenz |
|---|---|---|---|
| `cc0/asphalt_03_diff_1k.jpg`, `cc0/asphalt_03_nor_gl_1k.jpg`, `cc0/asphalt_03_rough_1k.jpg` | Poly Haven, "Asphalt 03": https://polyhaven.com/a/asphalt_03 | Poly Haven | CC0 1.0 (Public Domain), https://polyhaven.com/license |
| `cc0/concrete_floor_worn_001_diff_1k.jpg`, `cc0/concrete_floor_worn_001_nor_gl_1k.jpg`, `cc0/concrete_floor_worn_001_rough_1k.jpg` | Poly Haven, "Concrete Floor Worn 001": https://polyhaven.com/a/concrete_floor_worn_001 | Poly Haven | CC0 1.0 (Public Domain), https://polyhaven.com/license |

Verwendung: Asphalt der Straßen und Gehwege (`TK_STREET` in `scripts/tokyo_hall.gd`, Funktion `_tk_grain`).
Heruntergeladen am 24.10.2026 in 1K-Auflösung, unverändert. CC0 verlangt keine Namensnennung;
sie steht hier trotzdem. Mit `--no-cc0` startet die Halle ohne diese Texturen.

## Freie 3D-Modelle (CC0, Poly Haven)

Alle in `cc0/models/<name>/` (glTF, 1K-Texturen, unverändert), Quelle https://polyhaven.com/a/<name>, Lizenz CC0 1.0 (https://polyhaven.com/license). Verwendet in `scripts/tokyo_hall.gd` (CC0_PROPS, `_tk_cc_load`): Klimageräte an den Fassaden, Mülltonnen, Müllsäcke, Kartons, Fässer, Warnschilder und Reifen auf den Gehwegen, Zählerkästen, Sicherheitslampen und Kameras an den Hintertüren, Gullydeckel auf den Straßen. Heruntergeladen am 25.10.2026. Mit `--no-cc0` oder `--no-kit` startet die Halle ohne sie.

| Ordner | Modell |
|---|---|
| `cc0/models/metal_trash_can` | Metal Trash Can, https://polyhaven.com/a/metal_trash_can |
| `cc0/models/exterior_aircon_unit` | Exterior Aircon Unit, https://polyhaven.com/a/exterior_aircon_unit |
| `cc0/models/utility_box_01` | Utility Box 01, https://polyhaven.com/a/utility_box_01 |
| `cc0/models/utility_box_02` | Utility Box 02, https://polyhaven.com/a/utility_box_02 |
| `cc0/models/security_camera_01` | Security Camera 01, https://polyhaven.com/a/security_camera_01 |
| `cc0/models/security_light` | Security Light, https://polyhaven.com/a/security_light |
| `cc0/models/trashbag` | Trashbag, https://polyhaven.com/a/trashbag |
| `cc0/models/cardboard_box_01` | Cardboard Box 01, https://polyhaven.com/a/cardboard_box_01 |
| `cc0/models/barrel_03` | Barrel 03, https://polyhaven.com/a/barrel_03 |
| `cc0/models/WetFloorSign_01` | Wet Floor Sign 01, https://polyhaven.com/a/WetFloorSign_01 |
| `cc0/models/old_tyre` | Old Tyre, https://polyhaven.com/a/old_tyre |
| `cc0/models/water_manhole_cover` | Water Manhole Cover, https://polyhaven.com/a/water_manhole_cover |

## Nach Henrys Bildern nachgebaut

Die Wahrzeichen-Gebäude (`scripts/tokyo_landmarks.gd`) und die Werbespots (`scripts/tokyo_ads.gd`) sind vollständig im Code gebaut bzw. gezeichnet, nach Henrys Referenzbildern in `D:\Games\AI Games\Nachtwache\tokyo` (Neon-Ramenhaus, Cyberpunk-Wolkenkratzer, Sakura-Apartmenthaus, Yakitori-Gasse, Shinsekai-Tech-Tower, Yamashita-Markt, Pachinko). Keine Bilddaten daraus im Spiel. Alle Namen und Schriftzüge sind erfunden.

## Eigene Assets (von Henry erzeugt)

| Dateien | Quelle |
|---|---|
| `building_a.glb` (+ Bilder) | Henrys Gebäudemodell (Meshy) |
| `source/kit_off/window_a.glb` (nicht mehr verwendet) | `D:\Games\AI Games\Nachtwache\tokyo\Meshy_AI_SciFi_Window_Frame_...glb` |
| `source/kit_off/window_b.glb` (nicht mehr verwendet) | `fensteralt.glb` |
| `source/kit_off/window_shutter.glb` (nicht mehr verwendet) | `Meshy_AI_Industrial_Rolling_Sh_...glb` |
| `source/kit_off/door_frame.glb` (nicht mehr verwendet) | `Meshy_AI_Industrial_Portal_Fra_...glb` |
| `source/kit_off/shop_facade.glb` (nicht mehr verwendet) | `Meshy_AI_japanese_shop_facade_1025142614_texture.glb` (im Chat geschickt, Kopie in `source/japanese_shop_facade_low.glb`) |
| `source/kit_off/shop_window.glb` (nicht mehr verwendet) | `storefront.glb` |
| `source/kit_off/balcony.glb` (nicht mehr verwendet) | `Meshy_AI_Tokyo_Balcony_Module_...glb` |
| `kit/vending.glb` | `Meshy_AI_Tokyo_Vending_Machine_1025043334_...glb` |
| `source/kit_off/fence.glb` (nicht mehr verwendet) | `zaun.glb` |
| `neo_ad_claude.ogv` | im Spiel gerenderte NEO-KICK!-Werbung (`tools/make_neo_ad.ps1`) |

Seit 25.10.2026 werden Fenster, Türen, Balkone, Ladenfronten und der Zaun prozedural gebaut (`_tk_proc_front` in `scripts/tokyo_hall.gd`); die Meshy-Teile dafür liegen ungenutzt in `source/kit_off/`. Meshy wird nur noch für Kleinteile wie den Automaten verwendet.
Alle Bausatzteile baut `tools/build_tokyo_kit.sh` mit `tools/blender_kit_fix.py`: schonend reduziert
(nur wenn nötig, vor dem Verschweißen, damit die Texturnähte heil bleiben; eine `<name>_low.glb`
aus Meshy wird bevorzugt und gar nicht reduziert), Nähte verschweißt, lose Krümel entfernt, auf
echte Maße gebracht, in der Tiefe flach gedrückt, Ursprung hinten unten mittig.
Die Originale in `D:\Games\AI Games\Nachtwache\tokyo` wurden nicht verändert.
Meshy-Ausgaben gehören laut Meshy-Bedingungen dem Ersteller (bei bezahltem Plan); bitte bei
einer Veröffentlichung den eigenen Plan prüfen.
