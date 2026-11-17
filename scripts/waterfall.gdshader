shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

// Waterfall veil: white falling streaks scrolling downward, fading at the
// top and bottom edges, slightly emissive so it reads in the canyon gloom.
uniform sampler2D streak_tex;
uniform float fall_speed = 0.55;
uniform float brightness = 1.1;

void fragment() {
	vec2 uv = UV;
	// Two layers scrolling at different speeds for depth.
	vec2 uv1 = vec2(uv.x, fract(uv.y - TIME * fall_speed));
	vec2 uv2 = vec2(uv.x * 1.7 + 0.37, fract(uv.y - TIME * fall_speed * 1.6));
	vec4 s1 = texture(streak_tex, uv1);
	vec4 s2 = texture(streak_tex, uv2);
	float a = clamp(s1.a * 1.0 + s2.a * 0.6, 0.0, 1.0);
	// Fade at the lip and at the pool.
	a *= smoothstep(0.0, 0.12, uv.y) * smoothstep(1.0, 0.82, uv.y);
	vec3 col = mix(s1.rgb, s2.rgb, 0.4) * brightness;
	ALBEDO = col;
	EMISSION = col * 0.55;
	ALPHA = a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.5;
}
