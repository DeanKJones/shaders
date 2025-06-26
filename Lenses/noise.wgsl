// Noise function from your reference
float random(in vec2 _st) {
    return fract(sin(dot(_st.xy,
                         vec2(12.9898,78.233)))*
                              43758.54531723);
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
    float resScale = 1440.0/iResolution.y;
    float noisePixels = 0.9 * resScale; // pixels
    
    // Vignette calculation (from reference)
    float vignette = pow(1.0 - dot(uv - 0.5, uv - 0.5), 2.2) * 1.2;
    vignette = pow(vignette, 3.0);
    
    // Basic noise (from reference)
    float noiseTime = mod(iTime * 0.50, 100.0);
    float noise = random(uv / resScale + noiseTime) * 0.35;
    
    // High noise with different UV calculation (from reference)
    vec2 noiseUv = floor(fragCoord * noisePixels) / iResolution.xy / noisePixels;
    float highNoise = pow(random(noiseUv + noiseTime), 1000.0) * 1.0;
    
    // Add vignette influence to high noise (from reference)
    highNoise += highNoise * vignette * 10.0;
    
    // Combine both noise types as in reference
    return color + noise * 0.2 + highNoise;
}

// Adaptive noise based on image brightness - extracted from original night vision code
vec3 addAdaptiveNoise(vec3 color, vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float resScale = 1440.0/iResolution.y;
    float noisePixels = 0.2 * resScale;
    
    // Luminance weights from original code
    const vec3 lum = vec3(0.2125, 0.7154, 0.0721);
    float mipLevel = 10.0;
    // Calculate adaptive brightness multiplier (from original)
    vec3 averageBrightness = textureLod(iChannel0, vec2(0.5,0.5), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.3,0.5), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.7,0.5), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.5,0.3), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.5,0.7), mipLevel).rgb;
    
    averageBrightness += textureLod(iChannel0, vec2(0.3,0.3), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.7,0.7), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.7,0.3), mipLevel).rgb;
    averageBrightness += textureLod(iChannel0, vec2(0.3,0.7), mipLevel).rgb;
    
    float brightness = dot(averageBrightness.rgb, lum) * 0.5;
    
    // Adaptive multiplier - more noise in darker areas
    float adaptiveMul = mix(pow(brightness, -1.5), 1.2, brightness);
    
    // Vignette calculation
    float vignette = pow(1.0 - dot(uv - 0.5, uv - 0.5), 2.2) * 1.2;
    vignette = pow(vignette, 3.0);
    
    // Basic noise - static, no time component
    float noise = random(uv / resScale);
    
    // High noise with vignette influence - static
    vec2 noiseUv = floor(fragCoord * noisePixels) / iResolution.xy / noisePixels;
    float highNoise = pow(random(noiseUv), 1000.0) * 1.0;
    highNoise += highNoise * vignette * 10.0;
    
    // Apply adaptive brightness multiplier to the color
    vec3 adaptedColor = color * adaptiveMul;
    
    // Add noise with brightness-dependent intensity
    return adaptedColor + noise * 0.2 + highNoise * (2.0 - brightness);
}