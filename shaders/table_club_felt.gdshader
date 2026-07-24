shader_type canvas_item;
render_mode unshaded, blend_mix;

// 全桌短绒桌布：以细密、无规则、方向交错的纤维覆盖整个桌面。
// 不绘制菱格、云纹、回纹或任何可读图案，近看有毛绒层次，远看保持安静。
uniform vec4 jade_deep : source_color = vec4(0.0196, 0.1569, 0.1255, 1.0);
uniform vec4 jade_base : source_color = vec4(0.0235, 0.1725, 0.1569, 1.0);
uniform vec4 jade_mid : source_color = vec4(0.0235, 0.2196, 0.1725, 1.0);
uniform vec4 jade_lift : source_color = vec4(0.0431, 0.2471, 0.2039, 1.0);
uniform vec4 jade_highlight : source_color = vec4(0.0706, 0.2471, 0.2078, 1.0);
uniform vec4 warm_light : source_color = vec4(0.7765, 0.6039, 0.3451, 1.0);
uniform float plush_strength : hint_range(0.0, 0.16) = 0.112;
uniform float fiber_density : hint_range(70.0, 260.0) = 148.0;
uniform float nap_variation : hint_range(0.0, 0.10) = 0.034;
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.50;
uniform float light_strength : hint_range(0.0, 0.25) = 0.205;
uniform float ambient_fill_strength : hint_range(0.0, 0.18) = 0.080;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	float random_a = hash21(cell + vec2(seed, seed * 1.73));
	float random_b = hash21(cell * 1.91 + vec2(seed * 2.31, seed));
	float angle = direction_bias + (random_a - 0.5) * 1.95;
	vec2 direction = vec2(cos(angle), sin(angle));
	vec2 normal_direction = vec2(-direction.y, direction.x);
	float across = abs(dot(local, normal_direction));
	float along = abs(dot(local, direction));
	float width = mix(0.026, 0.060, random_b);
	float length = mix(0.18, 0.43, random_a);
	float strand = 1.0 - smoothstep(width, width + 0.030, across);
	strand *= 1.0 - smoothstep(length, length + 0.075, along);
	return strand * mix(0.58, 1.0, random_b);
}

float full_surface_fiber(vec2 uv) {
	float layer_a = short_fiber(
		uv + vec2(0.0017, 0.0021),
		vec2(fiber_density, fiber_density * 0.62),
		2.7,
		0.16
	);
	float layer_b = short_fiber(
		uv.yx + vec2(0.0031, -0.0013),
		vec2(fiber_density * 1.27, fiber_density * 0.78),
		7.9,
		1.42
	);
	float layer_c = short_fiber(
		uv + vec2(-0.0023, 0.0037),
		vec2(fiber_density * 0.73, fiber_density * 0.49),
		13.4,
		-0.58
	);
	return clamp(layer_a * 0.48 + layer_b * 0.34 + layer_c * 0.28, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;

	float diagonal = clamp((1.0 - uv.x) * 0.58 + (1.0 - uv.y) * 0.42, 0.0, 1.0);
	float top_left_light = pow(diagonal, 2.30) * light_strength;
	float center_x = 1.0 - smoothstep(0.08, 0.54, abs(uv.x - 0.50));
	float center_y = 1.0 - smoothstep(0.06, 0.46, abs(uv.y - 0.43));
	float center_lift = center_x * center_y * 0.024;
	float neutral_fill = center_x * center_y * ambient_fill_strength;
	float upper_sheen = (1.0 - smoothstep(0.0, 0.22, uv.y)) * (0.45 + 0.55 * (1.0 - uv.x));
	vec3 base = mix(jade_deep.rgb, jade_base.rgb, 0.58 + diagonal * 0.18);
	base = mix(base, jade_mid.rgb, 0.24 + center_lift * 2.2);
	base += warm_light.rgb * top_left_light * 0.25;
	base += jade_highlight.rgb * (center_lift + neutral_fill * 0.22);
	base += warm_light.rgb * upper_sheen * light_strength * 0.035;

	// 大小两层绒毛明暗：短纤维提供真实毛边，低频绒向让整桌有柔软的顺逆毛层次。
	float plush_fiber = full_surface_fiber(uv);
	float plush_shadow = full_surface_fiber(uv + vec2(0.0012, 0.0010));
	float plush_nap = value_noise(uv * vec2(52.0, 34.0));
	float brushed_nap = value_noise(uv * vec2(118.0, 76.0) + vec2(17.0, 9.0));
	float nap_field = (plush_nap - 0.5) * 0.72 + (brushed_nap - 0.5) * 0.28;
	base += mix(jade_lift.rgb, vec3(0.24, 0.32, 0.29), 0.42) * plush_fiber * plush_strength * 0.86;
	base -= jade_deep.rgb * plush_shadow * plush_strength * 0.24;
	base += nap_field * nap_variation;

	// 细颗粒只破除色带，不形成任何规则图案。
	float grain = hash21(floor(uv * vec2(1540.0, 920.0))) - 0.5;
	base += grain * 0.010;

	vec2 centered = abs((uv - vec2(0.5)) * vec2(1.04, 1.0));
	float rectangular_edge = max(centered.x, centered.y);
	float corner_edge = length(centered * vec2(0.92, 1.0));
	float edge = max(
		smoothstep(0.35, 0.54, rectangular_edge),
		smoothstep(0.47, 0.76, corner_edge) * 0.72
	);
	float lower_right = smoothstep(0.32, 1.10, uv.x * 0.54 + uv.y * 0.46);
	base *= 1.0 - edge * vignette_strength;
	base *= 1.0 - lower_right * 0.075;

	COLOR = vec4(base, 1.0);
}
