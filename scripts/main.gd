extends Node3D

## NO RETURN: STARVED ROCK — game orchestrator.
##
## Full-game structure (3–4 hours, no padding — see DESIGN.md):
##   ACT 1 — DAY: arrive, set up camp, hike the canyon trails, visit the
##     four story canyons, meet the "ranger", unease building.
##   ACT 2 — NIGHTFALL: night hits, walkies go wrong, the crash site is
##     found in Owl Canyon, the first friend disappears.
##   ACT 3 — THE HOLLOW / NO RETURN: the remaining friends disappear one
##     by one, the UFO's presence closes in, reach the truth / escape.
## This slice plays ACT 1 + ACT 2 and ends on the Act 2 cliffhanger card.
## The act system, the objective queue, and the disappearance director are
## built as reusable systems so ACT 3 extends from them, not around them.

const PlayerScene := preload("res://scenes/player.tscn")
const CompanionScene := preload("res://scenes/companion.tscn")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const DayNightScript := preload("res://scripts/day_night.gd")
const AudioSynthScript := preload("res://scripts/audio_synth.gd")
const GameUIScript := preload("res://scripts/ui.gd")

const TRIP_DATE := "NOV.14.2026"
const CANYON_TIMES := [11.0, 14.0, 17.0, 19.5] # clock after each story canyon
const STORY_INDICES := [0, 1, 2, 3] # LaSalle, French, Wildcat, Tonti
const OWL_INDEX := 4
# Act 3 objectives (full game — documented here so the slice's systems
# already know the shape of what comes next; not playable in the slice).
const ACT3_OBJECTIVES := [
	["FIND CHRIS", "He was at the fence. Now he's not."],
	["FIND HARRY", "The walkie answers in his voice. It isn't him."],
	["REACH THE TRUTH", "Get inside the craft."],
	["NO RETURN", "There is no way back. Only through."],
]

enum State { TITLE, PLAYING, PAUSED, ENDING }
enum Act { ACT1_DAY, ACT2_NIGHTFALL, ACT3_HOLLOW }

var state: int = State.TITLE
var act: int = Act.ACT1_DAY
var world: WorldBuilder
var player: Player
var companions: Array = []
var day_night: DayNight
var audio: AudioSynth
var ui: GameUI
var sun_pivot: Node3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var nv_light: SpotLight3D
var cloud_dome: MeshInstance3D
var cloud_mat: StandardMaterial3D

var player_path: Array = [] # breadcrumb trail of the player's positions
var _path_last := Vector3.ZERO
var canyons_visited := 0
var visited_flags := [false, false, false, false]
var discovered_flags: Array = []
var explored_count := 0
var camp_done := false
var sal_missing := false
var discovery_done := false
var day_discovery_toast_done := false
var figure_spawned_day := false
var figure_spawned_night := false
var figure_active := false
var walkie_cooldown := 0.0
var walkie_uses_after_loss := 0
var ending_started := false
var rumble_timer := 55.0
var truck_barked := false
var deer_barked := false
var hum_barked := false
var carcass_barked := [false, false, false]
var carcass_positions := [Vector2(-140, -88), Vector2(-152, -30), Vector2(-145, -64)] # must match world_builder.gd
var night_vision_on := false
var night_fell := false
var elapsed := 0.0

# ------------------------------------------------------------------- setup ---

func _enter_tree() -> void:
	_setup_input()

func _ready() -> void:
	randomize()
	discovered_flags.resize(18)
	discovered_flags.fill(false)
	_build_sky()
	world = WorldBuilderScript.new()
	world.name = "World"
	add_child(world)
	day_night = DayNightScript.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, sun_pivot, world_env, cloud_mat)
	day_night.set_time(8.0)
	audio = AudioSynthScript.new()
	audio.name = "Audio"
	add_child(audio)
	_spawn_player_and_friends()
	_make_triggers()
	ui = GameUIScript.new()
	ui.name = "UI"
	add_child(ui)
	ui.start_pressed.connect(_start_game)
	ui.resume_pressed.connect(_resume_game)
	ui.restart_pressed.connect(_restart_game)
	ui.quit_to_title_pressed.connect(_quit_to_title)
	ui.quit_game_pressed.connect(func() -> void: get_tree().quit())
	ui.set_clock(_format_clock())
	ui.set_objective("SET UP CAMP", "Reach the campsite")
	ui.set_explored(0, 18)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("flashlight", KEY_F)
	_add_key_action("night_vision", KEY_N)
	_add_key_action("walkie", KEY_T)
	_add_key_action("pause", KEY_ESCAPE)

func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _build_sky() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.65, 0.8, 0.95)
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.5
	# Filmic render: ACES tonemapping + glow for depth, SSAO + volumetric
	# fog where the renderer supports them (Forward+ on desktop; the web
	# Compatibility renderer ignores SSAO/volumetric fog and keeps the
	# standard fog + glow, so the game still looks right in a browser).
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.08
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.006
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.88
	environment.adjustment_contrast = 1.04
	world_env.environment = environment
	add_child(world_env)
	# Cloud dome: a big textured sphere that follows the camera (the sky
	# itself has no clouds). Unshaded, transparent, seen from inside.
	cloud_mat = StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_texture = preload("res://assets/generated/clouds.png")
	cloud_mat.albedo_color = Color(1, 1, 1, 0.9)
	cloud_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	cloud_dome = MeshInstance3D.new()
	cloud_dome.name = "CloudDome"
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 80.0
	dome_mesh.height = 160.0
	dome_mesh.radial_segments = 32
	dome_mesh.rings = 16
	cloud_dome.mesh = dome_mesh
	cloud_dome.material_override = cloud_mat
	add_child(cloud_dome)
	sun_pivot = Node3D.new()
	sun_pivot.name = "SunPivot"
	add_child(sun_pivot)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 250.0
	sun.light_energy = 1.15
	sun_pivot.add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(140.0), 0.0)
	moon.light_color = Color(0.5, 0.65, 0.9)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)

func _spawn_player_and_friends() -> void:
	player = PlayerScene.instantiate() as Player
	player.name = "Jayce"
	player.position = world.spawn_point
	add_child(player)
	player.stepped.connect(_on_player_stepped)
	_path_last = player.global_position
	player_path.append(player.global_position)
	# Camcorder night-vision light (green-tinted fill, on with NV mode).
	nv_light = SpotLight3D.new()
	nv_light.name = "NightVisionLight"
	nv_light.position = Vector3(0.1, -0.1, -0.2)
	nv_light.light_color = Color(0.45, 1.0, 0.5)
	nv_light.light_energy = 0.0
	nv_light.spot_angle = 55.0
	nv_light.spot_range = 26.0
	player.get_node("Head/Camera3D").add_child(nv_light)
	# The three friends. Sal is index 1 — the first to go.
	# Distinct looks: shirt, face, hair, height. Chris is tallest, Harry shortest.
	var defs := [
		{"name": "Chris", "shirt": Color(0.7, 0.15, 0.12), "offset": Vector3(-1.6, 0, 2.6),
			"face": "res://assets/generated/face_chris.png", "hair": "res://assets/generated/hair_short.png",
			"hair_style": 0, "hair_radius": 0.106, "height": 1.06, "path_off": 10},
		{"name": "Sal", "shirt": Color(0.12, 0.3, 0.65), "offset": Vector3(0, 0, 3.6),
			"face": "res://assets/generated/face_sal.png", "hair": "res://assets/generated/hair_curly.png",
			"hair_style": 2, "hair_radius": 0.115, "height": 1.0, "path_off": 20},
		{"name": "Harry", "shirt": Color(0.75, 0.6, 0.1), "offset": Vector3(1.6, 0, 2.6),
			"face": "res://assets/generated/face_harry.png", "hair": "res://assets/generated/hair_blond.png",
			"hair_style": 1, "hair_radius": 0.106, "height": 0.95, "path_off": 30},
	]
	for d in defs:
		var c := CompanionScene.instantiate() as Companion
		c.name = d["name"]
		var spawn: Vector3 = world.spawn_point + player.global_transform.basis * (d["offset"] as Vector3)
		spawn.y = world.ground_height_at(spawn.x, spawn.z) + 1.2
		c.position = spawn
		add_child(c)
		c.setup(d, player, d["offset"])
		c.set_path(player_path, d["path_off"])
		companions.append(c)
	# Jayce's visible hands + camcorder (first-person, not blocky).
	Humanoid.build_jayce_hands(player.get_node("Head/Camera3D"))

func _make_triggers() -> void:
	for i in range(world.canyons.size()):
		var c: Dictionary = world.canyons[i]
		var area := Area3D.new()
		area.name = "CanyonTrigger%d" % i
		area.collision_layer = 0
		area.collision_mask = 1
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = float(c["radius"]) * 0.85
		shape.shape = sphere
		area.add_child(shape)
		area.position = Vector3(c["pos"].x, float(c["floor_h"]) + 3.0, c["pos"].y)
		area.body_entered.connect(_on_canyon_entered.bind(i))
		add_child(area)
	# Discovery trigger at the crash site.
	var disc := Area3D.new()
	disc.name = "DiscoveryTrigger"
	disc.collision_layer = 0
	disc.collision_mask = 1
	var dshape := CollisionShape3D.new()
	var dsphere := SphereShape3D.new()
	dsphere.radius = 9.0
	dshape.shape = dsphere
	disc.add_child(dshape)
	disc.position = world.discovery_pos + Vector3(0, 2.0, 0)
	disc.body_entered.connect(_on_discovery_entered)
	add_child(disc)

# ------------------------------------------------------------------- flow ---

func _start_game() -> void:
	state = State.PLAYING
	ui.show_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.toast("STARVED ROCK STATE PARK — 8:00 AM", 4.0)
	_bark(0, "Park's closed, huh? Good. More park for us.")
	_bark_delayed(1, "Four canyons, one day. Let's move.", 5.0)

func _resume_game() -> void:
	state = State.PLAYING
	ui.show_pause(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _quit_to_title() -> void:
	get_tree().reload_current_scene()

func _on_canyon_entered(body: Node3D, index: int) -> void:
	if state != State.PLAYING or body != player:
		return
	var cname: String = world.canyons[index]["name"]
	# Exploration: every canyon counts toward the 18, story or not.
	if not discovered_flags[index]:
		discovered_flags[index] = true
		explored_count += 1
		ui.set_explored(explored_count, 18)
		if not STORY_INDICES.has(index):
			ui.toast("DISCOVERED — %s CANYON  (%d/18)" % [cname.to_upper(), explored_count], 3.0)
			return
	# Story canyon: advances the day.
	var story_pos := STORY_INDICES.find(index)
	if visited_flags[story_pos]:
		return
	visited_flags[story_pos] = true
	canyons_visited += 1
	ui.set_objective("CANYONS %d/4" % canyons_visited, "Visit each canyon")
	ui.toast("CANYON %d/4 — %s" % [canyons_visited, cname.to_upper()], 3.5)
	match index:
		0:
			_bark(2, "Okay, this one's actually beautiful. Worth the climb.")
		1:
			_bark(1, "This place is too quiet. Where are the birds?")
			_spawn_figure(1) # the "ranger" is standing down the trail
		2:
			_bark(0, "Did you guys hear that? ...No? Just me?")
		3:
			_bark(2, "The fence says restricted. The fence is also... open. Cool. Cool cool cool.")
	_time_skip(CANYON_TIMES[canyons_visited - 1])
	if canyons_visited >= 4:
		_night_falls()

func _time_skip(target_hour: float) -> void:
	day_night.transition_to(target_hour)
	ui.fade_to(1.0, 0.45)
	await get_tree().create_timer(0.6).timeout
	ui.fade_to(0.0, 0.6)

func _night_falls() -> void:
	if night_fell:
		return
	night_fell = true
	act = Act.ACT2_NIGHTFALL
	player.set_flashlight(true)
	ui.toast("NIGHT HAS FALLEN.", 4.0)
	_bark_delayed(1, "It's dark. Like... really dark. Flashlights, everyone.", 2.0)
	_bark_delayed(0, "We should've been back at camp an hour ago.", 7.0)
	for c in companions:
		(c as Companion).set_scared(true)
	ui.set_objective("OWL CANYON", "Reach the crash site")
	_spawn_figure(0) # the figure again, by Owl Canyon
	for spot in world.truck_lights:
		(spot as SpotLight3D).light_energy = 2.5

func _on_discovery_entered(body: Node3D) -> void:
	if state != State.PLAYING or body != player:
		return
	if day_night.is_night() and not discovery_done:
		_run_disappearance(1) # Sal — the first to go
	elif not day_discovery_toast_done:
		day_discovery_toast_done = true
		ui.toast("A CRATER. SCORCHED EARTH.", 3.5)
		_bark_delayed(0, "That's not a plane. What IS that?", 1.5)

# ------------------------------------------------- disappearance director ---
# The disappearance system: a reusable scripted beat. In the full game,
# ACT 3 runs the same sequence for Chris and Harry — only the friend, the
# place, and the last words change.

func _run_disappearance(companion_index: int) -> void:
	if discovery_done:
		return
	discovery_done = true
	var friend := companions[companion_index] as Companion
	if friend == null or not friend.visible:
		return
	# 1. The friend walks toward the craft, drawn to it.
	var walk_to := world.discovery_pos + Vector3(5.0, 0.0, 2.0)
	friend.set_manual_target(walk_to)
	friend.clear_look_target()
	ui.subtitle(friend.friend_name, "Jayce... are you seeing this?", 3.5)
	audio.set_fear(1.0)
	# Wait until they get there (or 8 s, if the path is blocked).
	var waited := 0.0
	while not friend.at_manual_target() and waited < 8.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	# 2. They stop. They turn to the camera. Last words.
	friend.clear_manual_target()
	friend.look_at_point(player.global_position)
	friend.say("Jayce... it's —")
	ui.subtitle(friend.friend_name, "Jayce... it's —", 3.0)
	audio.set_hum_level(-4.0)
	audio.play_sting2()
	for m in world.craft_lights:
		(m as StandardMaterial3D).emission_energy_multiplier = 6.0
	await get_tree().create_timer(1.4).timeout
	# 3. The flash. The static. When the picture clears, they're gone.
	audio.play_static()
	audio.play_boom()
	ui.flash()
	await get_tree().create_timer(0.5).timeout
	var last_pos := friend.global_position
	friend.visible = false
	friend.enabled_follow = false
	sal_missing = true
	# What he left behind: his walkie-talkie, on the ground.
	world.dropped_walkie.position = Vector3(last_pos.x, world.ground_height_at(last_pos.x, last_pos.z) + 0.1, last_pos.z)
	world.dropped_walkie.visible = true
	for m in world.craft_lights:
		(m as StandardMaterial3D).emission_energy_multiplier = 2.0
	ui.toast("SAL IS GONE.", 4.0)
	_bark(0, "SAL?! Sal, come in! Where did he go?!")
	await get_tree().create_timer(2.5).timeout
	_bark(2, "He was right here. He was RIGHT HERE.")
	_bark_delayed(0, "His walkie. It's just... here. On the ground.", 4.0)
	ui.set_objective("FIND SAL", "Call him on the walkie  [ T ]")

func _show_ending() -> void:
	state = State.ENDING
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.fade_to(1.0, 1.0)
	await get_tree().create_timer(1.1).timeout
	var stats := "Canyons visited: 4/4   •   Explored: %d/18   •   Time: %s   •   One friend lost" % [explored_count, _format_clock_time()]
	ui.show_ending(stats)

# ----------------------------------------------------------------- walkie ---

func _use_walkie() -> void:
	if walkie_cooldown > 0.0 or state != State.PLAYING:
		return
	walkie_cooldown = 3.0
	audio.play_squelch()
	ui.set_walkie(true, "TRANSMITTING...")
	await get_tree().create_timer(0.5).timeout
	audio.play_static()
	if sal_missing:
		walkie_uses_after_loss += 1
		if walkie_uses_after_loss == 1:
			ui.subtitle("SAL [WALKIE]", "— ...static... —", 3.0)
			ui.set_walkie(true, "NO RESPONSE — STATIC")
		else:
			_garbled_transmission()
			return
	elif day_night.is_night():
		audio.play_interference()
		var lines := [
			"— ...say again? You're breaking — ... —",
			"— ...something's on the channel... —",
			"— ...I can hear you but it's not just you... —",
		]
		ui.subtitle("CHRIS [WALKIE]", lines[randi() % lines.size()], 3.5)
		ui.set_walkie(true, "INTERFERENCE")
	else:
		var who := companions[randi() % companions.size()] as Companion
		var lines := [
			"Still alive, still hiking.",
			"Copy. All good back here.",
			"If I die on this trail I'm haunting all of you.",
			"Yeah, I hear you. Keep filming, Jayce.",
		]
		ui.subtitle(who.friend_name + " [WALKIE]", lines[randi() % lines.size()], 3.5)
		ui.set_walkie(true, "CH-04 OPEN")
	await get_tree().create_timer(2.5).timeout
	audio.play_squelch()
	ui.set_walkie(false, "")

func _garbled_transmission() -> void:
	if ending_started:
		return
	ending_started = true
	ui.set_walkie(true, "SIGNAL FOUND — ???")
	ui.subtitle("??? [WALKIE]", "— ...Jayce? —", 2.5)
	audio.play_interference()
	await get_tree().create_timer(2.8).timeout
	ui.subtitle("??? [WALKIE]", "— ...don't... come... —", 2.5)
	audio.play_static()
	await get_tree().create_timer(2.8).timeout
	ui.subtitle("??? [WALKIE]", "— ...it's... here... —", 2.5)
	audio.play_interference()
	await get_tree().create_timer(2.8).timeout
	ui.set_walkie(false, "")
	_show_ending()

# ------------------------------------------------------------------ figure ---

func _spawn_figure(spot_index: int) -> void:
	if spot_index == 1 and figure_spawned_day:
		return
	if spot_index == 0 and figure_spawned_night:
		return
	if spot_index == 1:
		figure_spawned_day = true
	else:
		figure_spawned_night = true
	world.figure.position = world.figure_spots[spot_index]
	world.figure.visible = true
	figure_active = true

func _update_figure() -> void:
	if not figure_active or world.figure == null:
		return
	var to_fig := world.figure.global_position - player.global_position
	var dist := to_fig.length()
	var cam_fwd: Vector3 = -player.get_node("Head/Camera3D").global_transform.basis.z
	var facing: float = cam_fwd.dot(to_fig.normalized())
	if dist < 18.0 or (facing > 0.93 and dist < 45.0):
		world.figure.visible = false
		figure_active = false
		audio.play_sting()
		_bark(0, "Is that a ranger? Hey! We're not supposed to— ...where'd he go?")

# ------------------------------------------------------------------ helpers ---

func _bark(index: int, text: String) -> void:
	if index < 0 or index >= companions.size():
		return
	var c := companions[index] as Companion
	if c == null or not c.visible:
		return
	c.say(text)
	ui.subtitle(c.friend_name, text, 4.0)

func _bark_delayed(index: int, text: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if state == State.PLAYING:
		_bark(index, text)

func _format_clock_time() -> String:
	var h := int(day_night.time_hours)
	var m := int((day_night.time_hours - float(h)) * 60.0)
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, ampm]

func _format_clock() -> String:
	return TRIP_DATE + "  " + _format_clock_time()

# ------------------------------------------------------------------ input ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			state = State.PAUSED
			ui.show_pause(true)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif state == State.PAUSED:
			_resume_game()
		return
	if state != State.PLAYING:
		return
	# Web builds: clicking the canvas re-captures the mouse after Esc.
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("flashlight"):
		player.set_flashlight(not player.flashlight_on)
		ui.toast("FLASHLIGHT " + ("ON" if player.flashlight_on else "OFF"), 1.2)
	elif event.is_action_pressed("night_vision"):
		night_vision_on = not night_vision_on
		nv_light.light_energy = 2.2 if night_vision_on else 0.0
		ui.set_night_vision(night_vision_on)
		ui.toast("NIGHT VISION " + ("ON" if night_vision_on else "OFF"), 1.2)
	elif event.is_action_pressed("walkie"):
		_use_walkie()

# -------------------------------------------------------------- footsteps ---

func _on_player_stepped() -> void:
	var p := player.global_position
	var surface := "dirt"
	if p.z < -146.0:
		surface = "sand"
	elif world.slope_at(p.x, p.z) > 0.55 or world.canyon_factor_at(p.x, p.z) > 0.4:
		surface = "rock"
	elif Vector2(p.x, p.z).distance_to(Vector2(world.lodge_pos.x, world.lodge_pos.z)) < 6.0:
		surface = "wood"
	elif Vector2(p.x, p.z).distance_to(Vector2(-20, -122)) < 5.0 or Vector2(p.x, p.z).distance_to(Vector2(60, -118)) < 5.0:
		surface = "wood"
	elif world.nearest_trail_dist(p.x, p.z) > 2.5:
		surface = "dirt" # forest floor reads as dirt underfoot
	audio.play_footstep(surface)

# ------------------------------------------------------------------ per-frame ---

func _process(delta: float) -> void:
	elapsed += delta
	# The cloud dome follows the camera (it is a sky, not a place).
	if cloud_dome != null and player != null:
		cloud_dome.global_position = player.global_position
	if walkie_cooldown > 0.0:
		walkie_cooldown -= delta
	if state == State.TITLE and player != null:
		player.rotate_y(0.04 * delta)
		return
	if state != State.PLAYING:
		return
	ui.set_clock(_format_clock())
	# Breadcrumb trail: record where Jayce actually walked.
	if player.global_position.distance_to(_path_last) > 0.8:
		_path_last = player.global_position
		player_path.append(_path_last)
		if player_path.size() > 800:
			player_path.pop_front()
	# Camp setup: reach the campsite, Act 1's first objective.
	if not camp_done and player.global_position.distance_to(world.campsite_pos) < 8.0:
		camp_done = true
		ui.set_objective("CANYONS 0/4", "Visit each canyon — LaSalle, French, Wildcat, Tonti")
		ui.toast("CAMP SET UP.", 3.0)
		_bark(2, "Tents up, fire later. Let's see these canyons.")
	# Discovery safety: if the player is already standing in the crash site
	# when night falls (e.g. they arrived during the time skip), the trigger
	# may have fired in "day" mode — run the disappearance anyway.
	if day_night.is_night() and not discovery_done and player.global_position.distance_to(world.discovery_pos) < 9.0:
		_run_disappearance(1)
	# Campfire flicker.
	if world.fire_light != null:
		world.fire_light.light_energy = 1.5 + sin(elapsed * 13.0) * 0.3 + sin(elapsed * 7.7) * 0.2
	# Craft lights blink + hum follows distance to the crash site.
	if world.craft_lights.size() > 0:
		for i in range(world.craft_lights.size()):
			var m := world.craft_lights[i] as StandardMaterial3D
			var on := int(elapsed * 2.0 + float(i)) % 2 == 0
			m.emission_energy_multiplier = 2.0 if on else 0.2
	if world.craft_light_ref != null:
		world.craft_light_ref.light_energy = 1.7 + sin(elapsed * 1.5) * 0.5
	var dist_crash := player.global_position.distance_to(world.discovery_pos)
	audio.set_hum_level(lerpf(-26.0, -9.0, clampf(1.0 - dist_crash / 120.0, 0.0, 1.0)))
	audio.set_crash_proximity(clampf(1.0 - dist_crash / 120.0, 0.0, 1.0))
	# Night drone fades in after dark.
	var night_f := clampf((day_night.time_hours - 18.0) / 1.5, 0.0, 1.0)
	audio.set_drone_level(lerpf(-30.0, -16.0, night_f))
	# Score tension follows the clock — and the truth.
	var tension := 0.0
	if discovery_done:
		tension = 3.0 # deliberate silence: only the hum and the heartbeat
	elif day_night.time_hours >= 18.5:
		tension = 2.0
	elif day_night.time_hours >= 16.5:
		tension = 1.0
	audio.set_tension(tension)
	# Fear: night, the figure, the crash site, and losing Sal.
	var fear := 0.0
	if day_night.is_night():
		fear = 0.3
	if dist_crash < 30.0:
		fear = maxf(fear, 0.6)
	if figure_active and player.global_position.distance_to(world.figure.global_position) < 30.0:
		fear = maxf(fear, 0.7)
	if sal_missing:
		fear = maxf(fear, 0.85)
	audio.set_fear(fear)
	# Distant rumble during the day: something is out there.
	rumble_timer -= delta
	if rumble_timer <= 0.0 and not day_night.is_night():
		rumble_timer = randf_range(45.0, 85.0)
		audio.play_rumble()
		_bark(randi() % 3, "Thunder? There's not a cloud in the sky.")
	# The hum gets loud near the crash site — the friends notice.
	if not hum_barked and dist_crash < 25.0 and not discovery_done:
		hum_barked = true
		_bark(1, "Do you hear that? That hum. It's coming from the ground.")
	# Ranger truck: bark once up close.
	if not truck_barked and player.global_position.distance_to(world.truck_pos) < 10.0:
		truck_barked = true
		_bark(0, "Ranger truck. Empty. Keys are still in it... weird.")
	# Watching deer: turns to face you; bark the first time you're close.
	if world.watching_deer != null:
		var deer := world.watching_deer
		var d := player.global_position.distance_to(deer.global_position)
		if d < 25.0:
			var to_player := (player.global_position - deer.global_position).normalized()
			var target_yaw := atan2(-to_player.x, -to_player.z)
			deer.rotation.y = lerp_angle(deer.rotation.y, target_yaw, delta * 2.0)
			if d < 9.0 and not deer_barked:
				deer_barked = true
				_bark(2, "That deer has been standing there the whole time. It hasn't moved. Not once.")
	# Carcasses: one bark each, first time close.
	for i in range(carcass_positions.size()):
		if carcass_barked[i]:
			continue
		var cp: Vector2 = carcass_positions[i]
		if Vector2(player.global_position.x, player.global_position.z).distance_to(cp) < 6.0:
			carcass_barked[i] = true
			_bark(1, "That's not a coyote kill. Look at it. That's... surgical.")
	_update_figure()
