// Created by Justin Shrake - @j2rgb/2019
// An artistic lens dispersion effect. This is not intended to be physically realistic.

#iChannel0 "Lenses/grid.wgsl"
#define SHOW_RING

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 lens_uv = fragCoord / iResolution.y;
    vec2 lens_pos = iMouse.xy == vec2(0) ? vec2(1.0, 0.5) : iMouse.xy / iResolution.y;
    
    vec2 lens_delta = lens_uv - lens_pos;
    float lens_dist = length(lens_delta);
    
    // Lens parameters
    const float lens_radius = 0.25;
    const float lens_zoom = 2.0;
    const float lens_radius_fudge = 0.975;
    
    // Spherical lens normal approximation
    vec3 lens_normal = normalize(vec3(
        lens_delta, 
        lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist * lens_dist)
    ));
    
    vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
    
    // IOR ratios for dispersion (air/glass)
    const float ior_base = 1.015;
    const float ior_step = 0.0065;
    float eta[6] = float[6](
        1.0 / ior_base,                    // red
        1.0 / (ior_base + ior_step),       // yellow  
        1.0 / (ior_base + 2.0 * ior_step), // green
        1.0 / (ior_base + 1.0 * ior_step), // cyan
        1.0 / (ior_base + 2.0 * ior_step), // blue
        1.0 / (ior_base + 1.0 * ior_step)  // violet
    );
    
    // Sample textures with different refractions
    vec3 tex = texture(iChannel0, uv).rgb;
    vec3 samples[6];
    for(int i = 0; i < 6; i++) {
        vec2 refract_offset = refract(incident, lens_normal, eta[i]).xy;
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
    vec3 dispersed_color = vec3(
        r + (2.0 * v + 2.0 * y - c) / 3.0,
        g + (2.0 * y + 2.0 * c - v) / 3.0,
        b + (2.0 * c + 2.0 * v - y) / 3.0
    );
    
    vec3 color = mix(tex, dispersed_color, step(lens_dist, lens_radius));
    
#ifdef SHOW_RING
    float distance = distance(lens_pos, lens_uv);
    float ring = smoothstep(distance, 1.0, lens_radius);
    color *= ring * 25.0;
#endif
    
    fragColor = vec4(color, 1.0);
}