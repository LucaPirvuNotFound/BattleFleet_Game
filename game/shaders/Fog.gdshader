shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform sampler2D fog_mask : hint_default_black;
uniform sampler2D noise_texture : repeat_enable;

// NEW: Grab the screen's depth texture to detect terrain intersections
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec4 fog_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float map_size = 1024.0;

// NEW: Fog controls
uniform float fog_density = 2.0; 
uniform float baseline_opacity : hint_range(0.0, 1.0) = 0.5;
uniform float edge_fade_distance : hint_range(0.0, 10.0) = 2.0;

varying vec2 world_xz;

void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    // --- 1. PROXIMITY FADE (Soft Intersections) ---
    // Read the depth buffer and calculate the real linear distance of the terrain behind the fog
    float depth = texture(depth_texture, SCREEN_UV).x;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    
    float terrain_depth = -view.z; // How far away the terrain/water is
    float fog_depth = -VERTEX.z;   // How far away the fog plane is
    
    // Fade out the alpha as the terrain gets closer to the fog plane
    float depth_fade = clamp((terrain_depth - fog_depth) / edge_fade_distance, 0.0, 1.0);


    // --- 2. FOG TEXTURING ---
    vec2 fog_uv = (world_xz / map_size) + 0.5;
    float mask_val = texture(fog_mask, fog_uv).r;
    vec4 noise_val = texture(noise_texture, fog_uv);
    
    
    // --- 3. OPACITY MATH ---
    // Make sure the noise never dips below the baseline
    float base_thickness = clamp(noise_val.r * fog_density, 0.0, 1.0);
    float noise_alpha = max(baseline_opacity, base_thickness);
    
    // Ships cut through the fog
    float visibility_alpha = 1.0 - mask_val;
    
    // Combine: Vision Mask * Noise Density * Base Color Alpha * Terrain Edge Fade
    float final_alpha = visibility_alpha * noise_alpha * fog_color.a * depth_fade;
    
    ALBEDO = fog_color.rgb * noise_val.rgb;
    ALPHA = final_alpha;
}