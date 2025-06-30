#define GRID 0
#if GRID
    #iChannel0 "Grids/grid.wgsl"
#else
    #iChannel0 "Grids/gridMoving.wgsl"
#endif
#iChannel1 "Lenses/buffer-blur.wgsl"  // Blurred UV coordinates

#define SHOW_RING

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 lens_uv = fragCoord / iResolution.y;

    // Get blurred UV coordinates from buffer
    vec2 distorted_uv = texture(iChannel1, uv).xy;
    
    // Sample the grid texture using the distorted UV coordinates
    vec3 color = texture(iChannel0, distorted_uv).rgb;
    
    // Apply vignette if needed
    float vignette = pow(1.0 - dot(uv - 0.5, uv - 0.5), 2.2) * 1.2;
    
#ifdef SHOW_RING
    const float lens_radius = 0.3;
    vec2 lens_pos1 = vec2(0.3, 0.7);
    vec2 lens_pos2 = vec2(0.75, 0.7); 
    
    float distance1 = distance(lens_pos1, lens_uv);
    float distance2 = distance(lens_pos2, lens_uv);
    float ring1 = 1.0 - smoothstep(lens_radius - 0.2, lens_radius + 0.02, distance1);
    float ring2 = 1.0 - smoothstep(lens_radius - 0.2, lens_radius + 0.02, distance2);
    float combined_ring = max(ring1, ring2);

    color *= combined_ring;
#endif
    
    fragColor = vec4(color, 1.0);
}