# NO RETURN: STARVED ROCK — Design (full game, 3–4 hours)

Target length: **3–4 hours total. Short, straight to the point, and good.
No padding, no filler.** Every objective moves the story or the dread
forward; anything that exists only to fill time gets cut.

## The arc

Four college friends — Chris, Sal, Harry, and Jayce (the player, holding
the camcorder) — leave college for a camping trip in Starved Rock State
Park. The park was supposed to be closed. They go in anyway, determined to
hike every trail to every canyon. They find something they were never
supposed to find: a crashed UFO. After that, people start disappearing one
by one. There is no return.

Escalation, as designed: at first they think it's a camp police officer /
ranger (they're so far out, that's the only explanation that makes sense),
then after strange sounds and things happening they think someone is hunting
them — but it's much worse.

## Act structure

### ACT 1 — DAY (~60–75 min, full game)
*Arrive, set up camp, hike the canyon trails, visit the canyons, meet the
"ranger" misdirection, unease building.*

- Arrive at the closed gate, walk past it. Empty parking lot, shuttered
  lodge. Set up camp at the campground hub.
- Open exploration (semi-open, God of War structure): the campground/lodge
  hub with connected regions — the 18 canyons, the forest, the River Trail
  and the Bluff Trail. Day is for exploring; the map feels big and free.
- Unease seeded early: distant sounds (thunder with no clouds), animals
  acting wrong (the deer that never moves), slaughtered animals (surgical,
  no visible wounds), the empty ranger truck with the keys still in it, a
  ranger sighting that turns out to be nothing.
- The four story canyons (LaSalle, French, Wildcat, Tonti) advance the clock
  toward sunset. The other fourteen canyons are there to find — exploration
  is rewarded with discoveries, not chores.
- Ends as the sun sets and the group realizes they're too far out to get
  back before dark.

### ACT 2 — NIGHTFALL (~45–60 min, full game)
*Night hits, walkie-talkies go wrong, the crash site is found, things
escalate, the first friend disappears.*

- Night falls. Flashlight, camcorder night vision, fog, the forest going
  quiet where animals should be.
- The walkie-talkie frequency starts acting wrong: static, voices cutting
  in and out, something else on the channel.
- The group pushes on to Owl Canyon — the far, remote canyon — and finds
  the crash site: scorched trees, a crater, the craft itself.
- The first disappearance (Sal): a scripted beat, not a despawn. He walks
  toward the craft, turns to the camera, and is gone. His walkie-talkie is
  left on the ground.
- The walkie answers in static — then in a voice that isn't quite his.
- Ends on the cliffhanger: one friend gone, three left, and the thing in
  the canyon knows they're here.

### ACT 3 — THE HOLLOW / NO RETURN (~60–75 min, full game)
*The remaining friends disappear one by one, the UFO's presence closes in,
the player must reach the truth / escape — a tight finale, not a grind.*

- The remaining disappearances (Chris, then Harry) run the same scripted
  system as Sal's — each one a real beat with its own place and last words.
- The UFO's presence closes in: the hum follows the player, the frequency
  gets worse, the figure is seen more often and closer.
- The player must reach the truth: get inside the craft. A tight finale,
  not a grind — every objective is the story moving forward.
- Clear ending. No endless wandering, no filler collectibles.

## What the slice covers

The slice plays **Act 1 + Act 2** (arrival → camp → four story canyons →
night → crash site → Sal's disappearance → ending card). Expected slice
playtime: **~15–25 minutes** (see README).

## Systems built for extension (not one-offs)

- **Act system** (`main.gd`, `Act` enum): the game knows which act it is;
  objectives, tension, and audio follow the act.
- **Objective queue**: objectives are data (title + detail), advanced by
  events. Act 3's objectives are already listed in `main.gd`
  (`ACT3_OBJECTIVES`).
- **Disappearance director** (`main.gd`, `_run_disappearance`): a reusable
  scripted beat — walk toward the craft, stop, turn to camera, last words,
  flash, gone, dropped walkie-talkie. Act 3 calls the same function for
  Chris and Harry.
- **Day/night + tension**: the clock drives the sun, the fog, the score
  (day/dusk/night pads), the wildlife (birds by day, crickets by night,
  silence near the crash site), and the fear level (heartbeat/breathing).
- **Semi-open map**: the hub (campground/lodge) + 18 canyon regions +
  River/Bluff trails. New regions extend by adding canyon defs and trail
  polylines in `world_builder.gd` — no code changes to the terrain system.

## Pacing rules (from Jaylen)

- Day = open exploring. Night = tension closes in. The canyons, dense
  forest, and fog limit sightlines so the horror never gets lost in the
  open map.
- Every objective moves the story or the dread forward. Cut anything that
  exists just to fill time.
- 3–4 hours total for the full game. The slice is the opening arc, not a
  demo of a grind.
