extends Node3D
class_name WorldBuilder

## NO RETURN: STARVED ROCK — procedural park.
##
## The map is a semi-open, God-of-War-style hub-and-regions layout modelled
## on Starved Rock State Park (Oglesby, Illinois): the Illinois River along
## the north edge, sandstone bluffs above it, the lodge / campground hub near
## the south entrance, and 18 real named sandstone canyons branching off the
## trail network (River Trail along the river, Bluff Trail along the rim).
## The UFO crash site is in Owl Canyon — the far, remote canyon.
##
## Everything is generated in code: heightmap terrain (hills + bluff ridge +
## river valley + 18 carved slot canyons + flattened trails), vertex colors,
## and low-poly primitive props. No imported assets.

const SIZE := 360.0
const GRID := 181
const STEP := 2.0
const RIVER_Y := 0.9

# Canyon defs: name, segment a->b (south->north), width, depth, story?, waterfall?
# Order matters: [0..3] are the four story canyons, [4] is Owl (crash site),
# [5..17] are the other thirteen real Starved Rock canyons.
const CANYON_DEFS := [
	["LaSalle", Vector2(-55, -55), Vector2(-60, -105), 16.0, 16.0, true, true],
	["French", Vector2(18, -60), Vector2(22, -108), 14.0, 15.0, true, true],
	["Wildcat", Vector2(85, -35), Vector2(108, -80), 14.0, 16.0, true, true],
	["Tonti", Vector2(-110, -25), Vector2(-135, -68), 15.0, 17.0, true, true],
	["Owl", Vector2(-148, 0), Vector2(-158, -55), 13.0, 22.0, false, true],
	["St. Louis", Vector2(-138, 55), Vector2(-148, 15), 12.0, 13.0, false, true],
	["Kickapoo", Vector2(140, 10), Vector2(150, -35), 12.0, 13.0, false, false],
	["Sac", Vector2(-95, 95), Vector2(-100, 55), 11.0, 12.0, false, false],
	["Aurora", Vector2(55, 15), Vector2(60, -25), 12.0, 13.0, false, true],
	["Fox", Vector2(120, 60), Vector2(130, 20), 11.0, 12.0, false, false],
	["Pontiac", Vector2(95, 95), Vector2(100, 60), 11.0, 12.0, false, false],
	["Basswood", Vector2(-40, 70), Vector2(-45, 30), 11.0, 12.0, false, false],
	["Lone Tree", Vector2(60, 110), Vector2(70, 75), 11.0, 12.0, false, false],
	["Hidden", Vector2(-75, -10), Vector2(-80, -50), 10.0, 14.0, false, false],
	["Hennepin", Vector2(140, -70), Vector2(155, -100), 12.0, 14.0, false, false],
	["Ottawa", Vector2(-5, 20), Vector2(0, -25), 12.0, 13.0, false, true],
	["Kaskaskia", Vector2(-120, 100), Vector2(-125, 60), 11.0, 12.0, false, true],
	["Illinois", Vector2(150, 70), Vector2(160, 30), 11.0, 12.0, false, true],
]

# Trail network: named polylines the flattening + footstep systems use.
const TRAIL_DEFS := {
	"entrance": [Vector2(0, 170), Vector2(0, 150), Vector2(0, 138), Vector2(0, 120)],
	"hub": [Vector2(0, 120), Vector2(0, 100)],
	"ascent": [Vector2(0, 100), Vector2(-15, 60), Vector2(5, 20), Vector2(-5, -30), Vector2(0, -70), Vector2(0, -95)],
	"bluff": [Vector2(-155, -95), Vector2(150, -95)],
	"river": [Vector2(-165, -155), Vector2(165, -155)],
	"descent": [Vector2(0, -95), Vector2(0, -125), Vector2(0, -155)],
	"lasalle": [Vector2(0, -80), Vector2(-30, -70), Vector2(-55, -60), Vector2(-58, -100)],
	"french": [Vector2(10, -85), Vector2(20, -70), Vector2(21, -100)],
	"wildcat": [Vector2(70, -95), Vector2(90, -60), Vector2(100, -75)],
	"tonti": [Vector2(-60, -95), Vector2(-90, -60), Vector2(-120, -50), Vector2(-128, -62)],
	"owl": [Vector2(-150, -95), Vector2(-152, -55), Vector2(-150, -20), Vector2(-155, -48)],
	"stlouis": [Vector2(-100, -95), Vector2(-125, -55), Vector2(-143, 30)],
	"aurora": [Vector2(30, -95), Vector2(50, -50), Vector2(58, -10)],
	"hidden": [Vector2(-40, -90), Vector2(-60, -50), Vector2(-78, -30)],
	"hennepin": [Vector2(130, -95), Vector2(145, -80), Vector2(150, -90)],
	"lonetree": [Vector2(30, 100), Vector2(55, 95), Vector2(65, 85)],
	"basswood": [Vector2(-10, 90), Vector2(-30, 80), Vector2(-42, 50)],
	"sac": [Vector2(-40, 100), Vector2(-70, 80), Vector2(-97, 70)],
	"kaskaskia": [Vector2(-60, 110), Vector2(-95, 85), Vector2(-122, 75)],
	"fox": [Vector2(60, 100), Vector2(95, 85), Vector2(125, 40)],
	"pontiac": [Vector2(40, 110), Vector2(70, 100), Vector2(97, 75)],
	"kickapoo": [Vector2(110, -95), Vector2(135, -50), Vector2(145, -10)],
	"illinois": [Vector2(120, 100), Vector2(140, 85), Vector2(152, 55), Vector2(158, 40)],
}

var canyons: Array = []
var trails: Dictionary = TRAIL_DEFS
var spawn_point := Vector3.ZERO
var campsite_pos := Vector3.ZERO
var discovery_pos := Vector3.ZERO
var lodge_pos := Vector3.ZERO
var figure: Node3D
var figure_spots: Array = []
var fire_light: OmniLight3D
var craft_lights: Array = []
var craft_light_ref: OmniLight3D
var truck_lights: Array = []
var truck_pos := Vector3.ZERO
var watching_deer: Node3D
var dropped_walkie: Node3D

var _noise: FastNoiseLite
var _noise2: FastNoiseLite
var _trail_pts := PackedVector3Array()
var _trail_cells := {}

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.012
	_noise.seed = 1337
	_noise2 = FastNoiseLite.new()
	_noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise2.frequency = 0.004
	_noise2.seed = 777
	_build_canyon_data()
	_build_trail_samples()
	_build_terrain()
	_build_river()
	_build_structures()
	_build_props()
	_build_crash_site()
	_build_animals()
	_build_figure()
	spawn_point = Vector3(0, ground_height_at(0, 150) + 1.2, 150)
	campsite_pos = Vector3(0, ground_height_at(0, 100) + 0.5, 100)
	lodge_pos = Vector3(-18, ground_height_at(-18, 118), 118)
	var owl: Dictionary = canyons[4]
	discovery_pos = Vector3(owl["b"].x, float(owl["floor_h"]) + 0.5, owl["b"].y)
	figure_spots = [
		Vector3(-140, ground_height_at(-140, -62) + 0.2, -62),
		Vector3(25, ground_height_at(25, -70) + 0.2, -70),
		Vector3(-30, ground_height_at(-30, 20) + 0.2, 20),
	]

# ------------------------------------------------------------- heightfield ---

func _base_height(x: float, z: float) -> float:
	# Rolling forested hills.
	var h := 12.0 + _noise.get_noise_2d(x, z) * 5.0 + _noise2.get_noise_2d(x, z) * 7.0
	# Rim hills around the map edges (not in the river strip).
	var r := Vector2(x, z).length()
	var river_mask := 1.0 - smoothstep(150.0, 165.0, -z)
	h += smoothstep(145.0, 178.0, r) * 26.0 * river_mask
	# The sandstone bluff band above the river (z -95..-140), dropping to the river.
	var n := -z
	var bluff := smoothstep(95.0, 118.0, n) * (1.0 - smoothstep(138.0, 152.0, n))
	h += bluff * 20.0
	# River valley floor.
	h = lerpf(h, 0.5, smoothstep(148.0, 158.0, n))
	return h

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()

func _canyon_factor(x: float, z: float, c: Dictionary) -> float:
	# 0 outside the canyon, 1 at its floor centre.
	var d := _dist_to_segment(Vector2(x, z), c["a"], c["b"])
	return clampf(1.0 - d / float(c["width"]), 0.0, 1.0)

func _build_canyon_data() -> void:
	for def in CANYON_DEFS:
		var a: Vector2 = def[1]
		var b: Vector2 = def[2]
		var mid := (a + b) * 0.5
		var floor_h := maxf(_base_height(mid.x, mid.y) - float(def[4]), 1.0)
		var w := float(def[3])
		var bb := Rect2(
			Vector2(minf(a.x, b.x) - w, minf(a.y, b.y) - w),
			Vector2(absf(b.x - a.x) + w * 2.0, absf(b.y - a.y) + w * 2.0))
		canyons.append({
			"name": def[0], "a": a, "b": b, "width": w, "depth": float(def[4]),
			"story": def[5], "waterfall": def[6],
			"pos": mid, "radius": maxf((b - a).length() * 0.5, w),
			"floor_h": floor_h, "bbox": bb,
		})

func _height_no_trail(x: float, z: float) -> float:
	var h := _base_height(x, z)
	for c in canyons:
		var cd: Dictionary = c
		if not (cd["bbox"] as Rect2).has_point(Vector2(x, z)):
			continue
		var f := _canyon_factor(x, z, cd)
		if f > 0.0:
			h = lerpf(h, float(cd["floor_h"]), smoothstep(0.08, 1.0, f))
	return h

func _build_trail_samples() -> void:
	# Dense samples along every trail, heights smoothed along the trail so
	# the path reads as a walked ramp (down the bluff, into the canyons).
	for key in TRAIL_DEFS.keys():
		var pts: Array = TRAIL_DEFS[key]
		var raw: Array = []
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg_len := a.distance_to(b)
			var steps := int(seg_len / 2.0)
			for s in range(steps + 1):
				var p := a.lerp(b, float(s) / float(max(1, steps)))
				raw.append(Vector3(p.x, _height_no_trail(p.x, p.y), p.y))
		# Two passes of a 1-2-3-2-1 moving average.
		for _pass in range(2):
			var sm := raw.duplicate()
			for i in range(raw.size()):
				var acc := 0.0
				var wsum := 0.0
				for k in range(-2, 3):
					var j := clampi(i + k, 0, raw.size() - 1)
					var w := 3.0 - absf(float(k))
					acc += (raw[j] as Vector3).y * w
					wsum += w
				sm[i] = Vector3((raw[i] as Vector3).x, acc / wsum, (raw[i] as Vector3).z)
			raw = sm
		for p in raw:
			var idx := _trail_pts.size()
			_trail_pts.append(p)
			var cell := Vector2i(int(floor(p.x / 8.0)), int(floor(p.z / 8.0)))
			if not _trail_cells.has(cell):
				_trail_cells[cell] = []
			(_trail_cells[cell] as Array).append(idx)

func _nearest_trail(x: float, z: float) -> Dictionary:
	var best := -1
	var best_d := 999.0
	var cx := int(floor(x / 8.0))
	var cz := int(floor(z / 8.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := Vector2i(cx + dx, cz + dz)
			if not _trail_cells.has(cell):
				continue
			for idx in (_trail_cells[cell] as Array):
				var p: Vector3 = _trail_pts[idx]
				var d := Vector2(x - p.x, z - p.z).length()
				if d < best_d:
					best_d = d
					best = idx
	return {"index": best, "dist": best_d}

func ground_height_at(x: float, z: float) -> float:
	return height_at(x, z)

func height_at(x: float, z: float) -> float:
	var h := _height_no_trail(x, z)
	var near := _nearest_trail(x, z)
	if near["index"] >= 0 and float(near["dist"]) < 5.0:
		var tp: Vector3 = _trail_pts[int(near["index"])]
		var blend := smoothstep(5.0, 1.5, float(near["dist"])) * 0.9
		h = lerpf(h, tp.y, blend)
	return h

func slope_at(x: float, z: float) -> float:
	var e := 1.5
	var dx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var dz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return Vector2(dx, dz).length()

func nearest_trail_dist(x: float, z: float) -> float:
	return float(_nearest_trail(x, z)["dist"])

func canyon_factor_at(x: float, z: float) -> float:
	var best := 0.0
	for c in canyons:
		var cd: Dictionary = c
		if not (cd["bbox"] as Rect2).has_point(Vector2(x, z)):
			continue
		best = maxf(best, _canyon_factor(x, z, cd))
	return best

# ---------------------------------------------------------------- terrain ---

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array = []
	var colors: Array = []
	var hmap := PackedFloat32Array()
	var half := SIZE * 0.5
	for gz in range(GRID):
		for gx in range(GRID):
			var x := -half + float(gx) * STEP
			var z := -half + float(gz) * STEP
			var h := height_at(x, z)
			verts.append(Vector3(x, h, z))
			colors.append(_vertex_color(x, z))
			hmap.append(h)
	# Triangles, winding (a,d,b),(a,c,d) so faces point +Y.
	for gz in range(GRID - 1):
		for gx in range(GRID - 1):
			var a := gz * GRID + gx
			var b := a + 1
			var c := a + GRID
			var d := c + 1
			for tri in [[a, d, b], [a, c, d]]:
				for vi in tri:
					st.set_color(colors[vi])
					st.add_vertex(verts[vi])
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	# Collision: HeightMapShape3D — the right tool for a regular grid.
	# The shape is centered on the body; scale (2,1,2) maps its 1-unit
	# cells to the 2 m grid. Data is row-major: row = z, column = x.
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = GRID
	shape.map_depth = GRID
	shape.map_data = hmap
	col.shape = shape
	col.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(col)
	add_child(body)

func _vertex_color(x: float, z: float) -> Color:
	var h := height_at(x, z)
	var sl := slope_at(x, z)
	var cf := canyon_factor_at(x, z)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(x * 13.7 + z * 7.3)) + 5
	var jitter := rng.randf_range(-0.03, 0.03)
	# Scorched earth around the crash site (Owl Canyon north end).
	var owl: Dictionary = canyons[4]
	var dcrash := Vector2(x - owl["b"].x, z - owl["b"].y).length()
	if dcrash < 14.0:
		return Color(0.08 + jitter, 0.07 + jitter, 0.06 + jitter)
	# River sand.
	if z < -146.0:
		return Color(0.62 + jitter, 0.55 + jitter, 0.42 + jitter)
	# Trail dirt.
	if nearest_trail_dist(x, z) < 1.6:
		return Color(0.42 + jitter, 0.32 + jitter, 0.22 + jitter)
	# Sandstone on steep slopes and canyon walls.
	if sl > 0.55 or cf > 0.55:
		var t := clampf(sl, 0.0, 1.0)
		return Color(0.72 + jitter, 0.58 + jitter * 0.5, 0.4 + jitter * 0.5).lerp(Color(0.5, 0.38, 0.26), t * 0.4)
	# Forest floor: dark moss green, lighter on high ground.
	var g := 0.16 + clampf(h / 60.0, 0.0, 1.0) * 0.08
	return Color(0.1 + jitter, g + jitter, 0.08 + jitter)

func _build_river() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.32, 0.5, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.25
	mat.metallic_specular = 0.6
	var plane := MeshInstance3D.new()
	plane.name = "IllinoisRiver"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SIZE, 40.0)
	plane.mesh = mesh
	plane.material_override = mat
	plane.position = Vector3(0, RIVER_Y, -162)
	add_child(plane)

# ---------------------------------------------------------------- helpers ---

func _mat(color: Color, rough := 0.9, metallic := 0.0, emission := Color(0, 0, 0, 0), emission_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if emission_e > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_e
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0, rot_x := 0.0, rot_z := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(rot_x, rot_y, rot_z)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, r_top: float, r_bot: float, height: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, scale_y := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale.y = scale_y
	parent.add_child(mi)
	return mi

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _label(parent: Node3D, pos: Vector3, text: String, size := 32, color := Color(0.92, 0.9, 0.8), yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 1)
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l

func _sign(parent: Node3D, pos: Vector2, lines: String, yaw := 0.0, board_color := Color(0.35, 0.25, 0.14)) -> void:
	var gy := ground_height_at(pos.x, pos.y)
	_cyl(parent, Vector3(pos.x, gy + 1.1, pos.y), 0.06, 0.06, 2.2, _mat(Color(0.3, 0.22, 0.13)))
	var n_lines := lines.split("\n").size()
	_box(parent, Vector3(pos.x, gy + 2.1, pos.y), Vector3(2.2, 0.35 + 0.3 * n_lines, 0.08), _mat(board_color), yaw)
	_label(parent, Vector3(pos.x, gy + 2.15, pos.y), lines, 30, Color(0.95, 0.9, 0.75), yaw)

func _cabin(parent: Node3D, pos: Vector2, size: Vector3, wall_color: Color, roof_color: Color, yaw := 0.0, boarded := true) -> Node3D:
	var gy := ground_height_at(pos.x, pos.y)
	var cabin := Node3D.new()
	cabin.position = Vector3(pos.x, gy, pos.y)
	cabin.rotation.y = yaw
	parent.add_child(cabin)
	_box(cabin, Vector3(0, size.y * 0.5, 0), size, _mat(wall_color))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 0.8, size.y * 0.55, size.z + 0.8)
	roof.mesh = prism
	roof.material_override = _mat(roof_color)
	roof.position = Vector3(0, size.y + size.y * 0.27, 0)
	cabin.add_child(roof)
	# Door.
	_box(cabin, Vector3(0, size.y * 0.28, size.z * 0.5 + 0.03), Vector3(0.9, size.y * 0.55, 0.06), _mat(Color(0.2, 0.14, 0.09)))
	if boarded:
		# Boarded-up windows: dark rectangles with plank crosses.
		for sx in [-1.0, 1.0]:
			_box(cabin, Vector3(sx * size.x * 0.28, size.y * 0.6, size.z * 0.5 + 0.03), Vector3(0.8, 0.8, 0.05), _mat(Color(0.05, 0.05, 0.06)))
			_box(cabin, Vector3(sx * size.x * 0.28, size.y * 0.6, size.z * 0.5 + 0.07), Vector3(0.95, 0.12, 0.04), _mat(Color(0.45, 0.35, 0.2)), 0.0, 0.0, 0.5)
			_box(cabin, Vector3(sx * size.x * 0.28, size.y * 0.6, size.z * 0.5 + 0.07), Vector3(0.95, 0.12, 0.04), _mat(Color(0.45, 0.35, 0.2)), 0.0, 0.0, -0.5)
	return cabin

func _pine(parent: Node3D, pos: Vector3, scale_f := 1.0, scorched := false) -> Node3D:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * scale_f
	parent.add_child(tree)
	var trunk_mat := _mat(Color(0.05, 0.04, 0.03) if scorched else Color(0.25, 0.16, 0.1))
	var leaf_mat := _mat(Color(0.02, 0.02, 0.02) if scorched else Color(0.08, 0.2, 0.08))
	_cyl(tree, Vector3(0, 1.0, 0), 0.14, 0.2, 2.0, trunk_mat)
	_cone(tree, Vector3(0, 3.0, 0), 1.5, 3.0, leaf_mat)
	_cone(tree, Vector3(0, 4.6, 0), 1.1, 2.4, leaf_mat)
	_cone(tree, Vector3(0, 6.0, 0), 0.7, 1.8, leaf_mat)
	return tree

func _waterfall(parent: Node3D, c: Dictionary) -> void:
	var a: Vector2 = c["a"]
	var b: Vector2 = c["b"]
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var yaw := atan2(-dir.x, -dir.y)
	var floor_h: float = c["floor_h"]
	var w: float = c["width"]
	var fall_mat := StandardMaterial3D.new()
	fall_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.7)
	fall_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall_mat.roughness = 0.15
	fall_mat.emission_enabled = true
	fall_mat.emission = Color(0.6, 0.75, 0.9)
	fall_mat.emission_energy_multiplier = 0.4
	# Veil across the canyon, top at rim height.
	_box(parent, Vector3(mid.x, floor_h + 6.0, mid.y), Vector3(w * 0.7, 12.0, 0.25), fall_mat, yaw)
	# Pool at the base.
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.15, 0.4, 0.55, 0.85)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.roughness = 0.15
	var pool := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = w * 0.45
	cyl.bottom_radius = w * 0.45
	cyl.height = 0.2
	pool.mesh = cyl
	pool.material_override = pool_mat
	pool.position = Vector3(mid.x, floor_h + 0.15, mid.y)
	parent.add_child(pool)

# ------------------------------------------------------------ structures ---

func _build_structures() -> void:
	var root := Node3D.new()
	root.name = "Structures"
	add_child(root)
	# --- Entrance gate (south, z=155): chained gate, CLOSED signs.
	var gate_y := ground_height_at(0, 155)
	_cyl(root, Vector3(-3.2, gate_y + 1.4, 155), 0.14, 0.14, 2.8, _mat(Color(0.25, 0.2, 0.15)))
	_cyl(root, Vector3(3.2, gate_y + 1.4, 155), 0.14, 0.14, 2.8, _mat(Color(0.25, 0.2, 0.15)))
	_box(root, Vector3(0, gate_y + 2.4, 155), Vector3(6.6, 0.3, 0.15), _mat(Color(0.3, 0.24, 0.16)))
	# Sagging chain: small links along a catenary dip.
	for i in range(11):
		var t := float(i) / 10.0
		var x := -3.0 + t * 6.0
		var y := gate_y + 1.9 - sin(t * PI) * 0.55
		_box(root, Vector3(x, y, 155), Vector3(0.28, 0.1, 0.1), _mat(Color(0.15, 0.15, 0.16), 0.4, 0.8))
	_sign(root, Vector2(0, 158), "STARVED ROCK\nSTATE PARK", 0.0, Color(0.15, 0.3, 0.15))
	_sign(root, Vector2(4.5, 153), "CLOSED\nNO ENTRY", 0.0, Color(0.45, 0.1, 0.08))
	# --- Empty parking lot (park is closed): asphalt + marked bays, no cars.
	var lot_y := ground_height_at(0, 138)
	_box(root, Vector3(0, lot_y + 0.05, 138), Vector3(34, 0.12, 20), _mat(Color(0.12, 0.12, 0.13)))
	for i in range(6):
		_box(root, Vector3(-12.5 + float(i) * 5.0, lot_y + 0.13, 138), Vector3(0.15, 0.02, 4.5), _mat(Color(0.85, 0.85, 0.8)))
	_sign(root, Vector2(19, 138), "PARKING\nLOT CLOSED", 0.0)
	# --- The Lodge (shuttered): big cabin, boarded windows, CLOSED sign.
	var lodge := _cabin(root, Vector2(-18, 118), Vector3(12, 5, 8), Color(0.4, 0.28, 0.16), Color(0.25, 0.16, 0.1), 0.15, true)
	_box(lodge, Vector3(0, 5.6, 4.4), Vector3(4.0, 0.9, 0.1), _mat(Color(0.3, 0.22, 0.12)))
	_label(lodge, Vector3(0, 6.6, 4.4), "STARVED ROCK LODGE", 36, Color(0.95, 0.9, 0.75))
	_label(lodge, Vector3(0, 5.6, 4.4), "CLOSED", 30, Color(0.9, 0.2, 0.15))
	# Porch.
	_box(lodge, Vector3(0, 0.25, 5.2), Vector3(10, 0.5, 2.4), _mat(Color(0.35, 0.26, 0.16)))
	# --- Cabins near the lodge.
	_cabin(root, Vector2(-42, 128), Vector3(6, 3.5, 5), Color(0.38, 0.27, 0.15), Color(0.22, 0.14, 0.09), -0.3, true)
	_cabin(root, Vector2(-46, 104), Vector3(6, 3.5, 5), Color(0.36, 0.26, 0.15), Color(0.22, 0.14, 0.09), 0.4, true)
	_cabin(root, Vector2(28, 128), Vector3(6, 3.5, 5), Color(0.4, 0.28, 0.16), Color(0.22, 0.14, 0.09), 0.2, true)
	# --- Ranger station (park office) east of the lodge.
	var station := _cabin(root, Vector2(36, 112), Vector3(7, 4, 6), Color(0.35, 0.3, 0.22), Color(0.2, 0.22, 0.15), -0.5, true)
	_label(station, Vector3(0, 4.8, 3.2), "RANGER STATION", 30, Color(0.9, 0.85, 0.7))
	var porch := OmniLight3D.new()
	porch.name = "PorchLight"
	porch.position = Vector3(0, 3.2, 3.6)
	porch.light_color = Color(1.0, 0.75, 0.4)
	porch.light_energy = 0.7
	porch.omni_range = 8.0
	station.add_child(porch)
	# --- Campsite (the hub): 4 A-frame tents, fire ring, cooler, backpacks.
	var camp := Node3D.new()
	camp.name = "Campsite"
	camp.position = Vector3(0, ground_height_at(0, 100), 100)
	add_child(camp)
	var tent_colors := [Color(0.7, 0.15, 0.12), Color(0.12, 0.3, 0.65), Color(0.75, 0.6, 0.1), Color(0.15, 0.5, 0.2)]
	var tent_spots := [Vector3(-4, 0, -3), Vector3(4, 0, -3), Vector3(-4, 0, 3), Vector3(4, 0, 3)]
	for i in range(4):
		var prism := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.4, 1.6, 2.8)
		prism.mesh = pm
		prism.material_override = _mat(tent_colors[i])
		prism.position = tent_spots[i]
		prism.rotation.y = float(i) * 0.5
		camp.add_child(prism)
		# Sleeping bag outside each tent.
		_box(camp, tent_spots[i] + Vector3(0, 0.25, 1.8), Vector3(0.8, 0.4, 1.9), _mat(Color(0.2, 0.25, 0.4)), float(i) * 0.5)
	# Campfire: stone ring + logs + flickering light.
	for i in range(8):
		var a := TAU * float(i) / 8.0
		_box(camp, Vector3(cos(a) * 0.9, 0.25, sin(a) * 0.9), Vector3(0.4, 0.5, 0.3), _mat(Color(0.4, 0.38, 0.36)), a)
	for i in range(3):
		_cyl(camp, Vector3(0, 0.35, 0), 0.09, 0.09, 1.1, _mat(Color(0.2, 0.12, 0.07)), Vector3(0, 0, 1.2 + float(i) * 1.0))
	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.position = Vector3(0, 0.9, 0)
	fire_light.light_color = Color(1.0, 0.55, 0.15)
	fire_light.light_energy = 1.5
	fire_light.omni_range = 12.0
	fire_light.omni_attenuation = 1.4
	camp.add_child(fire_light)
	# Cooler + backpacks.
	_box(camp, Vector3(6, 0.4, 1), Vector3(1.0, 0.8, 0.6), _mat(Color(0.85, 0.85, 0.88)))
	_box(camp, Vector3(-6, 0.5, 2), Vector3(0.7, 1.0, 0.5), _mat(Color(0.3, 0.2, 0.12)), 0.4)
	_box(camp, Vector3(-5.2, 0.5, 2.6), Vector3(0.7, 1.0, 0.5), _mat(Color(0.15, 0.2, 0.3)), -0.3)
	# --- Ranger truck in the parking lot (empty, keys in it, headlights off by day).
	var truck := Node3D.new()
	truck.name = "RangerTruck"
	truck.position = Vector3(10, ground_height_at(10, 135), 135)
	truck.rotation.y = -0.4
	add_child(truck)
	truck_pos = truck.position
	_box(truck, Vector3(0, 0.7, 0), Vector3(2.0, 0.9, 4.6), _mat(Color(0.9, 0.9, 0.88), 0.4, 0.3))
	_box(truck, Vector3(0, 1.5, 0.4), Vector3(1.8, 0.8, 2.2), _mat(Color(0.9, 0.9, 0.88), 0.4, 0.3))
	_box(truck, Vector3(0, 0.75, 0), Vector3(2.02, 0.3, 4.62), _mat(Color(0.1, 0.35, 0.15)))
	for wx in [-0.95, 0.95]:
		for wz in [-1.5, 1.5]:
			_cyl(truck, Vector3(wx, 0.45, wz), 0.42, 0.42, 0.3, _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 0, PI * 0.5))
	_label(truck, Vector3(0, 1.6, -0.8), "PARK RANGER", 28, Color(0.1, 0.3, 0.12))
	for hx in [-0.7, 0.7]:
		var hl := SpotLight3D.new()
		hl.position = Vector3(hx, 0.7, -2.35)
		hl.rotation = Vector3(0, 0, 0)
		hl.light_color = Color(1.0, 0.95, 0.8)
		hl.light_energy = 0.0
		hl.spot_range = 30.0
		hl.spot_angle = 30.0
		truck.add_child(hl)
		truck_lights.append(hl)
	# --- Trail signs at the junctions.
	_sign(root, Vector2(0, 150), "RIVER TRAIL ->\nBLUFF TRAIL ->", 0.0)
	_sign(root, Vector2(2, 105), "CAMPGROUND\nLASALLE 0.4 MI", 0.0)
	_sign(root, Vector2(3, -95), "BLUFF TRAIL\nRIVER TRAIL v", 0.0)
	_sign(root, Vector2(2, -150), "RIVER TRAIL\nILLINOIS RIVER", 0.0)
	_sign(root, Vector2(-52, -52), "LASALLE CANYON", 0.0)
	_sign(root, Vector2(17, -58), "FRENCH CANYON", 0.0)
	_sign(root, Vector2(86, -52), "WILDCAT CANYON", 0.0)
	_sign(root, Vector2(-118, -42), "TONTI CANYON", 0.0)
	_sign(root, Vector2(-148, -88), "OWL CANYON\nRESTRICTED - CLOSED", 0.0, Color(0.45, 0.1, 0.08))
	# --- Overlooks on the bluff rim.
	_overlook(root, Vector2(-20, -122), "HORSESHOE BEND")
	_overlook(root, Vector2(60, -118), "LOVER'S LEAP")
	# --- Waterfalls in the nine waterfall canyons.
	for c in canyons:
		if bool(c["waterfall"]):
			_waterfall(root, c)

func _overlook(parent: Node3D, pos: Vector2, label_text: String) -> void:
	var gy := ground_height_at(pos.x, pos.y)
	var ov := Node3D.new()
	ov.position = Vector3(pos.x, gy, pos.y)
	parent.add_child(ov)
	# Wooden railing facing the river (north, -z).
	for i in range(6):
		_cyl(ov, Vector3(-3.0 + float(i) * 1.2, 0.6, -1.5), 0.06, 0.06, 1.2, _mat(Color(0.3, 0.22, 0.13)))
	_box(ov, Vector3(0, 1.15, -1.5), Vector3(6.2, 0.1, 0.1), _mat(Color(0.32, 0.24, 0.14)))
	_box(ov, Vector3(0, 0.7, -1.5), Vector3(6.2, 0.08, 0.08), _mat(Color(0.32, 0.24, 0.14)))
	# Sign, built in local space (the overlook node already sits on the ground).
	_cyl(ov, Vector3(0, 1.1, 1.0), 0.06, 0.06, 2.2, _mat(Color(0.3, 0.22, 0.13)))
	_box(ov, Vector3(0, 2.1, 1.0), Vector3(2.2, 0.95, 0.08), _mat(Color(0.35, 0.25, 0.14)))
	_label(ov, Vector3(0, 2.15, 1.0), label_text + "\nOVERLOOK", 30, Color(0.95, 0.9, 0.75))

# ------------------------------------------------------------------ props ---

func _build_props() -> void:
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var hub := Vector2(0, 115)
	var owl: Dictionary = canyons[4]
	var crash := Vector2(owl["b"].x, owl["b"].y)
	# Pines.
	var placed := 0
	var tries := 0
	while placed < 140 and tries < 2500:
		tries += 1
		var x := rng.randf_range(-175, 175)
		var z := rng.randf_range(-175, 175)
		if z < -146.0:
			continue
		if Vector2(x, z).distance_to(hub) < 26.0:
			continue
		if Vector2(x, z).distance_to(crash) < 22.0:
			continue
		if nearest_trail_dist(x, z) < 2.5:
			continue
		if canyon_factor_at(x, z) > 0.3:
			continue
		if slope_at(x, z) > 0.5:
			continue
		_pine(root, Vector3(x, ground_height_at(x, z), z), rng.randf_range(0.8, 1.4))
		placed += 1
	# Bushes / ferns.
	placed = 0
	tries = 0
	while placed < 60 and tries < 1200:
		tries += 1
		var x := rng.randf_range(-170, 170)
		var z := rng.randf_range(-170, 170)
		if z < -146.0 or Vector2(x, z).distance_to(hub) < 24.0:
			continue
		if nearest_trail_dist(x, z) < 2.0 or canyon_factor_at(x, z) > 0.4:
			continue
		_sphere(root, Vector3(x, ground_height_at(x, z) + 0.3, z), rng.randf_range(0.5, 0.9), _mat(Color(0.07, 0.18, 0.07)), 0.6)
		placed += 1
	# Boulders (some in the canyons).
	placed = 0
	tries = 0
	while placed < 80 and tries < 1500:
		tries += 1
		var x := rng.randf_range(-175, 175)
		var z := rng.randf_range(-175, 175)
		if z < -146.0 or Vector2(x, z).distance_to(hub) < 24.0:
			continue
		if nearest_trail_dist(x, z) < 2.0:
			continue
		var s := rng.randf_range(0.5, 1.8)
		_box(root, Vector3(x, ground_height_at(x, z) + s * 0.25, z), Vector3(s, s * 0.7, s), _mat(Color(0.45, 0.42, 0.38)), rng.randf_range(0, TAU))
		placed += 1
	# Scorched / toppled pines around the crater.
	for i in range(10):
		var a := TAU * float(i) / 10.0 + 0.3
		var d := rng.randf_range(15.0, 24.0)
		var x := crash.x + cos(a) * d
		var z := crash.y + sin(a) * d
		var tree := _pine(root, Vector3(x, ground_height_at(x, z), z), rng.randf_range(0.9, 1.3), true)
		tree.rotation = Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0, TAU), rng.randf_range(-0.4, 0.4))
	# Dead trees inside the fenced crash area.
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var d := rng.randf_range(8.0, 18.0)
		var x := crash.x + cos(a) * d
		var z := crash.y + sin(a) * d
		var gy := ground_height_at(x, z)
		_cyl(root, Vector3(x, gy + 1.5, z), 0.08, 0.14, 3.0, _mat(Color(0.06, 0.05, 0.04)), Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)))

# ------------------------------------------------------------- crash site ---

func _build_crash_site() -> void:
	var root := Node3D.new()
	root.name = "CrashSite"
	add_child(root)
	var owl: Dictionary = canyons[4]
	var cx: float = owl["b"].x
	var cz: float = owl["b"].y
	var cy: float = owl["floor_h"]
	var center := Vector3(cx, cy, cz)
	# Scorched crater disc.
	var crater := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 13.0
	cyl.bottom_radius = 13.0
	cyl.height = 0.3
	crater.mesh = cyl
	crater.material_override = _mat(Color(0.05, 0.045, 0.04))
	crater.position = center + Vector3(0, 0.1, 0)
	root.add_child(crater)
	# Blasted-rock rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(14):
		var a := TAU * float(i) / 14.0
		var d := rng.randf_range(12.0, 14.5)
		var s := rng.randf_range(1.2, 2.6)
		_box(root, Vector3(cx + cos(a) * d, cy + 0.4, cz + sin(a) * d), Vector3(s, s * 0.6, s), _mat(Color(0.1, 0.09, 0.08)), rng.randf_range(0, TAU))
	# The craft: tilted disc + dome, metallic hull, 8 blinking rim lights.
	var craft := Node3D.new()
	craft.name = "Craft"
	craft.position = center + Vector3(0, 1.2, 0)
	craft.rotation = Vector3(0.12, 0.7, -0.18)
	root.add_child(craft)
	var hull_mat := _mat(Color(0.55, 0.58, 0.62), 0.25, 0.85)
	var hull := MeshInstance3D.new()
	var hull_mesh := CylinderMesh.new()
	hull_mesh.top_radius = 3.2
	hull_mesh.bottom_radius = 4.6
	hull_mesh.height = 1.4
	hull_mesh.radial_segments = 24
	hull.mesh = hull_mesh
	hull.material_override = hull_mat
	craft.add_child(hull)
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 2.2
	dome_mesh.height = 2.2
	dome.mesh = dome_mesh
	dome.material_override = _mat(Color(0.2, 0.3, 0.45), 0.15, 0.6)
	dome.position = Vector3(0, 0.9, 0)
	dome.scale.y = 0.55
	craft.add_child(dome)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.4, 0.02, 0.02)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.05, 0.05)
		lm.emission_energy_multiplier = 2.0
		var light_box := MeshInstance3D.new()
		var lb_mesh := BoxMesh.new()
		lb_mesh.size = Vector3(0.35, 0.2, 0.35)
		light_box.mesh = lb_mesh
		light_box.material_override = lm
		light_box.position = Vector3(cos(a) * 4.4, -0.2, sin(a) * 4.4)
		craft.add_child(light_box)
		craft_lights.append(lm)
	# Cold blue light over the crater.
	craft_light_ref = OmniLight3D.new()
	craft_light_ref.name = "CraftLight"
	craft_light_ref.position = center + Vector3(0, 4.0, 0)
	craft_light_ref.light_color = Color(0.4, 0.65, 1.0)
	craft_light_ref.light_energy = 1.7
	craft_light_ref.omni_range = 26.0
	root.add_child(craft_light_ref)
	# Debris field: 16 hull fragments scattered around the crater.
	for i in range(16):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(6.0, 26.0)
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		var s := rng.randf_range(0.3, 1.1)
		_box(root, Vector3(x, ground_height_at(x, z) + 0.2, z), Vector3(s, s * 0.4, s * 0.7), hull_mat, rng.randf_range(0, TAU), 0.0, rng.randf_range(-0.3, 0.3))
	# Abandoned gear: a backpack, a torn tent, a lantern, a camera.
	_box(root, Vector3(cx + 8, cy + 0.4, cz + 4), Vector3(0.7, 0.9, 0.5), _mat(Color(0.25, 0.18, 0.1)), 0.8)
	_box(root, Vector3(cx - 7, cy + 0.3, cz + 6), Vector3(1.8, 0.5, 1.4), _mat(Color(0.5, 0.15, 0.12)), -0.5, 0.0, 0.3)
	_box(root, Vector3(cx + 5, cy + 0.35, cz - 6), Vector3(0.3, 0.5, 0.3), _mat(Color(0.2, 0.2, 0.18), 0.3, 0.5))
	_box(root, Vector3(cx - 4, cy + 0.25, cz - 7), Vector3(0.5, 0.35, 0.3), _mat(Color(0.08, 0.08, 0.08), 0.2, 0.4))
	# Scattered bones (5).
	for i in range(5):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(9.0, 20.0)
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		_cyl(root, Vector3(x, ground_height_at(x, z) + 0.15, z), 0.05, 0.05, 0.9, _mat(Color(0.85, 0.82, 0.72)), Vector3(0, 0, PI * 0.5 + rng.randf_range(-0.4, 0.4)))
	# Fence ring around the crash area, gap on the east side.
	var fence_y := ground_height_at(cx, cz)
	for i in range(28):
		var a := TAU * float(i) / 28.0
		# Gap facing east (angle ~0).
		if absf(a) < 0.35 or absf(a - TAU) < 0.35:
			continue
		var x := cx + cos(a) * 22.0
		var z := cz + sin(a) * 22.0
		var gy := ground_height_at(x, z)
		_cyl(root, Vector3(x, gy + 0.9, z), 0.07, 0.07, 1.8, _mat(Color(0.35, 0.3, 0.22)))
		if i % 2 == 0:
			var a2 := TAU * float(i + 1) / 28.0
			var x2 := cx + cos(a2) * 22.0
			var z2 := cz + sin(a2) * 22.0
			var gy2 := ground_height_at(x2, z2)
			var mid := Vector3((x + x2) * 0.5, (gy + gy2) * 0.5 + 1.5, (z + z2) * 0.5)
			var span := Vector3(x2 - x, 0, z2 - z).length()
			var rail := _box(root, mid, Vector3(span, 0.08, 0.08), _mat(Color(0.35, 0.3, 0.22)))
			rail.rotation.y = atan2(-(z2 - z), x2 - x)
	_sign(root, Vector2(cx + 22, cz), "RESTRICTED\nDO NOT ENTER", 0.0, Color(0.45, 0.1, 0.08))
	_sign(root, Vector2(cx - 16, cz + 15), "RESTRICTED\nDO NOT ENTER", 0.0, Color(0.45, 0.1, 0.08))
	# Dropped walkie-talkie prop (hidden until Sal's disappearance beat).
	dropped_walkie = Node3D.new()
	dropped_walkie.name = "DroppedWalkie"
	dropped_walkie.visible = false
	root.add_child(dropped_walkie)
	_box(dropped_walkie, Vector3(0, 0.15, 0), Vector3(0.22, 0.3, 0.12), _mat(Color(0.05, 0.05, 0.05)))
	_cyl(dropped_walkie, Vector3(0.08, 0.45, 0), 0.015, 0.015, 0.5, _mat(Color(0.1, 0.1, 0.1)))

# ---------------------------------------------------------------- animals ---

func _build_animals() -> void:
	var root := Node3D.new()
	root.name = "Animals"
	add_child(root)
	var deer_mat := _mat(Color(0.4, 0.3, 0.2))
	var blood_mat := _mat(Color(0.25, 0.02, 0.02))
	# Three deer carcasses: lying on their side, legs splayed, blood pool,
	# no visible wounds — "surgical", per Sal.
	var carcass_spots := [Vector2(-140, -88), Vector2(-152, -30), Vector2(-145, -64)]
	for i in range(carcass_spots.size()):
		var sp: Vector2 = carcass_spots[i]
		var gy := ground_height_at(sp.x, sp.y)
		var deer := Node3D.new()
		deer.position = Vector3(sp.x, gy, sp.y)
		deer.rotation.y = float(i) * 1.3
		root.add_child(deer)
		# Body on its side.
		_box(deer, Vector3(0, 0.45, 0), Vector3(0.7, 0.8, 1.6), deer_mat)
		# Head + neck, limp.
		_box(deer, Vector3(0.1, 0.35, 1.1), Vector3(0.35, 0.35, 0.7), deer_mat, 0.0, 0.0, 0.4)
		# Splayed legs.
		for lx in [-0.3, 0.3]:
			for lz in [-0.6, 0.6]:
				_cyl(deer, Vector3(lx * 1.4, 0.2, lz), 0.06, 0.06, 0.9, deer_mat, Vector3(0, 0, PI * 0.5))
		# Antlers on two of them.
		if i < 2:
			_cyl(deer, Vector3(-0.15, 0.75, 1.35), 0.03, 0.03, 0.7, _mat(Color(0.5, 0.4, 0.25)), Vector3(0.6, 0, 0.3))
			_cyl(deer, Vector3(0.2, 0.75, 1.35), 0.03, 0.03, 0.7, _mat(Color(0.5, 0.4, 0.25)), Vector3(0.6, 0, -0.3))
		# Blood pool.
		var pool := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.9
		pm.bottom_radius = 0.9
		pm.height = 0.04
		pool.mesh = pm
		pool.material_override = blood_mat
		pool.position = Vector3(0.3, 0.05, 0.2)
		deer.add_child(pool)
	# The watching deer: stands still, faces the player when near.
	watching_deer = Node3D.new()
	watching_deer.name = "WatchingDeer"
	watching_deer.position = Vector3(-120, ground_height_at(-120, -20), -20)
	root.add_child(watching_deer)
	_box(watching_deer, Vector3(0, 1.0, 0), Vector3(0.6, 0.9, 1.4), deer_mat)
	_box(watching_deer, Vector3(0, 1.7, 0.85), Vector3(0.3, 0.7, 0.3), deer_mat)
	_sphere(watching_deer, Vector3(0, 2.15, 0.9), 0.22, deer_mat)
	for lx in [-0.22, 0.22]:
		for lz in [-0.5, 0.5]:
			_cyl(watching_deer, Vector3(lx, 0.45, lz), 0.06, 0.06, 0.9, deer_mat)

# ------------------------------------------------------------------ figure ---

func _build_figure() -> void:
	# The "ranger": a normal-height man in dark clothes and a wide-brim hat.
	# He is a misdirection — the first explanation that makes sense — and he
	# is never what he seems. Swappable later for whatever the truth needs.
	figure = Node3D.new()
	figure.name = "Figure"
	figure.visible = false
	add_child(figure)
	var dark := _mat(Color(0.08, 0.09, 0.08))
	var skin := _mat(Color(0.75, 0.6, 0.48))
	_cyl(figure, Vector3(0, 1.0, 0), 0.22, 0.26, 1.5, dark) # coat
	_cyl(figure, Vector3(-0.12, 0.4, 0), 0.09, 0.09, 0.8, dark)
	_cyl(figure, Vector3(0.12, 0.4, 0), 0.09, 0.09, 0.8, dark)
	_sphere(figure, Vector3(0, 1.85, 0), 0.2, skin)
	# Wide-brim hat: brim disc + crown.
	_cyl(figure, Vector3(0, 2.0, 0), 0.42, 0.42, 0.05, _mat(Color(0.12, 0.1, 0.08)))
	_cyl(figure, Vector3(0, 2.12, 0), 0.16, 0.2, 0.22, _mat(Color(0.12, 0.1, 0.08)))
	figure.position = figure_spots[0] if figure_spots.size() > 0 else Vector3.ZERO
