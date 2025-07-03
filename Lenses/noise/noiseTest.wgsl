
float hash21(uvec2 p)
{
    // Add more scrambling for better distribution
    p = p * uvec2(1597334677u, 3812015801u);
    p.x ^= p.y >> 16u;
    p.y ^= p.x >> 16u;
    p ^= p >> 16u;
    p.x *= 0x85ebca6bu;
    p.y *= 0xc2b2ae35u;
    p.x ^= p.y >> 13u;
    p.y ^= p.x >> 13u;
    p.x *= 0x85ebca6bu;
    p.y *= 0xc2b2ae35u;
    uint h = p.x ^ p.y;
    return float(h) * (1.0 / 4294967296.0);  // Better normalization
}

float hash22(uvec2 p, uint seed)
{
    p += seed;
    return fract(sin(dot(vec2(p), vec2(12.9898, 78.233))) * 43758.5453);
}

//--------------------------------------------------------------
// main fragment
//--------------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    uvec2 pix = uvec2(fragCoord);

    pix.x ^= uint(iTime * 1.618);
    pix.y ^= uint(iTime * 2.718);
    
    float r1 = hash21(pix);
    float r2 = hash22(pix, uint(iFrame));
    float r = fract(r1 + r2 * 0.5);

    const float DENSITY1 = 0.00025;
    const float DENSITY2 = 0.0005;
    const float DENSITY3 = 0.001;

    float speck = 0.0;
    if (r < DENSITY1) {
        speck = 1.0;
    } else if (r < DENSITY2) {
        speck = 0.6;
    } else if (r < DENSITY3) {
        speck = 0.3;
    }

    vec3 color = vec3(speck);
    if (speck > 0.8) {
        color = mix(color, vec3(0.0, 0.9, 0.8), 0.3);
    }

    fragColor = vec4(color, 1.0);
}