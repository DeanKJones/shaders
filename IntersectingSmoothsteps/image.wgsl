// Define which intersection method to use
#define INTERSECTION 0  // 0 = Union, 1 = Intersection, 2 = Smooth Union

float circle_mask(vec2 p, vec2 center, float inner_radius, float outer_radius) {
    float dist = length(p - center);
    return 1.0 - smoothstep(inner_radius, outer_radius, dist);
}

// Union (max)
float union_op(float a, float b) {
    return max(a, b);
}

// Intersection (min) 
float intersection_op(float a, float b) {
    return min(a, b);
}

// Smooth union using exponential blending
float smooth_union(float a, float b, float k) {
    float res = exp2(-k * a) + exp2(-k * b);
    return -log2(res) / k;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    
    // Three circle positions
    vec2 center_pos = vec2(0.0, 0.0);  // Center circle
    vec2 left_pos = vec2(-0.3, 0.0);   // Left circle
    vec2 right_pos = vec2(0.3, 0.0);   // Right circle
    
    // Control parameters for edge blur thickness
    float inner_radius = 0.07;   // Start of blur (solid white)
    float outer_radius = 0.25;   // End of blur (full black)
    
    // Three circle masks
    float center_circle = circle_mask(uv, center_pos, inner_radius, outer_radius);
    float left_circle = circle_mask(uv, left_pos, inner_radius, outer_radius);
    float right_circle = circle_mask(uv, right_pos, inner_radius, outer_radius);
    
    // Combine the three circle masks
    float final_mask;
    
    #if INTERSECTION == 0
        // Union - show all three circles
        final_mask = max(center_circle, max(left_circle, right_circle));
    #elif INTERSECTION == 1
        // Intersection - only where all three overlap
        final_mask = min(center_circle, min(left_circle, right_circle));
    #else
        // Smooth union - organic blending of all three
        float temp = smooth_union(center_circle, left_circle, 8.0);
        final_mask = smooth_union(temp, right_circle, 8.0);
    #endif
    
    // Output as alpha mask: white circles, black background
    vec3 color = vec3(final_mask);
    
    // Method indicator in corner
    float aspect = iResolution.x / iResolution.y;
    bool corner_indicator = length(uv - vec2(-aspect + 0.2, 0.8)) < 0.05;
    if (corner_indicator) {
        #if INTERSECTION == 0
            color = vec3(1.0, 1.0, 0.0); // Yellow for Union
        #elif INTERSECTION == 1
            color = vec3(0.0, 1.0, 1.0); // Cyan for Intersection
        #else
            color = vec3(1.0, 0.0, 1.0); // Magenta for Smooth Union
        #endif
    }
    
    fragColor = vec4(color, 1.0);
}