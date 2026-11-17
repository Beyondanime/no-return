shader_type spatial;

// Generic world-space triplanar PBR material (cabins, truck, fences, props).
// Real textures, no UV stretching on box geometry.
uniform sampler2D albedo_tex;
uniform sampler2D normal_tex;
uniform sampler2D rough_tex;
uniform float tex_scale = 0.25;
uniform float normal_strength = 1.0;
uniform float roughness = 0.85;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 trip(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(3.0));
	b /= dot(b, vec3(1.0));
	return texture(t, p.zy * s).rgb * b.x
		+ texture(t, p.xz * s).rgb * b.y
		+ texture(t, p.xy * s).rgb * b.z;
}

// Triplanar normal: each projection's tangent-space normal swizzled to world.
vec3 trip_normal(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(3.0));
	b /= dot(b, vec3(1.0));
	vec3 nx = texture(t, p.zy * s).rgb * 2.0 - 1.0;
	vec3 ny = texture(t, p.xz * s).rgb * 2.0 - 1.0;
	vec3 nz = texture(t, p.xy * s).rgb * 2.0 - 1.0;
	// X plane: T=+Z, B=+Y, N=+X  -> (tz, ty, tx)
	// Y plane: T=+X, B=+Z, N=+Y  -> (tx, tz, ty)
	// Z plane: T=+X, B=+Y, N=+Z  -> (tx, ty, tz)
	vec3 wx = vec3(nx.z, nx.y, nx.x);
	vec3 wy = vec3(ny.x, ny.z, ny.y);
	vec3 wz = nz;
	return normalize(wx * b.x + wy * b.y + wz * b.z);
}

void fragment() {
	vec3 alb = trip(albedo_tex, wp, wn, tex_scale) * tint.rgb;
	ALBEDO = alb;
	vec3 nrm = trip_normal(normal_tex, wp, wn, tex_scale);
	// Blend geometric normal toward the texture normal.
	vec3 n_world = normalize(mix(wn, nrm, clamp(normal_strength, 0.0, 1.0)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float r = trip(rough_tex, wp, wn, tex_scale).g;
	ROUGHNESS = clamp(r * roughness, 0.05, 1.0);
	SPECULAR = 0.5;
}
