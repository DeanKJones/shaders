#iChannel0 "Lenses/buffer-uv.wgsl"

// Gaussian blur for UV coordinates
vec2 gaussianBlurUV(vec2 fragCoord, float blur_radius) {
    vec2 result = vec2(0.0);
    float total_weight = 0.0;
    
    int samples = 4; // Increased to 9x9 kernel for stronger blur
    float sigma = blur_radius * 0.1; // Reduced sigma for tighter distribution
    
    for (int x = -samples/2; x <= samples/2; x++) {
        for (int y = -samples/2; y <= samples/2; y++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 sample_coord = fragCoord + offset * blur_radius * 0.5; // Scale offset properly
            
            // Gaussian weight with proper normalization
            float distance_sq = float(x*x + y*y);
            float weight = exp(-distance_sq / (2.0 * sigma * sigma));
            
            // Clamp sample coordinates to avoid edge artifacts
            vec2 uv = clamp(sample_coord / iResolution.xy, 0.0, 1.0);
            vec2 sample_uv = texture(iChannel0, uv).xy;
            
            result += sample_uv * weight;
            total_weight += weight;
        }
    }
    
    return result / total_weight;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 blurred_uv = gaussianBlurUV(fragCoord, 10.0); // Adjust blur radius as needed
    fragColor = vec4(blurred_uv, 0.0, 1.0);
}