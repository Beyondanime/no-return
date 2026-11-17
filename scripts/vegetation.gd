extends RefCounted
class_name Vegetation
## Realistic vegetation + rocks for Starved Rock, all instanced (MultiMesh)
## so the forest costs a handful of draw calls.
##
## - Fir trees: procedural — bark-textured tapered trunk + a canopy of
##   crossed alpha-cutout quads using the real fir twig texture.
## - Grass / ferns / shrubs: crossed-quad tufts with the merged alpha
##   textures from the CC0 Poly Haven plant models.
## - Boulders, mossy rocks, stumps, dead trunks: CC0 Poly Haven GLTF
##   models (meshes merged, then MultiMesh).
## All external assets are CC0 (Poly Haven). See ASSET_SOURCES.md.

const FIR_BARK := preload("res://assets/tree/fir_bark_diff_1k.jpg")
const FIR_BARK_NOR := preload("res://assets/tree/fir_bark_nor_1k.jpg")
const FIR_BARK_ARM := preload("res://assets/tree/fir_bark_arm_1k.jpg")
const FIR_TWIG := preload("res://assets/generated/fir_twig_rgba.png")
const GRASS_TEX := preload("res://assets/models/grass_medium_01/textures/grass_medium_01_diff_alpha.png")
const GRASS_TEX2 := preload("res://assets/models/grass_medium_02/textures/grass_medium_02_diff_alpha.png")
const FERN_TEX := preload("res://assets/models/fern_02/textures/fern_02_diff_alpha.png")
const SHRUB_TEX := preload("res://assets/models/shrub_02/textures/shrub_02_diff_alpha.png")
const MOSS_TEX := preload("res://assets/models/moss_01/textures/moss_01_diff_alpha.png")

const BOULDER_SCENE := "res://assets/models/boulder_01/boulder_01.gltf"
const ROCK_SET_SCENE := "res://assets/models/rock_moss_set_01/rock_moss_set_01.gltf"
const STUMP_SCENE := "res://assets/models/tree_stump_01/tree_stump_01.gltf"
const DEAD_TRUNK_SCENE := "res://assets/models/dead_tree_trunk/dead_tree_trunk.gltf"

static func _alpha_mat(tex: Texture2D, scissor: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = scissor
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	return m

## One crossed-quad tuft mesh. quads: array of [width, height, y_base, rot_y].
static func _tuft_mesh(quads: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var w: float = q[0]
		var h: float = q[1]
		var y0: float = q[2]
		var rot: float = q[3]
		var ca := cos(rot)
		var sa := sin(rot)
		var hw := w * 0.5
		# quad corners in local space, facing +Z before rotation
		var corners: Array = [
			Vector3(-hw, y0, 0), Vector3(hw, y0, 0),
			Vector3(hw, y0 + h, 0), Vector3(-hw, y0 + h, 0),
		]
		var uvs: Array = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var nrm := Vector3(sa, 0, ca)  # rotated +Z
		var idx: Array = [0, 1, 2, 0, 2, 3]
		for i in idx:
			var c: Vector3 = corners[i]
			var p := Vector3(c.x * ca, c.y, -c.x * sa)
			st.set_normal(nrm)
			st.set_uv(uvs[i])
			st.add_vertex(p)
	return st.commit()

## A flat ground patch (moss): a quad lying in the XZ plane, normal +Y.
static func _flat_patch_mesh(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var corners: Array = [
		Vector3(-h, 0, -h), Vector3(h, 0, -h),
		Vector3(h, 0, h), Vector3(-h, 0, h),
	]
	var uvs: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
	return st.commit()
## Merge every MeshInstance3D in a GLTF scene into one ArrayMesh
## (accumulating node transforms). All these models use one material.
static func _merge_scene(scene_path: String) -> ArrayMesh:
	var ps: PackedScene = load(scene_path)
	var root := ps.instantiate()
	var parts: Array = [] # each entry: [surface arrays, transform, material]
	_collect_meshes(root, Transform3D.IDENTITY, parts)
	root.queue_free()
	var all_have_tangents := true
	for part in parts:
		if (part[0] as Array)[Mesh.ARRAY_TANGENT].is_empty():
			all_have_tangents = false
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var mat: Material = null
	for part in parts:
		var arr: Array = part[0]
		var xf: Transform3D = part[1]
		if mat == null:
			mat = part[2]
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		for i in range(v.size()):
			verts.append(xf * v[i])
			normals.append((xf.basis * n[i]).normalized())
			uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
			if all_have_tangents:
				var t := Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])
				var tt := (xf.basis * t).normalized()
				tangents.append_array(PackedFloat32Array([tt.x, tt.y, tt.z, tg[i * 4 + 3]]))
		if idx.is_empty():
			for i in range(v.size()):
				indices.append(base + i)
		else:
			for i in range(idx.size()):
				indices.append(base + idx[i])
	var merged: Array = []
	merged.resize(Mesh.ARRAY_MAX)
	merged[Mesh.ARRAY_VERTEX] = verts
	merged[Mesh.ARRAY_NORMAL] = normals
	merged[Mesh.ARRAY_TEX_UV] = uvs
	if all_have_tangents and not tangents.is_empty():
		merged[Mesh.ARRAY_TANGENT] = tangents
	merged[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
	if mat != null:
		out.surface_set_material(0, mat)
	return out

static func _collect_meshes(node: Node, parent_xf: Transform3D, parts: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				parts.append([mi.mesh.surface_get_arrays(s), xf,
					mi.mesh.surface_get_material(s)])
	for child in node.get_children():
		_collect_meshes(child, xf, parts)

static func _multimesh(mesh: Mesh, transforms: Array[Transform3D], parent: Node3D,
		mat: Material = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	parent.add_child(mmi)
	return mmi

static func _xf(pos: Vector3, rot_y: float, scale: float,
		scale_y: float = -1.0) -> Transform3D:
	var sy := scale_y if scale_y > 0.0 else scale
	var b := Basis(Vector3.UP, rot_y).scaled(Vector3(scale, sy, scale))
	return Transform3D(b, pos)

static func populate(parent: Node3D, wb) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	# --- placement helpers (same rules as the world builder) ---
	var is_ok := func(x: float, z: float) -> bool:
		if z < -148.0:
			return false
		if wb.canyon_factor_at(x, z) > 0.45:
			return false
		if wb.nearest_trail_dist(x, z) < 1.6:
			return false
		var p := Vector2(x, z)
		if p.distance_to(Vector2(60, -128)) < 26.0:
			return false
		if p.distance_to(Vector2(wb.CRASH_POS.x, wb.CRASH_POS.y)) < 22.0:
			return false
		if p.distance_to(Vector2(-10, 60)) < 18.0:
			return false
		return true
	var ground := func(x: float, z: float) -> float:
		return wb.height_at(x, z)

	# --- fir trees: trunk + canopy (same transform list) ---
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.30
	trunk.height = 6.0
	trunk.radial_segments = 12
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_texture = FIR_BARK
	bark_mat.albedo_color = Color(1.8, 1.5, 1.2)
	bark_mat.normal_texture = FIR_BARK_NOR
	bark_mat.roughness_texture = FIR_BARK_ARM
	bark_mat.roughness = 1.0
	bark_mat.uv1_scale = Vector3(2, 3, 1)
	var canopy := _tuft_mesh([
		[3.2, 2.6, 1.8, 0.0], [3.2, 2.6, 1.8, PI / 3], [3.2, 2.6, 1.8, 2 * PI / 3],
		[2.6, 2.2, 3.4, PI / 6], [2.6, 2.2, 3.4, PI / 2], [2.6, 2.2, 3.4, 5 * PI / 6],
		[2.0, 1.8, 4.8, 0.0], [2.0, 1.8, 4.8, PI / 3], [2.0, 1.8, 4.8, 2 * PI / 3],
		[1.4, 1.5, 6.0, PI / 6], [1.4, 1.5, 6.0, PI / 2], [1.4, 1.5, 6.0, 5 * PI / 6],
	])
	var canopy_mat := _alpha_mat(FIR_TWIG, 0.35)
	canopy_mat.albedo_color = Color(0.75, 1.0, 0.7)
	var tree_xfs: Array[Transform3D] = []
	var tries := 0
	while tree_xfs.size() < 150 and tries < 3000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-150.0, 175.0)
		if not is_ok.call(x, z):
			continue
		var s := rng.randf_range(0.8, 1.45)
		tree_xfs.append(_xf(Vector3(x, ground.call(x, z) + 3.0 * s, z),
			rng.randf_range(0, TAU), s))
	_multimesh(trunk, tree_xfs, parent, bark_mat)
	_multimesh(canopy, tree_xfs, parent, canopy_mat)

	# --- ground cover tufts ---
	var grass_mesh := _tuft_mesh([
		[1.0, 0.55, 0.0, 0.0], [1.0, 0.55, 0.0, PI / 3], [1.0, 0.55, 0.0, 2 * PI / 3],
	])
	var fern_mesh := _tuft_mesh([
		[1.1, 0.7, 0.0, 0.0], [1.1, 0.7, 0.0, PI / 2],
	])
	var shrub_mesh := _tuft_mesh([
		[1.3, 0.9, 0.0, 0.0], [1.3, 0.9, 0.0, PI / 3], [1.3, 0.9, 0.0, 2 * PI / 3],
	])
	var moss_mesh := _flat_patch_mesh(0.9)
	var grass_xfs: Array[Transform3D] = []
	var grass2_xfs: Array[Transform3D] = []
	var fern_xfs: Array[Transform3D] = []
	var shrub_xfs: Array[Transform3D] = []
	var moss_xfs: Array[Transform3D] = []
	tries = 0
	while (grass_xfs.size() + grass2_xfs.size()) < 900 and tries < 12000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-150.0, 175.0)
		if z < -148.0 or wb.canyon_factor_at(x, z) > 0.55:
			continue
		var y: float = ground.call(x, z)
		var xf := _xf(Vector3(x, y + 0.02, z), rng.randf_range(0, TAU),
			rng.randf_range(0.7, 1.5))
		if rng.randf() < 0.5:
			grass_xfs.append(xf)
		else:
			grass2_xfs.append(xf)
	tries = 0
	while fern_xfs.size() < 240 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-150.0, 175.0)
		# Ferns love the damp canyon bottoms and shaded trail edges.
		if z < -148.0 or wb.canyon_factor_at(x, z) < 0.15:
			continue
		if wb.nearest_trail_dist(x, z) < 1.2:
			continue
		fern_xfs.append(_xf(Vector3(x, ground.call(x, z) + 0.02, z),
			rng.randf_range(0, TAU), rng.randf_range(0.7, 1.4)))
	tries = 0
	while shrub_xfs.size() < 130 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-150.0, 175.0)
		if not is_ok.call(x, z):
			continue
		shrub_xfs.append(_xf(Vector3(x, ground.call(x, z) + 0.02, z),
			rng.randf_range(0, TAU), rng.randf_range(0.8, 1.6)))
	tries = 0
	while moss_xfs.size() < 90 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-150.0, 175.0)
		if z < -148.0:
			continue
		# flat moss patch lying on the ground
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU))
		b = b.scaled(Vector3(rng.randf_range(0.8, 1.8), 1, rng.randf_range(0.8, 1.8)))
		moss_xfs.append(Transform3D(b, Vector3(x, ground.call(x, z) + 0.03, z)))
	_multimesh(grass_mesh, grass_xfs, parent, _alpha_mat(GRASS_TEX))
	_multimesh(grass_mesh, grass2_xfs, parent, _alpha_mat(GRASS_TEX2))
	_multimesh(fern_mesh, fern_xfs, parent, _alpha_mat(FERN_TEX))
	_multimesh(shrub_mesh, shrub_xfs, parent, _alpha_mat(SHRUB_TEX))
	_multimesh(moss_mesh, moss_xfs, parent, _alpha_mat(MOSS_TEX, 0.4))

	# --- GLTF rocks / stumps / dead trunks (merged, then MultiMesh) ---
	var boulder_mesh := _merge_scene(BOULDER_SCENE)
	var rock_mesh := _merge_scene(ROCK_SET_SCENE)
	var stump_mesh := _merge_scene(STUMP_SCENE)
	var dead_mesh := _merge_scene(DEAD_TRUNK_SCENE)
	var boulder_xfs: Array[Transform3D] = []
	var rock_xfs: Array[Transform3D] = []
	var stump_xfs: Array[Transform3D] = []
	var dead_xfs: Array[Transform3D] = []
	tries = 0
	while boulder_xfs.size() < 70 and tries < 3000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-148.0, 175.0)
		if wb.nearest_trail_dist(x, z) < 1.4:
			continue
		var s := rng.randf_range(0.5, 2.2)
		boulder_xfs.append(_xf(Vector3(x, ground.call(x, z) + 0.1 * s, z),
			rng.randf_range(0, TAU), s, s * rng.randf_range(0.7, 1.0)))
	tries = 0
	while rock_xfs.size() < 40 and tries < 3000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-148.0, 175.0)
		# Mossy rocks cluster in and around the canyons.
		if wb.canyon_factor_at(x, z) < 0.1 and rng.randf() < 0.7:
			continue
		if wb.nearest_trail_dist(x, z) < 1.4:
			continue
		var s := rng.randf_range(0.6, 1.6)
		rock_xfs.append(_xf(Vector3(x, ground.call(x, z) + 0.05 * s, z),
			rng.randf_range(0, TAU), s))
	tries = 0
	while stump_xfs.size() < 18 and tries < 2000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-148.0, 175.0)
		if not is_ok.call(x, z):
			continue
		stump_xfs.append(_xf(Vector3(x, ground.call(x, z), z),
			rng.randf_range(0, TAU), rng.randf_range(0.8, 1.5)))
	tries = 0
	while dead_xfs.size() < 14 and tries < 2000:
		tries += 1
		var x := rng.randf_range(-175.0, 175.0)
		var z := rng.randf_range(-148.0, 175.0)
		if not is_ok.call(x, z):
			continue
		# Dead trunks lie on their side (rotated ~90 deg around Z).
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.FORWARD, PI / 2)
		var s := rng.randf_range(0.8, 1.3)
		b = b.scaled(Vector3(s, s, s))
		dead_xfs.append(Transform3D(b, Vector3(x, ground.call(x, z) + 0.35 * s, z)))
	_multimesh(boulder_mesh, boulder_xfs, parent)
	_multimesh(rock_mesh, rock_xfs, parent)
	_multimesh(stump_mesh, stump_xfs, parent)
	_multimesh(dead_mesh, dead_xfs, parent)
