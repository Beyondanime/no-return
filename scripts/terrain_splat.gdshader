shader_type spatial;

// Starved Rock terrain: PBR texture splatting.
// Blend weights come from the vertex COLOR channels (baked in world_builder):
//   r = trail dirt, g = canyon/sandstone, b = scorched earth, a = river sand.
// Grass and dead leaves mix by a world-space noise so the forest floor reads
// as patches of lush grass (day, Ref 2) and dead leaves (fog/night, Ref 1).
// Steep slopes and canyon walls use triplanar sandstone; flat ground uses
// planar sampling. Normal maps are perturbed in world space (no tangents
// needed on the procedural terrain mesh).

uniform sampler2D grass_albedo;
uniform sampler2D grass_normal;
uniform sampler2D leaves_albedo;
uniform sampler2D leaves_normal;
uniform sampler2D dirt_albedo;
uniform sampler2D dirt_normal;
uniform sampler2D sandstone_albedo;
uniform sampler2D sandstone_normal;
uniform sampler2D sand_albedo;
uniform sampler2D scorch_albedo;
uniform vec3 crash_pos = vec3(-158.0, 1.0, -55.0);
uniform float uv_scale = 0.15;
uniform float wall_scale = 0.12;
uniform float normal_strength = 0.9;

varying vec3 wp;
varying vec3 wn;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 trip(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(3.0));
	b /= dot(b, vec3(1.0));
	return texture(t, p.zy * s).rgb * b.x
		+ texture(t, p.xz * s).rgb * b.y
		+ texture(t, p.xy * s).rgb * b.z;
}

vec3 trip_normal(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(3.0));
	b /= dot(b, vec3(1.0));
	vec3 nx = texture(t, p.zy * s).rgb * 2.0 - 1.0;
	vec3 ny = texture(t, p.xz * s).rgb * 2.0 - 1.0;
	vec3 nz = texture(t, p.xy * s).rgb * 2.0 - 1.0;
	vec3 wx = vec3(nx.z, nx.y, nx.x);
	vec3 wy = vec3(ny.x, ny.z, ny.y);
	vec3 wz = nz;
	return normalize(wx * b.x + wy * b.y + wz * b.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 w = COLOR; // r trail, g sandstone, b scorch, a sand
	float slope = clamp(1.0 - wn.y, 0.0, 1.0);
	// Steep ground is rock even outside the canyon bboxes.
	float wall_w = clamp(w.g + smoothstep(0.35, 0.75, slope) * 0.9, 0.0, 1.0);
	float trail_w = clamp(w.r * (1.0 - wall_w), 0.0, 1.0);
	float scorch_w = clamp(w.b, 0.0, 1.0);
	float sand_w = clamp(w.a * (1.0 - wall_w), 0.0, 1.0);
	float ground_w = clamp(1.0 - wall_w - trail_w - scorch_w - sand_w, 0.0, 1.0);

	// Ground patchiness: grass vs dead leaves.
	float patch = vnoise(wp.xz * 0.06);
	float patch2 = vnoise(wp.xz * 0.23 + 31.7);
	float leaf_w = clamp(0.35 + patch * 0.5 - patch2 * 0.15, 0.0, 1.0);

	vec2 uv = wp.xz * uv_scale;
	vec3 grass_a = texture(grass_albedo, uv).rgb;
	vec3 leaves_a = texture(leaves_albedo, uv).rgb;
	vec3 dirt_a = texture(dirt_albedo, uv).rgb;
	vec3 sand_a = texture(sand_albedo, uv).rgb;
	vec3 scorch_a = texture(scorch_albedo, uv).rgb;
	vec3 wall_a = trip(sandstone_albedo, wp, wn, wall_scale);

	vec3 ground_a = mix(grass_a * vec3(0.7, 1.0, 0.55), leaves_a, leaf_w);
	vec3 alb = ground_a * ground_w
		+ dirt_a * trail_w
		+ sand_a * sand_w
		+ scorch_a * scorch_w
		+ wall_a * 0.65 * wall_w;
	// Canyon bottoms read darker (crevice shading).
	alb *= 1.0 - w.g * 0.22;
	ALBEDO = alb;

	// Normals: planar for the ground layers, triplanar for the walls.
	vec3 gn = texture(grass_normal, uv).rgb * 2.0 - 1.0;
	vec3 ln = texture(leaves_normal, uv).rgb * 2.0 - 1.0;
	vec3 dn = texture(dirt_normal, uv).rgb * 2.0 - 1.0;
	// Planar mapping: T=+X, B=+Z, N=+Y -> world (tx, tz, ty).
	vec3 ground_n = mix(mix(gn, ln, leaf_w), dn, clamp(trail_w + sand_w + scorch_w, 0.0, 1.0));
	vec3 ground_nw = vec3(ground_n.x, ground_n.z, ground_n.y);
	vec3 wall_nw = trip_normal(sandstone_normal, wp, wn, wall_scale);
	vec3 n_world = normalize(mix(ground_nw, wall_nw, wall_w));
	// Perturb the geometric normal toward the texture normal.
	n_world = normalize(mix(wn, n_world, clamp(normal_strength, 0.0, 1.0)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float rough = mix(0.95, 0.85, wall_w);
	rough = mix(rough, 1.0, scorch_w);
	ROUGHNESS = rough;
	// Rough dirt/rock/leaves barely reflect the sky; a high specular
	// makes distant slopes viewed at a grazing angle wash white
	// (Fresnel sky reflection), which read as snow-covered hills.
	SPECULAR = 0.1;
}
