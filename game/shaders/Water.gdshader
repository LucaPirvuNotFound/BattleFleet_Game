shader_type spatial;
render_mode depth_draw_always, cull_back;

uniform vec3 albedo : source_color = vec3(0.0, 0.4, 0.8);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D texture_normal1 : hint_normal;
uniform sampler2D texture_normal2 : hint_normal;
uniform sampler2D wave;

uniform float noise_scale = 10.0;
uniform float height_scale = 0.15;
uniform vec2 wave_dir1 = vec2(2.0, 0.0);
uniform vec2 wave_dir2 = vec2(0.0, 1.0);
uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.015;

uniform float edge_scale = 0.2; // Represents the thickness of the foam line
uniform vec3 edge_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying float height;
varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    height = texture(wave, world_pos.xz / noise_scale + TIME * time_scale).r;
    VERTEX.y += height * height_scale;
}

void fragment() {
    // 1. Setup scrolling coordinates for normal maps
    vec2 time1 = (TIME * wave_dir1) * time_scale;
    vec2 time2 = (TIME * wave_dir2) * time_scale;
    
    // 2. Modern Godot 4 depth linearization
    float depth_raw = texture(depth_texture, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float linear_depth = -view.z;
    
    // 3. Get depth of the current water fragment surface
    float water_depth = -VERTEX.z;
    
    // 4. Calculate depth difference
    float z_dif = linear_depth - water_depth;
    
    // 5. Mix normal maps for standard water waves
    vec3 normal_mix = mix(
        texture(texture_normal1, world_pos.xz * 0.05 + time1).rgb,
        texture(texture_normal2, world_pos.xz * 0.05 + time2).rgb,
        0.5
    );
    
    // 6. Smooth or step edge blend
    // Lower z_dif means closer to geometry intersection.
    float foam_factor = step(z_dif, edge_scale); 
    // Guard against showing foam on geometry *in front* of the water
    foam_factor *= step(0.0, z_dif); 

    // Combine albedo and foam edge
    ALBEDO = mix(albedo, edge_color, foam_factor);
    
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = normal_mix;
}