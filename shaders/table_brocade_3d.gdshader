shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 far_tint : source_color = vec4(0.38, 0.50, 0.63, 0.14);
uniform vec4 near_tint : source_color = vec4(0.22, 0.25, 0.38, 0.72);
uniform float pattern_scale : hint_range(3.0, 24.0) = 18.0;

float line_mask(float value, float width) {
    float distance_to_line = abs(fract(value) - 0.5);
    return 1.0 - smoothstep(width, width + fwidth(value) * 1.5, distance_to_line);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 p = UV * pattern_scale;
    float diagonal_a = line_mask(p.x + p.y, 0.018);
    float diagonal_b = line_mask(p.x - p.y, 0.018);
    vec2 cell = fract(p * 0.5) - 0.5;
    float ring = 1.0 - smoothstep(0.016, 0.035, abs(length(cell) - 0.22));
    float weave = max(max(diagonal_a, diagonal_b) * 0.34, ring * 0.28);
	// A broad Sichuan-brocade underprint gives the blue cloth a readable dark
	// texture on phone screens. The motif is value-only (never a bright decal):
	// interlocked lozenges, small seal rings and a restrained cloud-wave band.
	vec2 motif_uv = UV * vec2(6.0, 5.0);
	vec2 motif_cell = fract(motif_uv) - 0.5;
	float lozenge_distance = abs(motif_cell.x) + abs(motif_cell.y);
	float lozenge = 1.0 - smoothstep(0.035, 0.070, abs(lozenge_distance - 0.34));
	float seal_ring = 1.0 - smoothstep(0.025, 0.060, abs(length(motif_cell * vec2(1.0, 1.25)) - 0.17));
	float cloud_wave = 0.5 + 0.5 * sin((motif_uv.x * 2.0 + sin(motif_uv.y * 6.2831)) * 3.1416);
	cloud_wave = smoothstep(0.80, 0.96, cloud_wave) * smoothstep(0.20, 0.44, abs(motif_cell.y));
	float dark_pattern = clamp(max(lozenge * 0.72, max(seal_ring * 0.34, cloud_wave * 0.22)), 0.0, 1.0);
	vec2 microfiber_uv = UV * vec2(980.0, 760.0);
	float microfiber = hash21(floor(microfiber_uv));
	float nap = 0.5 + 0.5 * sin((microfiber_uv.x + microfiber_uv.y * 0.73) * 0.72);
	// The physical table extends well beyond the camera crop. Compress the
	// useful gradient into the visible UV range so the screen still receives a
	// clear far/middle/near hierarchy.
	float depth = smoothstep(0.02, 0.76, UV.y);
	vec3 depth_color = mix(far_tint.rgb, near_tint.rgb, depth);
	// The pattern is pressed into the cloth, not printed on top. It therefore
	// changes local value by at most a few percent and never competes with tiles.
	ALBEDO = depth_color * (1.0 - weave * 0.035 - dark_pattern * 0.10 + (microfiber - 0.5) * 0.026 + (nap - 0.5) * 0.012);
    ROUGHNESS = clamp(0.90 + (microfiber - 0.5) * 0.055, 0.86, 0.94);
	ALPHA = mix(far_tint.a, near_tint.a, depth);
}
