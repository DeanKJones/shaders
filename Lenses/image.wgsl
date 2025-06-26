// Created by Justin Shrake - @j2rgb/2019
// An artistic lens dispersion effect. This is not intended to be physically realistic.

#define GRID 0
#if GRID
    #iChannel0 "Lenses/grid.wgsl"
#else
    #iChannel0 "Lenses/gridMoving.wgsl"
#endif
#include "Lenses/blur.wgsl"

#define SHOW_RING

// Box blur parameters for intersection softening
const float BOX_BLUR_SIZE = 8.0;     // Size of the box blur kernel
const float BOX_BLUR_STRENGTH = 0.9; // How much to blend with blurred result
const float INTERSECTION_WIDTH = 0.05; // Width of the intersection zone to blur



void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 lens_uv = fragCoord / iResolution.y;

    float vignette = pow(1.0 - dot(uv - 0.5, uv - 0.5), 2.2) * 1.2;
    float blurVignette = clamp(1.0 - pow(vignette, 1.4), 0.0, 1.0) + 0.0; // minBlur = 0.0
    
    // Sample base texture and add noise BEFORE lens processing
    vec3 tex = blurTex(uv, 0.03 / 4.0 * blurVignette, 4.0); 
    vec3 background_color = tex; // Store original background
    vec3 color = tex;
    
    // Two lens positions
    vec2 lens_pos1 = vec2(0.45, 0.7); // Fixed at top center
    vec2 lens_pos2 = vec2(0.15, 0.7); // Mouse controlled
    
    // Calculate center line between lenses
    float center_x = (lens_pos1.x + lens_pos2.x) * 0.5;
    float distance_from_center = abs(lens_uv.x - center_x);
    
    // Mouse-controlled infinity point (normalized mouse coordinates)
    vec2 mouse_norm = iMouse.xy / iResolution.xy;
    vec2 infinity_offset = (mouse_norm - 0.5) * 0.3; // Scale the offset range
    
    // Infinity circles - centered when aligned, move with mouse
    vec2 infinity_pos1 = lens_pos1 + infinity_offset;
    vec2 infinity_pos2 = lens_pos2 + infinity_offset;
    
    vec2 lens_delta1 = lens_uv - lens_pos1;
    vec2 lens_delta2 = lens_uv - lens_pos2;
    float lens_dist1 = length(lens_delta1);
    float lens_dist2 = length(lens_delta2);
    bool inlens = false;

    // Infinity circle deltas and distances
    vec2 infinity_delta1 = lens_uv - infinity_pos1;
    vec2 infinity_delta2 = lens_uv - infinity_pos2;
    float infinity_dist1 = length(infinity_delta1);
    float infinity_dist2 = length(infinity_delta2);

    // Lens parameters
    const float lens_radius = 0.2;
    const float lens_zoom = 2.5;
    const float lens_radius_fudge = 0.995;
    
    // Infinity circle parameters
    //const float infinity_radius = 0.28;
    //const float infinity_edge_sharpness = 0.025;
    //const float infinity_inner_radius = infinity_radius - infinity_edge_sharpness;

    float edge_power = 2.0;
    float dispersion_factor1 = pow(lens_dist1 / lens_radius, edge_power);
    float dispersion_factor2 = pow(lens_dist2 / lens_radius, edge_power);
    
    // IOR ratios for dispersion (air/glass)
    const float ior_base = 1.015;
    const float ior_step = 0.0075;
    float eta[6] = float[6](
        1.0 / ior_base,                    // red
        1.0 / (ior_base + ior_step),       // yellow  
        1.0 / (ior_base + 2.0 * ior_step), // green
        1.0 / (ior_base + 1.0 * ior_step), // cyan
        1.0 / (ior_base + 2.0 * ior_step), // blue
        1.0 / (ior_base + 1.0 * ior_step)  // violet
    );
    
    // Calculate lens influence factors with smooth falloff
    float influence1 = smoothstep(lens_radius, lens_radius * 0.001, lens_dist1);
    float influence2 = smoothstep(lens_radius, lens_radius * 0.5, lens_dist2);
    
    // Total influence for normalization
    float total_influence = influence1 + influence2;
    
    if (total_influence > 0.0) {
        // Normalize influences
        influence1 /= total_influence;
        influence2 /= total_influence;
        
        vec3 dispersed_color1 = color;
        vec3 dispersed_color2 = color;
        
        // Process first lens
        if (lens_dist1 <= lens_radius) {
            vec3 lens_normal1 = normalize(vec3(
                lens_delta1, 
                lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist1 * lens_dist1)
            ));
            
            vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
            float edge_factor = lens_dist1 / lens_radius;
            float dispersion_strength = edge_factor * edge_factor;

            vec3 samples[6];
            for(int i = 0; i < 6; i++) {
                float scaled_eta = 1.0 + (eta[i] - 1.0) * dispersion_strength;
                vec2 refract_offset = refract(incident, lens_normal1, scaled_eta).xy;
                vec3 sample_color = texture(iChannel0, uv + refract_offset).rgb;
                samples[i] = addNoise(sample_color, fragCoord + refract_offset * iResolution.xy);
            }
            
            // Extract color components
            float r = samples[0].r * 0.5;
            float g = samples[2].g * 0.5;  
            float b = samples[4].b * 0.5;
            float y = dot(vec3(2.0, 2.0, -1.0), samples[1]) / 6.0;
            float c = dot(vec3(-1.0, 2.0, 2.0), samples[3]) / 6.0;
            float v = dot(vec3(2.0, -1.0, 2.0), samples[5]) / 6.0;
            
            // Reconstruct RGB with spectral mixing
            dispersed_color1 = vec3(
                r + (2.0 * v + 2.0 * y - c) / 3.0,
                g + (2.0 * y + 2.0 * c - v) / 3.0,
                b + (2.0 * c + 2.0 * v - y) / 3.0
            );
            inlens = true;
        }
        
        // Process second lens
        if (lens_dist2 <= lens_radius) {
            vec3 lens_normal2 = normalize(vec3(
                lens_delta2, 
                lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist2 * lens_dist2)
            ));
            
            vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
            float edge_factor = lens_dist2 / lens_radius;
            float dispersion_strength = edge_factor * edge_factor;

            vec3 samples[6];
            for(int i = 0; i < 6; i++) {
                float scaled_eta = 1.0 + (eta[i] - 1.0) * dispersion_strength;
                vec2 refract_offset = refract(incident, lens_normal2, scaled_eta).xy;
                vec3 sample_color = texture(iChannel0, uv + refract_offset).rgb;
                samples[i] = addNoise(sample_color, fragCoord + refract_offset * iResolution.xy);
            }
            
            // Extract color components
            float r = samples[0].r * 0.5;
            float g = samples[2].g * 0.5;  
            float b = samples[4].b * 0.5;
            float y = dot(vec3(2.0, 2.0, -1.0), samples[1]) / 6.0;
            float c = dot(vec3(-1.0, 2.0, 2.0), samples[3]) / 6.0;
            float v = dot(vec3(2.0, -1.0, 2.0), samples[5]) / 6.0;
            
            // Reconstruct RGB with spectral mixing
            dispersed_color2 = vec3(
                r + (2.0 * v + 2.0 * y - c) / 3.0,
                g + (2.0 * y + 2.0 * c - v) / 3.0,
                b + (2.0 * c + 2.0 * v - y) / 3.0
            );
            inlens = true;
        }
        
        // Blend the lens effects based on normalized influences
        color = mix(tex, dispersed_color1 * influence1 + dispersed_color2 * influence2, 
                   min(1.0, total_influence * 2.0));
    }
    
    // Store the color before infinity masking for blur operations
    vec3 pre_mask_color = color;
    
    // ===== NEW INFINITY CIRCLES =====
    // Create edge masks for infinity circles - only show the edge rings
    float infinity_mask_strength = 0.0;
    
    // Mask 1: Only active within lens_pos1 circle
    // bool in_lens_area1 = lens_dist1 <= lens_radius + 0.02 && lens_dist2 > lens_radius || lens_dist1 <= lens_radius + 0.02 && lens_dist2 <= lens_radius && lens_uv.x > ((lens_pos1.x + lens_pos2.x) / 2.0);
    // if (in_lens_area1) {
    //     float infinity_edge1 = smoothstep(infinity_inner_radius, infinity_radius, infinity_dist1);
    //     float infinity_ring1 = infinity_edge1 * (smoothstep(infinity_inner_radius - infinity_edge_sharpness, infinity_inner_radius, infinity_dist1));
        
    //     // Apply the infinity ring mask to the color
    //     color = mix(color, vec3(0.0, 0.0, 0.0), infinity_ring1 * 1.0);
    //     infinity_mask_strength = max(infinity_mask_strength, infinity_ring1);
    // }
    
    // // Mask 2: Only active within lens_pos2 circle  
    // bool in_lens_area2 = lens_dist2 <= lens_radius + 0.02 && lens_dist1 > lens_radius || lens_dist2 <= lens_radius + 0.02 && lens_dist1 <= lens_radius && lens_uv.x < ((lens_pos1.x + lens_pos2.x) / 2.0);
    // if (in_lens_area2) {
    //     float infinity_edge2 = smoothstep(infinity_inner_radius, infinity_radius, infinity_dist2);
    //     float infinity_ring2 = infinity_edge2 * (smoothstep(infinity_inner_radius - infinity_edge_sharpness, infinity_inner_radius, infinity_dist2));
        
    //     // Apply the infinity ring mask to the color
    //     color = mix(color, vec3(0.0, 0.0, 0.0), infinity_ring2 * 1.0);
    //     infinity_mask_strength = max(infinity_mask_strength, infinity_ring2);
    // }
    
    // ===== INTERSECTION BLUR PASS =====
    // Calculate blur influence based on distance from center line
    float blur_influence = 1.0 - smoothstep(0.0, INTERSECTION_WIDTH, distance_from_center);
    
    // Only apply blur in the intersection zone between lenses
    bool in_intersection_zone = lens_uv.y >= min(lens_pos1.y, lens_pos2.y) - lens_radius && 
                               lens_uv.y <= max(lens_pos1.y, lens_pos2.y) + lens_radius &&
                               lens_uv.x >= min(lens_pos1.x, lens_pos2.x) - lens_radius && 
                               lens_uv.x <= max(lens_pos1.x, lens_pos2.x) + lens_radius;
    
    if (in_intersection_zone && blur_influence > 0.0 && infinity_mask_strength > 0.1) {
        // Use box blur to soften the intersection line
        //vec3 blurred_color = boxBlurIntersection(uv, color, background_color, BOX_BLUR_SIZE);
        
        // Alternative: Use Gaussian blur for smoother results
        vec3 blurred_color = gaussianBlurIntersection(uv, BOX_BLUR_SIZE);
        
        // Mix between original and blurred based on both blur influence and mask strength
        float final_blur_strength = blur_influence * infinity_mask_strength * BOX_BLUR_STRENGTH;
        color = mix(color, blurred_color, final_blur_strength);
    }
    
#ifdef SHOW_RING
    float distance1 = distance(lens_pos1, lens_uv);
    float distance2 = distance(lens_pos2, lens_uv);
    float ring1 = 1.0 - smoothstep(lens_radius - 0.2, lens_radius + 0.02, distance1);
    float ring2 = 1.0 - smoothstep(lens_radius - 0.2, lens_radius + 0.02, distance2);
    float combined_ring = max(ring1, ring2);

    color *= combined_ring * 3.0;
#endif
    
    fragColor = vec4(color, 1.0);
}