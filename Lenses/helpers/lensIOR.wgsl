// Lens dispersion and refraction functions
#include "Lenses/noise.wgsl"

// Apply chromatic dispersion effect for a single lens
vec3 applyLensDispersion(vec2 uv, vec2 fragCoord, vec2 lens_pos, float lens_dist, float lens_radius, float lens_zoom, float lens_radius_fudge) {
    if (lens_dist > lens_radius) {
        return vec3(0.0); // No effect outside lens
    }
    
    vec2 lens_delta = (fragCoord / iResolution.y) - lens_pos;
    vec3 lens_normal = normalize(vec3(
        lens_delta, 
        lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist * lens_dist)
    ));
    
    vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
    float edge_factor = lens_dist / lens_radius;
    float dispersion_strength = edge_factor * edge_factor;
    
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
    
    vec3 samples[6];
    for(int i = 0; i < 6; i++) {
        float scaled_eta = 1.0 + (eta[i] - 1.0) * dispersion_strength;
        vec2 refract_offset = refract(incident, lens_normal, scaled_eta).xy;
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
    return vec3(
        r + (2.0 * v + 2.0 * y - c) / 3.0,
        g + (2.0 * y + 2.0 * c - v) / 3.0,
        b + (2.0 * c + 2.0 * v - y) / 3.0
    );
}

// Apply dual lens dispersion effect
vec3 applyDualLensDispersion(vec2 uv, vec2 fragCoord, vec2 lens_pos1, vec2 lens_pos2, vec3 base_color) {
    vec2 lens_uv = fragCoord / iResolution.y;
    
    float lens_dist1 = distance(lens_uv, lens_pos1);
    float lens_dist2 = distance(lens_uv, lens_pos2);
    
    // Lens parameters
    const float lens_radius = 0.2;
    const float lens_zoom = 2.5;
    const float lens_radius_fudge = 0.995;
    
    // Calculate lens influence factors with smooth falloff
    float influence1 = smoothstep(lens_radius, lens_radius * 0.001, lens_dist1);
    float influence2 = smoothstep(lens_radius, lens_radius * 0.5, lens_dist2);
    
    // Total influence for normalization
    float total_influence = influence1 + influence2;
    
    if (total_influence <= 0.0) {
        return base_color;
    }
    
    // Normalize influences
    influence1 /= total_influence;
    influence2 /= total_influence;
    
    // Apply dispersion for each lens
    vec3 dispersed_color1 = applyLensDispersion(uv, fragCoord, lens_pos1, lens_dist1, lens_radius, lens_zoom, lens_radius_fudge);
    vec3 dispersed_color2 = applyLensDispersion(uv, fragCoord, lens_pos2, lens_dist2, lens_radius, lens_zoom, lens_radius_fudge);
    
    // Use base color if no dispersion occurred
    if (lens_dist1 > lens_radius) dispersed_color1 = base_color;
    if (lens_dist2 > lens_radius) dispersed_color2 = base_color;
    
    // Blend the lens effects based on normalized influences
    return mix(base_color, dispersed_color1 * influence1 + dispersed_color2 * influence2, 
               min(1.0, total_influence * 2.0));
}