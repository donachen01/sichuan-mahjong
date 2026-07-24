shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 far_tint : source_color = vec4(0.38, 0.50, 0.63, 0.18);
uniform vec4 near_tint : source_color = vec4(0.22, 0.25, 0.38, 0.76);
uniform float plush_strength : hint_range(0.0, 0.16) = 0.120;
uniform float fiber_density : hint_range(70.0, 260.0) = 136.0;
uniform float nap_variation : hint_range(0.0, 0.10) = 0.028;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 43.17);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float short_fiber(vec2 uv, vec2 density, float seed, float direction_bias) {
	vec2 fiber_uv = uv * density;
	vec2 cell = floor(fiber_uv);
	vec2 local = fract(fiber_uv) - 0.5;
	float random_a = hash21(cell + vec2(seed, seed * 1.61));
	float random_b = hash21(cell * 1.83 + vec2(seed * 2.17, seed));
	float angle = direction_bias + (random_a - 0.5) * 2.10;
	vec2 direction = vec2(cos(angle), sin(angle));
	vec2 normal_direction = vec2(-direction.y, direction.x);
	float across = abs(dot(local, normal_direction));
	float along = abs(dot(local, direction));
	float width = mix(0.028, 0.064, random_b);
	float length = mix(0.18, 0.44, random_a);
	float strand = 1.0 - smoothstep(width, width + 0.032, across);
	strand *= 1.0 - smoothstep(length, length + 0.080, along);
	return strand * mix(0.56, 1.0, random_b);
}

float full_surface_fiber(vec2 uv) {
	float layer_a = short_fiber(
		uv + vec2(0.0011, 0.0017),
		vec2(fiber_density, fiber_density * 0.64),
		3.1,
		0.18
	);
	float layer_b = short_fiber(
		uv.yx + vec2(0.0029, -0.0019),
		vec2(fiber_density * 1.23, fiber_density * 0.76),
		8.3,
		1.48
	);
	float layer_c = short_fiber(
		uv + vec2(-0.0021, 0.0033),
		vec2(fiber_density * 0.71, fiber_density * 0.47),
		14.7,
		-0.52
	);
	return clamp(layer_a * 0.48 + layer_b * 0.35 + layer_c * 0.28, 0.0, 1.0);
}

void fragment() {
	// 透视深度色阶保留桌面空间感，但整块表面使用同一层连续短绒，不再叠加暗纹图案。
	float depth = smoothstep(0.02, 0.76, UV.y);
	vec3 depth_color = mix(far_tint.rgb, near_tint.rgb, depth);
	float plush_fiber = full_surface_fiber(UV);
	float plush_shadow = full_surface_fiber(UV + vec2(0.0013, 0.0010));
	float plush_nap = value_noise(UV * vec2(56.0, 38.0));
	float crossed_nap = value_noise(UV.yx * vec2(122.0, 82.0) + vec2(19.0, 7.0));
	float nap_field = (plush_nap - 0.5) * 0.72 + (crossed_nap - 0.5) * 0.28;
	float micro_grain = hash21(floor(UV * vec2(1240.0, 860.0))) - 0.5;

	vec3 fiber_light = vec3(0.34, 0.37, 0.44);
	ALBEDO = depth_color;
	ALBEDO += fiber_light * plush_fiber * plush_strength;
	ALBEDO -= depth_color * plush_shadow * plush_strength * 0.22;
	ALBEDO += nap_field * nap_variation;
	ALBEDO += micro_grain * 0.012;
	ROUGHNESS = clamp(0.925 + (plush_nap - 0.5) * 0.050 - plush_fiber * 0.018, 0.88, 0.96);
	ALPHA = mix(far_tint.a, near_tint.a, depth);
}
