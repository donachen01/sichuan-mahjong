shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.018, 0.160, 0.126, 1.0);
uniform vec4 thread_highlight : source_color = vec4(0.055, 0.310, 0.240, 1.0);

varying vec3 rail_local_position;

void vertex() {
    rail_local_position = VERTEX;
}

void fragment() {
    // Object-space weave avoids the coarse UV-atlas blocks visible on the
    // front rail while remaining resolution-independent on Retina screens.
    vec3 textile_position = rail_local_position * vec3(46.0, 62.0, 46.0);
    float warp = 0.5 + 0.5 * sin(textile_position.x * 6.28318);
    float weft = 0.5 + 0.5 * sin((textile_position.z + textile_position.y * 0.42) * 6.28318);
    float crossed_thread = warp * weft;
    float leather_grain = 0.5 + 0.25 * sin(dot(textile_position.xz, vec2(2.17, 3.71)))
        + 0.25 * sin(dot(textile_position.zy, vec2(5.13, 1.83)) + 0.7);
    float long_grain = 0.5 + 0.5 * sin((rail_local_position.x * 19.0 + rail_local_position.z * 7.0) * 6.28318);
    float relief = crossed_thread * 0.050 + (leather_grain - 0.5) * 0.042 + long_grain * 0.016;
    ALBEDO = mix(base_color.rgb, thread_highlight.rgb, clamp(relief, 0.0, 0.12));
    ROUGHNESS = clamp(0.50 + (leather_grain - 0.5) * 0.09, 0.42, 0.60);
    METALLIC = 0.015;
}
