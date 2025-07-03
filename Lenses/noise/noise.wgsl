// Noise function from your reference
float random(in vec2 _st) {
    return fract(sin(dot(_st.xy,
                         vec2(12.9898,78.233)))*
                              43758.5453172222);
}

vec3 blurTex(vec2 uv, float off, float it) {
    float subpx = 8.0 * it;
    vec3 fullRes = texture(iChannel0, uv).rgb / max(1.0, subpx + 1.0);
    
    for (float i = 0.0; i < it; i += 1.0) {
        float o = off * i;
        fullRes += texture(iChannel0, uv + vec2(0, o)).rgb / subpx;    // up
        fullRes += texture(iChannel0, uv + vec2(o, o)).rgb / subpx;    // up-right
        fullRes += texture(iChannel0, uv + vec2(o, 0)).rgb / subpx;    // right
        fullRes += texture(iChannel0, uv + vec2(o, -o)).rgb / subpx;   // down-right
        fullRes += texture(iChannel0, uv + vec2(0, -o)).rgb / subpx;   // down
        fullRes += texture(iChannel0, uv + vec2(-o, -o)).rgb / subpx;  // down-left
        fullRes += texture(iChannel0, uv + vec2(-o, 0)).rgb / subpx;   // left
        fullRes += texture(iChannel0, uv + vec2(-o, o)).rgb / subpx;   // up-left
    }
    return fullRes;
}

// Add noise to the texture before lens processing - closer to reference
vec3 addNoise(vec3 color, vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float resScale = 1440.0 / iResolution.y;
    float noisePixels = 0.9 * resScale;
    
    // Vignette calculation
    float vignette = pow(1.0 - dot(uv - 0.5, uv - 0.5), 2.2) * 1.2;
    vignette = pow(vignette, 3.0);
    
    float noiseTime = mod(iTime * 0.50, 100.0);    // High noise with pixelated UV
    // Basic noise using UV coordinates only
    float noise = random(uv / resScale + noiseTime) * 0.35;
    
    vec2 noiseUv = floor(fragCoord * noisePixels) / iResolution.xy / noisePixels;
    float highNoise = pow(random(noiseUv + noiseTime), 3000.0) * 1.0;
    
    // Add vignette influence to high noise
    highNoise += highNoise * vignette * 10.0;
    
    // Combine both noise types
    return color + noise * 0.2 + highNoise;
}
