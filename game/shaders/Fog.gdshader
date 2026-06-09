shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D fog_mask : hint_default_black;
uniform sampler2D noise_texture : repeat_enable;

uniform vec4 fog_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float map_size = 1024.0;

uniform float fog_density = 2.0;
uniform float baseline_opacity : hint_range(0.0, 1.0) = 0.5;

varying vec2 world_xz;

void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 fog_uv = (world_xz / map_size) + 0.5;
    float outside_map = max(max(-fog_uv.x, fog_uv.x - 1.0), max(-fog_uv.y, fog_uv.y - 1.0));
    float mask_val = outside_map > 0.0 ? 0.0 : texture(fog_mask, fog_uv).r;
    vec4 noise_val = texture(noise_texture, fog_uv);

    float base_thickness = clamp(noise_val.r * fog_density, 0.0, 1.0);
    float noise_alpha = max(baseline_opacity, base_thickness);

    float cleared = smoothstep(0.05, 0.92, mask_val);
    float visibility_alpha = 1.0 - cleared;
    visibility_alpha = max(visibility_alpha, smoothstep(0.0, 0.06, outside_map));

    float final_alpha = visibility_alpha * noise_alpha * fog_color.a;

    ALBEDO = fog_color.rgb * noise_val.rgb;
    ALPHA = final_alpha;
}