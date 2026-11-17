extends RefCounted
class_name Humanoid
## Builds realistic humanoid bodies from lathe/shell geometry + real PBR
## textures (skin, jersey, denim, hair, procedural faces). Replaces the
## blocky Roblox-style figures. All textures are original (generated) or
## CC0 (Poly Haven). No MakeHuman: no Linux/headless build exists.

const SKIN_TEX := preload("res://assets/generated/skin.png")
const JERSEY_TEX := preload("res://assets/textures/cotton_jersey/cotton_jersey_diff_1k.jpg")
const JERSEY_NOR := preload("res://assets/textures/cotton_jersey/cotton_jersey_nor_gl_1k.jpg")
const DENIM_TEX := preload("res://assets/textures/denim_fabric/denim_fabric_diff_1k.jpg")
const DENIM_NOR := preload("res://assets/textures/denim_fabric/denim_fabric_nor_gl_1k.jpg")
const HAIR_SHORT_TEX := preload("res://assets/generated/hair_short.png")
const HAIR_CURLY_TEX := preload("res://assets/generated/hair_curly.png")
const HAIR_BLOND_TEX := preload("res://assets/generated/hair_blond.png")
const CAP_TEX := preload("res://assets/generated/cap_yellow.png")
const FACE_CHRIS_TEX := preload("res://assets/generated/face_chris.png")
const FACE_SAL_TEX := preload("res://assets/generated/face_sal.png")
const FACE_HARRY_TEX := preload("res://assets/generated/face_harry.png")
const PLANKS_TEX := preload("res://assets/textures/weathered_planks/weathered_planks_diff_1k.jpg")
const PLANKS_NOR := preload("res://assets/textures/weathered_planks/weathered_planks_nor_gl_1k.jpg")

static func _std(albedo: Texture2D, rough: float = 0.85, normal: Texture2D = null,
		tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.albedo_color = tint
	m.roughness = rough
	if normal != null:
		m.normal_texture = normal
		m.normal_scale = 0.8
	return m

static func skin_mat() -> StandardMaterial3D:
	return _std(SKIN_TEX, 0.55)

static func shirt_mat(shirt_color: Color) -> StandardMaterial3D:
	# The jersey texture is a light warm grey, so the shirt color tints it.
	return _std(JERSEY_TEX, 0.9, JERSEY_NOR, shirt_color)

static func jeans_mat() -> StandardMaterial3D:
	return _std(DENIM_TEX, 0.9, DENIM_NOR)

static func shoe_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.10, 0.09)
	m.roughness = 0.6
	return m

static func face_mat(face_tex: Texture2D) -> StandardMaterial3D:
	return _std(face_tex, 0.55)

static func hair_mat(hair_tex: Texture2D) -> StandardMaterial3D:
	return _std(hair_tex, 0.85)

static func cap_mat() -> StandardMaterial3D:
	return _std(CAP_TEX, 0.9)

## Surface of revolution around +Y. profile: Vector2(radius, y).
## Normals are computed from the profile curve (smooth, no seam artifact).
static func lathe_mesh(profile: PackedVector2Array, segments: int = 20,
		uv_u_scale: float = 2.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		for j in range(n - 1):
			var p0 := profile[j]
			var p1 := profile[j + 1]
			# 2D profile normal (outward): (dy, -dr) normalized.
			var dr := p1.x - p0.x
			var dy := p1.y - p0.y
			var ln := Vector2(dy, -dr).normalized()
			var verts: Array = []
			for a in [a0, a1]:
				var ca := cos(a)
				var sa := sin(a)
				verts.append([Vector3(p0.x * ca, p0.y, p0.x * sa),
					Vector3(ln.x * ca, ln.y, ln.x * sa), Vector2(float(i) / segments * uv_u_scale, float(j) / (n - 1))])
				verts.append([Vector3(p1.x * ca, p1.y, p1.x * sa),
					Vector3(ln.x * ca, ln.y, ln.x * sa), Vector2(float(i) / segments * uv_u_scale, float(j + 1) / (n - 1))])
			# quad: (a0,p0) (a1,p1) (a1,p0) / (a0,p0) (a0,p1) (a1,p1)
			# (winding chosen so the outward normal faces the camera)
			var quad: Array = [verts[0], verts[3], verts[2], verts[0], verts[1], verts[3]]
			for v in quad:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	return st.commit()

## Partial sphere shell. theta: horizontal angle from -Z (front), phi: from +Y top.
## UV u follows theta, v follows phi.
static func shell_mesh(radius: float, theta_min: float, theta_max: float,
		phi_min: float, phi_max: float, seg_u: int = 16, seg_v: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iu in range(seg_u):
		var t0 := lerpf(theta_min, theta_max, float(iu) / seg_u)
		var t1 := lerpf(theta_min, theta_max, float(iu + 1) / seg_u)
		for iv in range(seg_v):
			var p0 := lerpf(phi_min, phi_max, float(iv) / seg_v)
			var p1 := lerpf(phi_min, phi_max, float(iv + 1) / seg_v)
			var quad: Array = []
			for t in [t0, t1]:
				for p in [p0, p1]:
					var sp := sin(p)
					var pos := Vector3(radius * sp * sin(t), radius * cos(p), -radius * sp * cos(t))
					quad.append([pos, pos.normalized(),
						Vector2(float(iu + (1 if t == t1 else 0)) / seg_u,
							float(iv + (1 if p == p1 else 0)) / seg_v)])
			# quad order: (t0,p0) (t1,p0) (t1,p1) / (t0,p0) (t1,p1) (t0,p1)
			var order: Array = [quad[0], quad[2], quad[3], quad[0], quad[3], quad[1]]
			for v in order:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	return st.commit()

static func _cylinder(top_r: float, bot_r: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = height
	m.radial_segments = 12
	return m

static func _box(sx: float, sy: float, sz: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(sx, sy, sz)
	return m

## Build a companion body into the companion scene's node tree.
## def keys: shirt (Color), face (String res path), hair (String res path),
## hair_style (0 short, 1 cap, 2 curly), hair_radius (float).
static func build_companion(c: Node3D, def: Dictionary) -> void:
	var shirt_color: Color = def.get("shirt", Color(0.8, 0.2, 0.15))
	var face_tex: Texture2D = load(def.get("face", "res://assets/generated/face_chris.png"))
	var hair_tex: Texture2D = load(def.get("hair", "res://assets/generated/hair_short.png"))
	var hair_style: int = def.get("hair_style", 0)
	var hair_r: float = def.get("hair_radius", 0.106)

	var shirt := shirt_mat(shirt_color)
	var jeans := jeans_mat()
	var skin := skin_mat()
	var shoe := shoe_mat()

	# --- torso (lathe): hips -> waist -> chest -> shoulders -> neck ---
	var profile := PackedVector2Array([
		Vector2(0.140, 0.50), Vector2(0.185, 0.62), Vector2(0.170, 0.75),
		Vector2(0.155, 0.90), Vector2(0.170, 1.05), Vector2(0.200, 1.22),
		Vector2(0.205, 1.32), Vector2(0.190, 1.40), Vector2(0.130, 1.45),
		Vector2(0.075, 1.48), Vector2(0.060, 1.52),
	])
	var torso := c.get_node_or_null("Body/Torso") as MeshInstance3D
	if torso != null:
		torso.mesh = lathe_mesh(profile, 20, 2.0)
		torso.material_override = shirt

	# --- head ---
	var head := c.get_node_or_null("HeadPivot/Head") as MeshInstance3D
	if head != null:
		var sph := SphereMesh.new()
		sph.radius = 0.10
		sph.height = 0.20
		sph.radial_segments = 24
		sph.rings = 12
		head.mesh = sph
		head.material_override = skin
	var face := c.get_node_or_null("HeadPivot/Face") as MeshInstance3D
	if face != null:
		face.mesh = shell_mesh(0.104, deg_to_rad(-55), deg_to_rad(55),
			deg_to_rad(25), deg_to_rad(75), 16, 8)
		face.material_override = face_mat(face_tex)

	# --- hair: crown cap + back cap (runtime nodes) ---
	var head_pivot := c.get_node_or_null("HeadPivot") as Node3D
	if head_pivot != null:
		for old in ["HairTop", "HairBack", "Brim"]:
			var on := head_pivot.get_node_or_null(old)
			if on != null:
				on.queue_free()
		var top := MeshInstance3D.new()
		top.name = "HairTop"
		top.mesh = shell_mesh(hair_r, 0.0, TAU, deg_to_rad(0), deg_to_rad(55), 20, 6)
		top.material_override = hair_mat(hair_tex) if hair_style != 1 else cap_mat()
		head_pivot.add_child(top)
		var back := MeshInstance3D.new()
		back.name = "HairBack"
		back.mesh = shell_mesh(hair_r, deg_to_rad(125), deg_to_rad(235),
			deg_to_rad(40), deg_to_rad(100), 10, 6)
		back.material_override = hair_mat(hair_tex) if hair_style != 1 else cap_mat()
		head_pivot.add_child(back)
		if hair_style == 1:
			var brim := MeshInstance3D.new()
			brim.name = "Brim"
			brim.mesh = _box(0.16, 0.015, 0.12)
			brim.position = Vector3(0, 0.045, -0.13)
			brim.rotation.x = deg_to_rad(-8)
			brim.material_override = cap_mat()
			head_pivot.add_child(brim)

	# --- limbs ---
	for side in ["L", "R"]:
		var leg := c.get_node_or_null("Leg" + side) as Node3D
		if leg != null:
			var thigh := leg.get_node_or_null("Thigh") as MeshInstance3D
			if thigh != null:
				thigh.mesh = _cylinder(0.075, 0.060, 0.42)
				thigh.position = Vector3(0, -0.21, 0)
				thigh.material_override = jeans
			var shin_p := leg.get_node_or_null("ShinPivot") as Node3D
			if shin_p != null:
				var shin := shin_p.get_node_or_null("Shin") as MeshInstance3D
				if shin != null:
					shin.mesh = _cylinder(0.060, 0.048, 0.42)
					shin.position = Vector3(0, -0.21, 0)
					shin.material_override = jeans
				var shoe_m := shin_p.get_node_or_null("Shoe") as MeshInstance3D
				if shoe_m != null:
					shoe_m.mesh = _box(0.10, 0.07, 0.26)
					shoe_m.position = Vector3(0, -0.42, -0.05)
					shoe_m.material_override = shoe
		var arm := c.get_node_or_null("Arm" + side) as Node3D
		if arm != null:
			var upper := arm.get_node_or_null("UpperArm") as MeshInstance3D
			if upper != null:
				upper.mesh = _cylinder(0.050, 0.042, 0.28)
				upper.position = Vector3(0, -0.14, 0)
				upper.material_override = shirt
			var fore_p := arm.get_node_or_null("ForearmPivot") as Node3D
			if fore_p != null:
				var fore := fore_p.get_node_or_null("Forearm") as MeshInstance3D
				if fore != null:
					fore.mesh = _cylinder(0.042, 0.036, 0.26)
					fore.position = Vector3(0, -0.13, 0)
					fore.material_override = skin
				var hand := fore_p.get_node_or_null("Hand") as MeshInstance3D
				if hand != null:
					hand.mesh = _box(0.07, 0.13, 0.045)
					hand.position = Vector3(0, -0.30, 0)
					hand.material_override = skin

## The "ranger" figure: a tall dark silhouette — long coat, wide-brim hat,
## face lost in shadow. Built the same way, no face shell.
static func build_figure(root: Node3D) -> Node3D:
	var fig := Node3D.new()
	fig.name = "RangerFigure"
	var coat := _std(PLANKS_TEX, 0.95, PLANKS_NOR, Color(0.16, 0.15, 0.14))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.08)
	dark.roughness = 0.9
	# long coat: lathe from the ground to the shoulders
	var profile := PackedVector2Array([
		Vector2(0.30, 0.0), Vector2(0.28, 0.4), Vector2(0.22, 0.9),
		Vector2(0.20, 1.2), Vector2(0.23, 1.35), Vector2(0.14, 1.45),
		Vector2(0.07, 1.50),
	])
	var body := MeshInstance3D.new()
	body.name = "Coat"
	body.mesh = lathe_mesh(profile, 16, 1.5)
	body.material_override = coat
	fig.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sph := SphereMesh.new()
	sph.radius = 0.10
	sph.height = 0.20
	sph.radial_segments = 16
	sph.rings = 8
	head.mesh = sph
	head.position = Vector3(0, 1.62, 0)
	head.material_override = dark
	fig.add_child(head)
	# wide-brim hat: crown + brim
	var crown := MeshInstance3D.new()
	crown.name = "HatCrown"
	crown.mesh = _cylinder(0.09, 0.11, 0.12)
	crown.position = Vector3(0, 1.74, 0)
	crown.material_override = dark
	fig.add_child(crown)
	var brim := MeshInstance3D.new()
	brim.name = "HatBrim"
	brim.mesh = _cylinder(0.19, 0.19, 0.015)
	brim.position = Vector3(0, 1.69, 0)
	brim.material_override = dark
	fig.add_child(brim)
	root.add_child(fig)
	return fig

## Jayce's visible hands + the camcorder, parented under the player camera.
static func build_jayce_hands(camera: Camera3D) -> Node3D:
	var hands := Node3D.new()
	hands.name = "JayceHands"
	var skin := skin_mat()
	# Forearms rising from the bottom of the frame, hands gripping the camera.
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		arm.name = "ForearmL" if side < 0 else "ForearmR"
		arm.mesh = _cylinder(0.045, 0.038, 0.30)
		arm.position = Vector3(side * 0.16, -0.28, -0.42)
		arm.rotation = Vector3(deg_to_rad(-38), 0, side * deg_to_rad(-14))
		arm.material_override = skin
		hands.add_child(arm)
		var hand := MeshInstance3D.new()
		hand.name = "HandL" if side < 0 else "HandR"
		hand.mesh = _box(0.07, 0.11, 0.05)
		hand.position = Vector3(side * 0.10, -0.155, -0.55)
		hand.rotation = Vector3(deg_to_rad(-20), 0, side * deg_to_rad(-8))
		hand.material_override = skin
		hands.add_child(hand)
	# The camcorder itself: the real CC0 model, held at the bottom center.
	var cam_scene: PackedScene = load("res://assets/models/vintage_video_camera/vintage_video_camera.gltf")
	var cam := cam_scene.instantiate()
	cam.name = "Camcorder"
	cam.scale = Vector3.ONE * 0.55
	cam.position = Vector3(0, -0.20, -0.58)
	cam.rotation = Vector3(deg_to_rad(6), 0, 0)
	hands.add_child(cam)
	camera.add_child(hands)
	return hands
