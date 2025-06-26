
#include "Lenses/noise.wgsl"
#define GRID 0
#if GRID
    #iChannel0 "Lenses/grid.wgsl"
#else
    #iChannel0 "Lenses/gridMoving.wgsl"
#endif

// Gaussian blur for smoother intersection
vec3 gaussianBlurIntersection(vec2 uv, float blur_radius) {
    vec3 result = vec3(0.0);
    float total_weight = 0.0;
    
    int samples = 9; // 9x9 kernel
    float sigma = blur_radius * 0.5;
    
    for (int x = -samples/2; x <= samples/2; x++) {
        for (int y = -samples/2; y <= samples/2; y++) {
            vec2 offset = vec2(float(x), float(y)) * blur_radius / iResolution.xy;
            vec2 sample_uv = uv + offset;
            
            // Gaussian weight
            float distance_sq = float(x*x + y*y);
            float weight = exp(-distance_sq / (2.0 * sigma * sigma));
            
            vec3 sample_color = texture(iChannel0, sample_uv).rgb;
            sample_color = addNoise(sample_color, sample_uv * iResolution.xy);
            
            result += sample_color * weight;
            total_weight += weight;
        }
    }
    
    return result / total_weight;
}