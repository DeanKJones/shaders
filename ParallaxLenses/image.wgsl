#iChannel0 "Grids/grid.wgsl"

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 lens_uv = fragCoord / iResolution.y;

    vec3 baseColor = texture(iChannel0, uv).rgb;

    // Lens parameters
    const float lens_radius = 0.3;

    // Minimum squash factor when fully squashed
    const float squash_min = 0.0;

    // Animate squash over time
    float cycleTime = 4.0;          // seconds for one full squash/unsquash
    float phase = mod(iTime, cycleTime) / cycleTime;                 // 0–1
    float toggle = mod(floor(iTime / cycleTime), 2.0);
    float t = smoothstep(0.0, 1.0, phase);
    if (toggle > 0.5) {
        t = 1.0 - t;
    }

    float lens_y = mix(0.5, 1.1, t);
    float lens_scale = mix(0.8, 1.5, t);
    float squashY = mix(1.0, squash_min, t);

    vec2 lens_pos = vec2(0.5, lens_y);

    // Compute relative coords from lens center
    vec2 rel = lens_uv - lens_pos;
    vec2 rel_squashed = vec2(rel.x, rel.y / squashY);

    float distance = length(rel_squashed);

    vec3 color = baseColor;


    if (distance < lens_radius) {
    vec2 center_uv = vec2(0.5, 0.5);

    vec2 rel_to_lens = lens_uv - lens_pos;
    vec2 scaled_offset = rel_to_lens / lens_scale;
    vec2 lens_sample_uv = center_uv + scaled_offset;

    // Normalized direction from center of lens to current pixel
    vec2 lens_uv_normalized = normalize(rel_to_lens);

    // Compute how far you are from center relative to radius
    float edge_factor = smoothstep(lens_radius * 0.25, lens_radius, distance);

    // Distortion strength grows with t
    float distortionStrength = t * 0.05;

    // Apply outward distortion near edges
    lens_sample_uv += lens_uv_normalized * edge_factor * distortionStrength;

    color = texture(iChannel0, lens_sample_uv).rgb;
}


    fragColor = vec4(color, 1.0);
}

