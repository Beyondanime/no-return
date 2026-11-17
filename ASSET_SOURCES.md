# ASSET SOURCES — No Return: Starved Rock

Hard rule for this project: **every asset is ORIGINAL (made in code by us)
or CC0 / public domain with a verifiable permissive license.** Nothing is
ripped from other games, films, music, or the internet at large.

## Original — made by us, in this repo (no license needed)

| Asset | Where | Notes |
|---|---|---|
| All GDScript code | `scripts/` | Game logic, world generation, audio synthesis, UI |
| All 3D geometry | `scripts/world_builder.gd`, `scenes/*.tscn` | Terrain mesh, canyons, lodge/cabins, tents, craft, props — built from Godot primitives (BoxMesh, CylinderMesh, SphereMesh, PrismMesh) at runtime |
| All sound effects | `scripts/audio_synth.gd` | Synthesized at startup with sine/noise generators: wind, birds, crickets, owls, footsteps (dirt/rock/sand/wood), walkie static/squelch/interference, UFO hum, heartbeat, breathing, rumbles, stingers |
| All music | `scripts/audio_synth.gd` | Original generative ambient score: day/dusk/night pad loops + sparse piano notes, scheduled by tension. No samples, no covers |
| Camcorder overlays | `scripts/ui.gd` | Film grain, scanlines, vignette generated as `ImageTexture`s at runtime |
| Game icon | `icon.svg` | Original vector (dark square, red canyon zigzag, gold bar) |

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

- No music, sounds, textures, photos, fonts, or models downloaded from the
  internet (including freesound.org — everything is synthesized instead).
- No audio or visuals from any other game or film (including God of War —
  the map *structure* is inspired by its hub-and-regions design, not its
  assets, music, or art).
- No stock assets of any kind.

## Title note

The working title is **"No Return: Starved Rock"**. A different
first-person horror game called "No Return" already exists on Steam
(app 1967220, Chinese-folklore hallway horror), so the subtitle keeps this
game distinct. Nothing from that game is used here.
