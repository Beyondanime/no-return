# NO RETURN: STARVED ROCK

A first-person found-footage horror slice, built in **Godot 4.7.2**.
Four college friends — Chris, Sal, Harry, and Jayce (you, holding the
camcorder) — hike into Starved Rock State Park after hours. The park was
supposed to be closed. They find a crashed UFO. Then people start to
disappear.

Full-game design (3 acts, 3–4 hours): see [DESIGN.md](DESIGN.md).
Asset sources and the copyright rule: see [ASSET_SOURCES.md](ASSET_SOURCES.md).

## Play the slice

**Web (recommended — no install, works on Mac and iPhone browsers):**
open `build/web/index.html` in a browser (or serve the `build/web/`
folder with any static host — the export has thread support off, so no
special server headers are needed). Click the game to capture the mouse.
If the mouse is released (Esc), click the game again to re-capture it.

**macOS:** open `build/macos/NoReturnStarvedRock.app`. The build is
unsigned (no paid Apple Developer account), so macOS Gatekeeper will
block the first launch — right-click the app and choose **Open**, then
confirm. That is expected for an unsigned build.

**Windows:** run `build/windows/NoReturnStarvedRock.exe`
(`NoReturnStarvedRock.pck` must sit next to it).

**From the editor:** open the project in Godot 4.7 and press Play, or run
`godot --headless --editor --import` to verify it loads cleanly.

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Look (click the game to capture the mouse) |
| Shift | Sprint |
| Space | Jump |
| F | Flashlight |
| N | Night vision (camcorder) |
| T | Walkie-talkie (press to talk to the group) |
| Esc | Pause |

Touch controls are not built yet — on iPhone the web build loads and
plays with a keyboard, but there is no virtual joystick in this slice.

## What happens in the slice (~15–25 minutes)

1. **Arrive** at Starved Rock State Park, 8:00 AM. Walk past the chained,
   CLOSED gate. Set up camp at the campground.
2. **Day — Act 1:** hike the trails and visit the four story canyons —
   LaSalle, French, Wildcat, Tonti. Each visit moves the clock toward
   sunset. The other fourteen real canyons (Owl, St. Louis, Kickapoo, Sac,
   Aurora, Fox, Pontiac, Basswood, Lone Tree, Hidden, Hennepin, Ottawa,
   Kaskaskia, Illinois) are there to discover — the HUD tracks
   EXPLORED x/18. Unease builds: a ranger sighting, a deer that never
   moves, slaughtered animals, an empty ranger truck.
3. **Night — Act 2:** darkness, fog, the walkie-talkie frequency going
   wrong. Reach Owl Canyon and find the crash site: scorched trees, a
   crater, the craft.
4. **The disappearance:** Sal walks toward the craft, turns to the camera,
   and is gone. His walkie-talkie is left on the ground. Call him on the
   walkie (T) — and hear what answers.
5. **Ending card:** "TO BE CONTINUED — Act 3: The Hollow."

## The map

Semi-open, God of War structure: a central hub (campground / lodge /
parking lot) with connected regions — 18 sandstone canyons, the Illinois
River along the north edge, the sandstone bluffs above it, the River Trail
and the Bluff Trail, overlooks (Horseshoe Bend, Lover's Leap), waterfalls
in nine canyons. Day is for open exploring; at night the darkness, fog,
and canyons close the sightlines in and the tension takes over.

## Sound & music (all original)

Everything is synthesized in code (`scripts/audio_synth.gd`) — no audio
files, nothing ripped. Forest ambience (wind, leaves, birds by day,
crickets and owls by night), footsteps on dirt / rock / sand / wood,
walkie-talkie static + squelch + UFO interference, the low hum near the
crash site, heartbeat and breathing when scared, scare stingers, and an
original generative ambient score (low drones, sparse piano notes) that
builds toward night — and drops to deliberate silence after the discovery.

## Project structure

```
no-return/
  project.godot            Godot 4.7 project ("No Return: Starved Rock")
  export_presets.cfg       Web / macOS / Windows Desktop presets
  icon.svg                 Original game icon
  ASSET_SOURCES.md         Every asset + its license (all original/CC0)
  DESIGN.md                Full-game 3-act design, 3–4 hour target
  README.md                This file
  scenes/
    main.tscn              Root scene (main.gd)
    player.tscn            Jayce — first-person controller + camcorder
    companion.tscn         Chris / Sal / Harry — distinct looks, walk/idle animation
  scripts/
    main.gd                Orchestrator: acts, objectives, disappearances, walkie
    world_builder.gd       Starved Rock: terrain, 18 canyons, trails, lodge, crash site
    player.gd              FPS controller (WASD, sprint, jump, flashlight, footsteps)
    companion.gd           Friends: breadcrumb following, animation, reactions
    day_night.gd           Sun/moon/sky/fog from the game clock
    audio_synth.gd         All sound + generative score, synthesized at startup
    ui.gd                  Title, camcorder HUD, pause, ending
```

## Build / verify

```bash
# Import check (headless, no errors expected):
~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --import --path ~/workspace/no-return

# Exports (templates already installed):
~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --export-release "Web" ~/workspace/no-return/build/web/index.html --path ~/workspace/no-return
~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --export-release "macOS" ~/workspace/no-return/build/macos/NoReturnStarvedRock.app --path ~/workspace/no-return
~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --export-release "Windows Desktop" ~/workspace/no-return/build/windows/NoReturnStarvedRock.exe --path ~/workspace/no-return
```

Godot 4.7.2 binary: `~/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64`
Export templates: `~/.local/share/godot/export_templates/4.7.2.stable/`

## Placeholder vs final

- **Final for the slice:** Starved Rock terrain + 18 canyons + trails +
  lodge/cabins/campground + river/bluffs + waterfalls + UFO crash site +
  carcasses + watching deer + ranger truck + camcorder HUD + walkie-talkie
  + Sal's scripted disappearance + title/pause/ending + full procedural
  soundscape and generative score.
- **Placeholder:** the "ranger" figure (a misdirection, swappable later);
  the monster/mystery beyond the UFO itself is not yet defined; companion
  AI is follow + barks (no combat, no inventory); touch controls not built;
  Act 3 is a design outline, not playable content.
