shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// The Illinois River: flowing water with a scrolling normal map, fresnel
// sky reflection and transparency at the banks.
uniform sampler2D normal_tex;
uniform vec4 deep_color : source_color = vec4(0.02, 0.06, 0.06, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.06, 0.16, 0.15, 1.0);
uniform vec4 sky_color : source_color = vec4(0.42, 0.52, 0.60, 1.0);
uniform float flow_speed = 0.025;
uniform float normal_strength = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Two scrolling normal layers, different scale/speed/direction.
	vec2 uv1 = wp.xz * 0.09 + vec2(TIME * flow_speed, TIME * flow_speed * 0.35);
	vec2 uv2 = wp.xz * 0.045 + vec2(-TIME * flow_speed * 0.55, TIME * flow_speed * 0.8);
	vec3 n1 = texture(normal_tex, uv1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, uv2).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3(n1.x + n2.x, 2.0, n1.y + n2.y));
	vec3 n_world = normalize(mix(vec3(0.0, 1.0, 0.0), n, clamp(normal_strength, 0.0, 1.0)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// Fresnel: looking down you see the deep water, at a grazing angle the sky.
	float fres = pow(1.0 - clamp(dot(NORMAL, vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 3.0);
	vec3 col = mix(mix(deep_color.rgb, shallow_color.rgb, 0.35 + 0.3 * n.x), sky_color.rgb, fres * 0.55);
	ALBEDO = col;
	ALPHA = 0.92;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
