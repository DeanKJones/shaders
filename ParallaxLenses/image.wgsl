#iChannel0 "Grids/grid.wgsl"

#define M_PI 3.141592653589793

// — rotation helpers —
mat3 rotX(float a){ float s=sin(a), c=cos(a); return mat3(1,0,0, 0,c,-s, 0,s,c); }
mat3 rotY(float a){ float s=sin(a), c=cos(a); return mat3(c,0,s, 0,1,0,-s,0,c); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 0. Basic setup
    vec2 uv       = fragCoord / iResolution.xy;
    vec3 baseCol  = texture(iChannel0, uv).rgb;
    
    // --- Named constants ---
    const float lensPlaneDist    = 1.0;           // Distance to lens plane
    const float phosPlaneDist    = 1.75;          // Distance to phosphor plane
    const float lensDisk         = 0.50;          // Radius of the lens disk
    const float phosDisk         = lensDisk * 1.5; // Radius of the phosphor disk
    const float maxTiltDeg       = 45.0;          // ± tilt angle
    const float fovDeg           = 45.0;          // Field of view

    // — distortion on the lens surface —
    const float k1 = 0.3;    // 1st‑order radial term
    const float k2 = 0.1;    // 2nd‑order radial term

    // 1. Mouse → tilt angles
    vec2 normMouse = clamp(iMouse.xy / iResolution.xy, 0.0, 1.0);
    float pitch    = (normMouse.y - 0.5) * radians(maxTiltDeg) * 2.0; // up/down
    float yaw      = (normMouse.x - 0.5) * radians(maxTiltDeg) * 2.0; // left/right
    mat3 viewRot   = rotY(yaw) * rotX(pitch);

    // 2. Primary camera ray
    vec2   ndc        = uv * 2.0 - 1.0;
    ndc.x            *= iResolution.x / iResolution.y;
    float tanHalfFOV = tan(radians(fovDeg) * 0.5);
    vec3  rayDir     = normalize(vec3(ndc * tanHalfFOV, -1.0));
    vec3  eyePos     = vec3(0.0);

    // 3. Lens‐disk intersection
    vec3 lensCenter  = vec3(0.0, 0.0, -lensPlaneDist);
    vec3 lensNormal  = viewRot * vec3(0.0, 0.0, 1.0);

    float lensDenom  = dot(rayDir, lensNormal);
    if (abs(lensDenom) < 1e-4) {
        fragColor = vec4(baseCol, 1.0);
        return;
    }

    float tLens      = dot(lensCenter - eyePos, lensNormal) / lensDenom;
    if (tLens < 0.0) {
        fragColor = vec4(baseCol, 1.0);
        return;
    }

    vec3  lensHit    = eyePos + tLens * rayDir;
    vec3  lensOffset = lensHit - lensCenter;
    float lensRad2   = length(lensOffset - dot(lensOffset, lensNormal) * lensNormal);

    // 3a. Outer‐edge blur (beyond the lensDisk)
    if (lensRad2 > lensDisk * lensDisk) {
        float fade = 1.0 - smoothstep(
            lensDisk * lensDisk,
            lensDisk * lensDisk * 1.15,
            lensRad2
        );
        fragColor = vec4(mix(baseCol, vec3(0.0), fade), 1.0);
        return;
    }

    // 3b. Inside the lensDisk → bend the ray according to radial distortion
    {
        // build local X/Y axes on the lens plane
        vec3 axisX   = normalize(viewRot * vec3(1.0, 0.0, 0.0));
        vec3 axisY   = normalize(viewRot * vec3(0.0, 1.0, 0.0));

        // project into disk‐local coords
        vec2 localXY = vec2(
            dot(lensOffset, axisX),
            dot(lensOffset, axisY)
        );
        vec2 diskUV  = localXY / lensDisk;       // now in [-1..1]×[-1..1]
        float r2     = dot(diskUV, diskUV);

        // compute radial distortion factor
        float radial = 1.0 + k1 * r2 + k2 * r2 * r2;
        vec2 warpedUV= diskUV * radial;
        vec2 warpedXY= warpedUV * lensDisk;

        // reconstruct the warped point on the lens surface
        vec3 warpedPoint = lensCenter
                         + axisX * warpedXY.x
                         + axisY * warpedXY.y;

        // re‐aim the ray from the eye through that warped point
        rayDir = normalize(warpedPoint - eyePos);
    }

    // 4. Phosphor‐disk intersection (with the bent ray)
    float gap        = phosPlaneDist - lensPlaneDist;
    vec3  phosCenter = lensCenter - lensNormal * gap;
    vec3  phosNormal = lensNormal;

    float phosDenom  = dot(rayDir, phosNormal);
    float tPhos      = dot(phosCenter - eyePos, phosNormal) / phosDenom;
    if (tPhos < 0.0) {
        fragColor = vec4(baseCol, 1.0);
        return;
    }

    vec3  phosHit    = eyePos + tPhos * rayDir;
    vec3  phosOffset = phosHit - phosCenter;
    float phosRad2   = length(phosOffset - dot(phosOffset, phosNormal) * phosNormal);

    // 5. Sample only if inside phosphor disk, nudged by 25% of the tilt
    vec3 outColor = vec3(0.0);
    if (phosRad2 <= phosDisk * phosDisk) {
        // compute a small UV shift based on tilt (max ±0.05)
        vec2 tiltShift = (normMouse - 0.5) * 2.0 * 0.05;

        // sample and tint the grid, nudged by tiltShift
        vec2 sampleUV = clamp(uv * 0.95 + tiltShift, 0.0, 1.0);
        vec3 sampleCol = texture(iChannel0, sampleUV).rgb;

        float edgeFade = smoothstep(phosDisk, phosDisk * 0.99, sqrt(phosRad2));
        outColor = sampleCol * edgeFade * vec3(0.0, 0.8, 0.2);
    }

    fragColor = vec4(outColor, 1.0);
}
