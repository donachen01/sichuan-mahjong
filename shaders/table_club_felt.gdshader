shader_type canvas_item;
render_mode unshaded, blend_mix;

// “蜀锦玉案”牌桌底材：低饱和墨玉、细密织纹、左上暖光与四周暗角。
// 该层只负责桌面材质，不改变任何 UI 节点的布局或交互区域。
uniform vec4 jade_deep : source_color = vec4(0.0196, 0.1569, 0.1255, 1.0); // #052820
uniform vec4 jade_base : source_color = vec4(0.0235, 0.1725, 0.1569, 1.0); // #062c28
uniform vec4 jade_mid : source_color = vec4(0.0235, 0.2196, 0.1725, 1.0);  // #06382c
uniform vec4 jade_lift : source_color = vec4(0.0431, 0.2471, 0.2039, 1.0); // #0b3f34
uniform vec4 jade_highlight : source_color = vec4(0.0706, 0.2471, 0.2078, 1.0); // #123f35
uniform vec4 warm_light : source_color = vec4(0.7765, 0.6039, 0.3451, 1.0); // old brass
uniform float brocade_opacity : hint_range(0.0, 0.12) = 0.065;
uniform float weave_opacity : hint_range(0.0, 0.10) = 0.035;
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.50;
uniform float light_strength : hint_range(0.0, 0.25) = 0.205;
uniform float ambient_fill_strength : hint_range(0.0, 0.18) = 0.080;
uniform float brocade_relief : hint_range(0.0, 1.0) = 0.560;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float line_mask(float value, float width) {
	float d = abs(fract(value) - 0.5);
	return 1.0 - smoothstep(width, width + 0.055, d);
}

float thin_band(float distance_value, float width) {
	return 1.0 - smoothstep(width, width + 0.018, abs(distance_value));
}

// 回纹：小尺寸折线回环，只取断续的经纬压纹。
float huiwen_motif(vec2 uv) {
	vec2 p = fract(uv * vec2(18.0, 14.0)) - 0.5;
	float ring = thin_band(max(abs(p.x), abs(p.y)) - 0.31, 0.018);
	float inner = thin_band(max(abs(p.x + 0.08), abs(p.y - 0.08)) - 0.16, 0.016);
	float break_gate = smoothstep(0.02, 0.09, abs(p.x + p.y * 0.72));
	return max(ring * break_gate, inner * (1.0 - break_gate * 0.42));
}

// 云雷纹：细小旋雷而非大面积云头。
float yunlei_motif(vec2 uv) {
	vec2 p = fract(uv * vec2(22.0, 16.0)) - 0.5;
	float radius = length(p);
	float angle = atan(p.y, p.x) / 6.2831853;
	float spiral = abs(fract(radius * 5.2 - angle * 1.35) - 0.5);
	return (1.0 - smoothstep(0.035, 0.085, spiral)) * (1.0 - smoothstep(0.12, 0.44, radius));
}

// 菱格锦纹：密度高、线条细，远看只是织物光泽。
float diamond_brocade(vec2 uv) {
	float a = line_mask((uv.x + uv.y) * 34.0, 0.018);
	float b = line_mask((uv.x - uv.y) * 34.0, 0.018);
	return a * b;
}

// 卷草纹：低振幅正弦枝叶，小于牌面笔画的视觉权重。
float scroll_grass_motif(vec2 uv) {
	vec2 p = uv * vec2(15.0, 18.0);
	float stem = thin_band(fract(p.y + sin(p.x * 1.75) * 0.13) - 0.5, 0.018);
	float leaf = thin_band(fract(p.x + cos(p.y * 1.55) * 0.11) - 0.5, 0.015);
	return max(stem * 0.82, stem * leaf);
}

// 缠枝纹：两条相位相反的细枝交织，做成丝线浮光。
float intertwined_branch_motif(vec2 uv) {
	vec2 p = uv * vec2(13.0, 19.0);
	float branch_a = thin_band(fract(p.y + sin(p.x * 1.25) * 0.16) - 0.5, 0.014);
	float branch_b = thin_band(fract(p.y - sin(p.x * 1.25) * 0.16 + 0.5) - 0.5, 0.014);
	return max(branch_a, branch_b);
}

float shu_brocade_pattern(vec2 uv) {
	float huiwen = huiwen_motif(uv);
	float yunlei = yunlei_motif(uv + vec2(0.017, 0.009));
	float diamond = diamond_brocade(uv);
	float scroll_grass = scroll_grass_motif(uv + vec2(0.031, 0.0));
	float intertwined_branch = intertwined_branch_motif(uv + vec2(0.0, 0.021));
	return clamp(
		huiwen * 0.18
		+ yunlei * 0.16
		+ diamond * 0.28
		+ scroll_grass * 0.18
		+ intertwined_branch * 0.20,
		0.0,
		1.0
	);
}

void fragment() {
	vec2 uv = UV;

	// 纯方向性光场：不使用任何位于桌面内部的径向光源，从根源上
	// 避免中央/左侧出现大圆形亮斑。所有受光统一来自左上。
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

	// 高频经纬纱与低对比菱格锦纹；纹理只在近看时被感知。
	float warp = line_mask(uv.x * 460.0 + sin(uv.y * 61.0) * 0.42, 0.010);
	float weft = line_mask(uv.y * 410.0 + cos(uv.x * 53.0) * 0.38, 0.010);
	float weave = (warp + weft) * 0.5;
	base += jade_lift.rgb * weave * weave_opacity * 0.26;

	// 4%-10% 的参数是整层“锦纹墨量”，明暗两次偏移形成织物/压纹，不像贴图浮在表面。
	float brocade_high = shu_brocade_pattern(uv + vec2(-0.00055, -0.00048));
	float brocade_shadow = shu_brocade_pattern(uv + vec2(0.00072, 0.00064));
	float motif_phase = 0.68 + 0.32 * sin(uv.x * 17.0 + sin(uv.y * 9.0));
	float cell_variation = 0.58 + 0.42 * hash21(floor(uv * vec2(19.0, 13.0)));
	float motif_gate = motif_phase * cell_variation;
	base += mix(jade_highlight.rgb, warm_light.rgb, 0.16) * brocade_high * motif_gate * brocade_opacity * (0.34 + brocade_relief * 0.15);
	base -= jade_deep.rgb * brocade_shadow * brocade_opacity * (0.18 + brocade_relief * 0.12);

	// 极细皮革/绒面颗粒，避免均匀色块产生塑料感。
	float grain = hash21(floor(uv * vec2(1280.0, 720.0))) - 0.5;
	base += grain * 0.012;

	// 四周暗角，右下略重；不压暗中央牌面读取区域。
	vec2 centered = abs((uv - vec2(0.5)) * vec2(1.04, 1.0));
	float rectangular_edge = max(centered.x, centered.y);
	float corner_edge = length(centered * vec2(0.92, 1.0));
	float edge = max(smoothstep(0.35, 0.54, rectangular_edge), smoothstep(0.47, 0.76, corner_edge) * 0.72);
	float lower_right = smoothstep(0.32, 1.10, uv.x * 0.54 + uv.y * 0.46);
	base *= 1.0 - edge * vignette_strength;
	base *= 1.0 - lower_right * 0.075;

	COLOR = vec4(base, 1.0);
}
