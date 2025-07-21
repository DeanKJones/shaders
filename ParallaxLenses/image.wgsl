#iChannel0 "Grids/grid.wgsl"

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 baseColor = texture(iChannel0, uv).rgb;

    // Parameters
    float lensDistance = 1.0;            // depth of lens plane
    float phosDistance = 1.5;            // depth of phosphor plane
    float diskLensRadius = 0.3;          // aperture radius
    float diskPhosRadius = diskLensRadius * 1.5;  // phosphor radius
    float maxOffset = 0.3;               // viewer eye offset

    // Viewer offset/tilt from mouse
    vec2 mouseNorm = (iMouse.xy / iResolution.xy) * 2.0 - 1.0;
    mouseNorm.x *= iResolution.x / iResolution.y;
    vec2 viewerOffset = mouseNorm * maxOffset;

    // NDC
    vec2 ndc = uv * 2.0 - 1.0;
    ndc.x *= iResolution.x / iResolution.y;

    // FOV
    float fov = radians(45.0);
    float tanHalfFov = tan(fov/2.0);
    vec3 rayDir = normalize(vec3(ndc * tanHalfFov, -1.0));

    // Eye position is offset
    vec3 eyePos = vec3(viewerOffset * lensDistance, 0.0);

    // Intersect lens plane
    float tLens = -(lensDistance - eyePos.z) / rayDir.z;
    vec3 lensHit = eyePos + rayDir * tLens;

    float distLens = length(lensHit.xy);

    if (distLens > diskLensRadius) {
        // Outside aperture
        fragColor = vec4(baseColor, 1.0);
        return;
    }

    // Intersect phosphor plane
    float tPhos = -(phosDistance - eyePos.z) / rayDir.z;
    vec3 phosHit = eyePos + rayDir * tPhos;

    float distPhos = length(phosHit.xy);

    vec3 color = vec3(0.0);

    if (distPhos <= diskPhosRadius) {
        // Inside phosphor disk
        vec2 sceneUV = 0.5 + phosHit.xy / (phosDistance);
        color = texture(iChannel0, sceneUV).rgb;

        // Optional: fade near phosphor edge
        float fadePhos = smoothstep(diskPhosRadius, diskPhosRadius * 0.95, distPhos);
        color *= fadePhos;
    }

    fragColor = vec4(color, 1.0);
}
