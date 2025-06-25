// Created by Justin Shrake - @j2rgb/2019
// An artistic lens dispersion effect. This is not intended to be physically realistic.

#define GRID 0
#if GRID
    #iChannel0 "Lenses/grid.wgsl"
#else
    #iChannel0 "Lenses/gridMoving.wgsl"
#endif

#define SHOW_RING


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 lens_uv = fragCoord / iResolution.y;
    
    // Two lens positions
    vec2 lens_pos1 = vec2(0.4, 0.7); // Fixed at top center
    vec2 lens_pos2 = iMouse.xy == vec2(0) ? vec2(0.5, 0.3) : iMouse.xy / iResolution.y; // Mouse controlled
    
    vec2 lens_delta1 = lens_uv - lens_pos1;
    vec2 lens_delta2 = lens_uv - lens_pos2;
    float lens_dist1 = length(lens_delta1);
    float lens_dist2 = length(lens_delta2);

    // Lens parameters
    const float lens_radius = 0.25;
    const float lens_zoom = 1.25;
    const float lens_radius_fudge = 0.975;

    float edge_power = 2.0; // Increase for more edge concentration
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
    
    // Sample base texture
    vec3 tex = texture(iChannel0, uv).rgb;
    vec3 color = tex;
    
    // Calculate lens influence factors with smooth falloff
    float influence1 = smoothstep(lens_radius, lens_radius * 0.2, lens_dist1);
    float influence2 = smoothstep(lens_radius, lens_radius * 0.2, lens_dist2);
    
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
            // Scale dispersion based on distance from center
            float edge_factor = lens_dist1 / lens_radius;
            float dispersion_strength = edge_factor * edge_factor; // Quadratic falloff

            vec3 samples[6];
            for(int i = 0; i < 6; i++) {
                // Scale the IOR difference by distance from center
                float scaled_eta = 1.0 + (eta[i] - 1.0) * dispersion_strength;
                vec2 refract_offset = refract(incident, lens_normal1, scaled_eta).xy;
                samples[i] = texture(iChannel0, uv + refract_offset).rgb;
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
        }
        
        // Process second lens
        if (lens_dist2 <= lens_radius) {
            vec3 lens_normal2 = normalize(vec3(
                lens_delta2, 
                lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist2 * lens_dist2)
            ));
            
            vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
            
            // Scale dispersion based on distance from center
            float edge_factor = lens_dist2 / lens_radius;
            float dispersion_strength = edge_factor * edge_factor; // Quadratic falloff

            vec3 samples[6];
            for(int i = 0; i < 6; i++) {
                // Scale the IOR difference by distance from center
                float scaled_eta = 1.0 + (eta[i] - 1.0) * dispersion_strength;
                vec2 refract_offset = refract(incident, lens_normal2, scaled_eta).xy;
                samples[i] = texture(iChannel0, uv + refract_offset).rgb;
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
        }
        
        // Blend the lens effects based on normalized influences
        color = mix(tex, dispersed_color1 * influence1 + dispersed_color2 * influence2, 
                   min(1.0, total_influence * 2.0));
    }
    
#ifdef SHOW_RING
    float distance1 = distance(lens_pos1, lens_uv);
    float distance2 = distance(lens_pos2, lens_uv);
    float ring1 = smoothstep(distance1, 1.0, lens_radius);
    float ring2 = smoothstep(distance2, 1.0, lens_radius);
    float combined_ring = max(ring1, ring2);
    color *= combined_ring * 45.0;
#endif
    
    fragColor = vec4(color, 1.0);
}