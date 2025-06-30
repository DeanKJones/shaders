vec3 GenerateLensUV(vec2 lens_uv, 
                    vec2 lens_uv1, 
                    vec2 lens_uv2, 
                    vec2 lens_pos1, 
                    vec2 lens_pos2, 
                    float center_x,
                    float lens_radius) {

    float lens_dist1 = distance(lens_uv, lens_pos1);
    if (lens_dist1 < lens_radius) {
        vec2 lens1_uv_normalized = normalize(lens_uv - lens_pos1);
        lens_uv1 += lens1_uv_normalized * 0.05 * (smoothstep(lens_radius * 0.5, lens_radius, lens_dist1));            
    }
    // Right lens
    float lens_dist2 = distance(lens_uv, lens_pos2);
    if (lens_dist2 < lens_radius) {
        vec2 lens2_uv_normalized = normalize(lens_uv - lens_pos2);
        lens_uv2 += lens2_uv_normalized * 0.05 * (smoothstep(lens_radius * 0.5, lens_radius, lens_dist2));            
    }

    if (lens_uv.x < center_x) {
        // Left lens
        lens_uv = lens_uv1;
    } else {
        // Right lens
        lens_uv = lens_uv2;
    }

    // Store UV coordinates in texture (no blur here)
    return vec3(lens_uv, 0.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 lens_uv = fragCoord / iResolution.y;

    vec2 lens_uv1 = lens_uv; // Left lens UV
    vec2 lens_uv2 = lens_uv; // Right lens UV

    const float lens_radius = 0.3;
    vec2 lens_pos1 = vec2(0.3, 0.7);
    vec2 lens_pos2 = vec2(0.75, 0.7); 
    float center_x = (lens_pos1.x + lens_pos2.x) * 0.5;
    
    vec3 lens_uv_data = GenerateLensUV(lens_uv, lens_uv1, lens_uv2, lens_pos1, lens_pos2, center_x, lens_radius);
    
    // Output UV coordinates as texture data
    fragColor = vec4(lens_uv_data.xy, 0.0, 1.0);
}