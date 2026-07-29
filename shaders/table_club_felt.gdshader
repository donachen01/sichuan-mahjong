shader_type canvas_item;
render_mode unshaded, blend_mix;

// 2D fallback for the Deep Emerald short-nap material.  It intentionally uses
// low-frequency value noise instead of visible sine threads, grids or logos.
uniform vec4 table_edge : source_color = vec4(0.0392, 0.2941, 0.2549, 1.0); // #0A4B41
uniform vec4 table_base : source_color = vec4(0.0588, 0.4118, 0.3412, 1.0); // #0F6957
uniform vec4 table_center : source_color = vec4(0.0863, 0.4784, 0.3922, 1.0); // #167A64
uniform float nap_strength : hint_range(0.0, 0.05) = 0.028;
uniform float brocade_strength : hint_range(0.0, 0.04) = 0.024;
uniform float edge_darkening : hint_range(0.0, 0.10) = 0.065;
uniform float center_lift : hint_range(0.0, 0.08) = 0.045;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float outer_brocade(vec2 uv, float perimeter) {
	vec2 p = uv * vec2(8.0, 6.0);
	float meander_a = abs(value_noise(p + vec2(value_noise(p * 0.42), 0.0)) - 0.5);
	float meander_b = abs(value_noise(p.yx * 1.17 + 7.3) - 0.5);
	float relief = 1.0 - smoothstep(0.055, 0.18, min(meander_a, meander_b));
	return relief * perimeter;
}

void fragment() {
	vec2 centred = abs(UV - vec2(0.5)) * 2.0;
	float edge_distance = max(centred.x, centred.y);
	float edge = smoothstep(0.70, 1.0, edge_distance);
	float centre = 1.0 - smoothstep(0.0, 0.74, length(centred));
	float perimeter = smoothstep(0.82, 0.92, edge_distance);

	vec3 colour = mix(table_base.rgb, table_center.rgb, centre * center_lift);
	colour = mix(colour, table_edge.rgb, edge * edge_darkening);

	float broad_nap = value_noise(UV * vec2(42.0, 31.0));
	float fine_nap = value_noise(UV * vec2(177.0, 133.0) + 11.7);
	float nap = (broad_nap - 0.5) * 0.72 + (fine_nap - 0.5) * 0.28;
	colour *= 1.0 + nap * nap_strength;

	float brocade = outer_brocade(UV, perimeter);
	colour *= 1.0 + (brocade - 0.5 * perimeter) * brocade_strength;
	COLOR = vec4(colour, 1.0);
}
