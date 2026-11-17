# ASSET SOURCES — No Return: Starved Rock

Hard rule for this project: **every asset is ORIGINAL (made in code by us)
or CC0 / public domain with a verifiable permissive license.** Nothing is
ripped from other games, films, music, or the internet at large.

## Original — made by us, in this repo (no license needed)

| Asset | Where | Notes |
|---|---|---|
| All GDScript code | `scripts/` | Game logic, world generation, audio synthesis, UI |
| All 3D geometry (terrain, structures, humanoids) | `scripts/world_builder.gd`, `scripts/vegetation.gd`, `scripts/humanoid.gd`, `scenes/*.tscn` | Terrain mesh, canyons, lodge/cabins, tents, craft, props, trees, humanoid figures — built from Godot primitives (BoxMesh, CylinderMesh, SphereMesh, PrismMesh, SurfaceTool) at runtime |
| All sound effects | `scripts/audio_synth.gd` | Synthesized at startup with sine/noise generators: wind, birds, crickets, owls, footsteps (dirt/rock/sand/wood), walkie static/squelch/interference, UFO hum, heartbeat, breathing, rumbles, stingers |
| All music | `scripts/audio_synth.gd` | Original generative ambient score: day/dusk/night pad loops + sparse piano notes, scheduled by tension. No samples, no covers |
| Camcorder overlays | `scripts/ui.gd` | Film grain, scanlines, vignette generated as `ImageTexture`s at runtime |
| Game icon | `icon.svg` | Original vector (dark square, red canyon zigzag, gold bar) |
| PIL-generated textures | `assets/generated/` | Made here with PIL/numpy (no external pixels): skin + 3 procedural faces (Chris/Sal/Harry), 3 hair textures, yellow cap, UFO hull panel albedo/normal/rough (concentric rings + radial panels + rivets + scorch), water normal, waterfall streaks, cloud dome, fir twig RGBA (Poly Haven twig photo merged with its separate alpha map — see below) |

## Third-party — CC0 (public domain), Poly Haven

All of the following are from [Poly Haven](https://polyhaven.com) and are
released under the **CC0 1.0 Universal (public domain)** license — free for
any use, no attribution required. Downloaded Nov 17, 2026 via the Poly Haven
API, at 1K resolution (textures) / 1K textures (models). Verify at
https://polyhaven.com/a/&lt;slug&gt; (each asset page states CC0).

### Textures (`assets/textures/`, `assets/tree/`)

| Asset | Poly Haven slug | Used for |
|---|---|---|
| Forest ground | `forest_ground_04` | Forest-floor ground layer |
| Dead forest leaves | `forest_leaves_04` | Leaf-litter ground patches |
| Grass ground | `grass_ground` | Ground variation |
| Dirt floor | `dirt_floor` | Trail dirt |
| Rocky trail | `rocky_trail` | Trail/rock variation |
| Worn natural rock (sandstone) | `worn_rock_natural_01` | Canyon walls / bluffs |
| Pitted mossy rock | `rock_pitted_mossy` | Boulders, rock faces |
| Mossy rock | `mossy_rock` | Mossy rocks |
| Rock ground | `rock_ground` | Rock variation |
| Pine bark | `pine_bark` | Tree trunks (variant) |
| Fir bark + fir twig (+ alpha) | `fir_tree_01` (tree asset) | Fir trunks (bark diff/nor/ARM) and fir canopy twigs (diff + separate grayscale alpha, merged into `assets/generated/fir_twig_rgba.png` by us) |
| Weathered planks | `weathered_planks` | Lodge/cabin wood |
| Rusty corrugated iron | `rusty_corrugated_iron` | Cabin roofs |
| Denim fabric | `denim_fabric` | Companions' jeans |
| Cotton jersey | `cotton_jersey` | Companions' shirts / tent fabric |
| Sand | `sand_01` | Riverbank sand |
| Burned ground | `burned_ground_01` | Scorched earth at the crash site |

Each texture was downloaded as diffuse + `nor_gl` normal + `rough` (ARM)
maps where Poly Haven provides them. All normal maps are imported with
`compress/normal_map=1` (linear, no sRGB decode) and mipmaps enabled.

### Models (`assets/models/`, GLTF + 1K PBR textures)

| Asset | Poly Haven slug | Used for |
|---|---|---|
| Boulder | `boulder_01` | Canyon / trail boulders |
| Mossy rock set | `rock_moss_set_01` | Mossy rocks |
| Tree stump | `tree_stump_01` | Stumps |
| Dead tree trunk | `dead_tree_trunk` | Dead trunks / crash-site debris |
| Grass (medium) | `grass_medium_01`, `grass_medium_02` | Grass tufts |
| Fern | `fern_02` | Canyon ferns |
| Shrub | `shrub_02` | Shrubs |
| Moss | `moss_01` | Moss patches |
| Vintage video camera | `vintage_video_camera` | Jayce's camcorder (first-person view model) |

Poly Haven tree GLTFs (`fir_tree_01`, `pine_tree_01`) were **not** used as
models — their `.bin` files are 478–958 MB. Only their 1K bark/twig
textures were used; the trees themselves are procedural (MultiMesh trunks
+ crossed-quad canopies) built in `scripts/vegetation.gd`.

## Third-party — engine / bundled only

| Asset | Source | License |
|---|---|---|
| Godot Engine 4.7.2 | godotengine.org | MIT License |
| Godot default UI font | Bundled with the Godot engine | Part of the engine distribution (no separate attribution required for use in a Godot game) |
| Godot export templates (Web / macOS / Windows) | godotengine.org (official releases) | MIT License |

## Real-world names (not assets, not copyrighted)

- **Starved Rock State Park, Oglesby, Illinois** and its canyon names
  (LaSalle, French, Wildcat, Tonti, Owl, St. Louis, Kickapoo, Sac, Aurora,
  Fox, Pontiac, Basswood, Lone Tree, Hidden, Hennepin, Ottawa, Kaskaskia,
  Illinois), the Illinois River, the River Trail and Bluff Trail, Horseshoe
  Bend and Lover's Leap overlooks. Place names are facts, not copyrighted
  works. The park's official logos, branding, maps, and photos are **not**
  used anywhere in the game.
- The landscape is modelled on the park's public structure (bluffs over the
  river, 18 sandstone canyons, waterfalls, lodge/campgrounds) — no map data
  was copied from Google Maps or any other source.

## What is NOT in this game

- No music, sounds, textures, photos, fonts, or models ripped from other
  games or films (including God of War — the map *structure* is inspired by
  its hub-and-regions design, not its assets, music, or art).
- No audio or visuals from any other game or film. No stock assets beyond
  the CC0 Poly Haven items listed above.
- No ambientCG assets (ambientCG was unreachable from the build machine;
  Poly Haven covered everything).

## Title note

The working title is **"No Return: Starved Rock"**. A different
first-person horror game called "No Return" already exists on Steam
(app 1967220, Chinese-folklore hallway horror), so the subtitle keeps this
game distinct. Nothing from that game is used here.
