shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Reference-green woven felt: a broad emerald centre, darker perimeter,
// Retina-scale crossed threads, and low-relief cloud scrolls at the edges.
// The pattern is procedural and deliberately contains no brand mark or text.
uniform vec4 edge_emerald : source_color = vec4(0.016, 0.235, 0.176, 1.0);
uniform vec4 base_emerald : source_color = vec4(0.020, 0.430, 0.329, 1.0);
uniform vec4 center_emerald : source_color = vec4(0.030, 0.570, 0.435, 1.0);
uniform vec4 thread_highlight : source_color = vec4(0.120, 0.690, 0.548, 1.0);
uniform vec4 relief_shadow : source_color = vec4(0.004, 0.160, 0.116, 1.0);
uniform float weave_strength : hint_range(0.0, 0.12) = 0.046;
uniform float relief_strength : hint_range(0.0, 0.12) = 0.020;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float fine_weave(vec2 uv) {
	vec2 p = uv * vec2(760.0, 520.0);
	float warp = 0.5 + 0.5 * sin((p.x + p.y * 0.55) * 6.2831853);
	float weft = 0.5 + 0.5 * sin((p.x - p.y * 0.55) * 6.2831853);
	float tiny_warp = 0.5 + 0.5 * sin((p.x * 0.47 + p.y) * 6.2831853);
	return warp * weft * 0.62 + tiny_warp * 0.38;
}

float ring_line(vec2 p, vec2 centre, float radius, float width) {
	return 1.0 - smoothstep(width, width * 1.8, abs(length(p - centre) - radius));
}

float cloud_scroll(vec2 uv) {
	// Repeat broad, flowing arcs only near the perimeter. Mirrored rings and
	// short bridges approximate the embossed scroll/cloud language in the
	// supplied reference while keeping the centre quiet behind the tiles.
	vec2 p = vec2(fract(uv.x * 3.15), fract(uv.y * 4.20));
	float curl_a = ring_line(p, vec2(0.30, 0.48), 0.18, 0.018);
	float curl_b = ring_line(p, vec2(0.57, 0.49), 0.13, 0.016);
	float bridge = (1.0 - smoothstep(0.018, 0.032, abs(p.y - 0.49)))
		* smoothstep(0.34, 0.42, p.x) * (1.0 - smoothstep(0.65, 0.73, p.x));
	float edge_mask = smoothstep(0.30, 0.47, max(abs(uv.x - 0.5), abs(uv.y - 0.5)));
	return clamp(max(max(curl_a, curl_b), bridge) * edge_mask, 0.0, 1.0);
}

void fragment() {
	vec2 centred = abs(UV - vec2(0.5));
	float edge = smoothstep(0.28, 0.53, max(centred.x * 1.02, centred.y));
	float centre_x = 1.0 - smoothstep(0.16, 0.49, centred.x);
	float centre_y = 1.0 - smoothstep(0.12, 0.49, centred.y);
	float centre_lift = centre_x * centre_y;
	float upper_left_light = pow(clamp((1.0 - UV.x) * 0.46 + (1.0 - UV.y) * 0.54, 0.0, 1.0), 2.2);

	vec3 colour = mix(base_emerald.rgb, center_emerald.rgb, centre_lift * 0.78);
	colour = mix(colour, edge_emerald.rgb, edge * 0.83);
	colour += center_emerald.rgb * upper_left_light * 0.070;

	float weave = fine_weave(UV);
	float crossed_shadow = fine_weave(UV + vec2(0.0009, 0.0012));
	colour += thread_highlight.rgb * weave * weave_strength;
	colour -= relief_shadow.rgb * crossed_shadow * weave_strength * 0.62;

	float scroll = cloud_scroll(UV);
	float scroll_shadow = cloud_scroll(UV + vec2(0.0036, 0.0044));
	colour += thread_highlight.rgb * scroll * relief_strength;
	colour -= relief_shadow.rgb * scroll_shadow * relief_strength * 0.80;

	float grain = hash21(floor(UV * vec2(1660.0, 1040.0))) - 0.5;
	colour += grain * 0.010;

	ALBEDO = colour;
	ROUGHNESS = clamp(0.89 + (weave - 0.5) * 0.035 + scroll * 0.018, 0.86, 0.94);
	METALLIC = 0.0;
	ALPHA = 1.0;
}
