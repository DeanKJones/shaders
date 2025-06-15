
#iChannel0 "SpectralRaytracer/buffer-a.wgsl"

#include "SpectralRaytracer/tracing/intersection.wgsl"
#include "SpectralRaytracer/tracing/materials/interactions.wgsl"

float gaussian(float x, float mu, float sigma)
{
    return 1.0 / (sigma * sqrt(2.0 * PI)) * exp(-(x-mu)*(x-mu)/(2.*sigma*sigma));
}


// The CIE color matching functions were taken from  https://www.fourmilab.ch/documents/specrend
// The tabulated functions then were approximated with gaussians (for G and B) and with a mixture of two gaussiuns (R).
vec3 wavelength2XYZ(float l)
{
	return vec3(
    	8233.31 * gaussian(l, 593.951, 34.00) + 1891.26 * gaussian(l, 448.89, 18.785),
        10522.64 * gaussian(l, 555.38, 40.80),
        11254.78 * gaussian(l, 452.98, 21.57)
    );
}

float XYZ2WavelengthApprox(float l, vec3 color) {
    return dot(wavelength2XYZ(l), color) / 100.0;
}


//
// Palette by Íñigo Quílez: 
// https://www.shadertoy.com/view/ll2GD3
//
vec3 pal(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) {
    return a + b * cos(6.28318530718 * (c * t + d));
}

float checkerBoard(vec2 p) {
   return mod(floor(p.x) + floor(p.y), 2.);
}

vec3 getSkyColor(vec3 rd) {
    vec3 col = mix(vec3(1), vec3(.5, .7, 1), .5 + .5 * rd.y);
    col = vec3(0.);
    float sun = clamp(dot(normalize(vec3(-0.3, .7, -.6)), rd), 0., 1.);
    col += vec3(1, .6, .1) * (pow(sun, 4.) + 10. * pow(sun, 32.));
    return col;
}

float gpuIndepentHash(float p) {
    p = fract(p * .1031);
    p *= p + 19.19;
    p *= p + p;
    return fract(p);
}

float reflectivity(float n1_over_n2, float cosTheta, float wavelenght) {
    float r0 = (n1_over_n2 - 1.) / (n1_over_n2 + 1.);
    r0 = r0*r0;
    return r0 + (1. - r0) * pow((1. - cosTheta), 5.);
}


float skyColor(Ray ray) {
	vec3 sky = getSkyColor(ray.direction);
    sky = RGB_2_XYZ * pow(sky, vec3(2.2));
    return XYZ2WavelengthApprox(ray.wavelength, sky) * 0.5;
}

float n_wavelength(float lambda_nm) {
    float lambda_um = lambda_nm / 1000.0;
    
    // Coefficients for Cauchy's equation, adjusted to fit the range 1 < n < 2 for visible spectrum
    float A = 0.438;
    float B = 0.316;
    

    // Calculate refractive index
    float n_lambda = A + B / (lambda_um * lambda_um);
    
    return n_lambda;
}


float trace(in Ray ray, inout float seed) {
    vec3 albedo = vec3(1.); 
    float roughness, type;
    Material mat;
    Hit rec;
    float intensity = 1.;
    
    for (int i = 0; i < PATH_LENGTH; ++i) {    
    	bool didHit = worldhit(ray, vec2(.001, 100), rec);
        float res = rec.t;
        Material mat = rec.mat;
		if (didHit) {
			ray.origin += ray.direction * res;
            //ray.origin -= ray.direction * .0001;  // This should work, but it doesn't
            
            if (mat.materialType == LAMBERTIAN) 
            { // Added/hacked a reflection term
                float F = FresnelSchlickRoughness(max(0.,-dot(rec.normal, ray.direction)), .04, mat.fuzz);
                if (F > hash1(seed)) {
                    ray.direction = modifyDirectionWithRoughness(rec.normal, reflect(ray.direction, rec.normal), mat.fuzz, seed);
                } else {
			        ray.direction = cosWeightedRandomHemisphereDirection(rec.normal, seed);
                }
                intensity *= mat.albedo.x * max(0.0, dot(rec.normal, ray.direction) / PI) * PI;  // TODO: Make this more legible. attenuation * scatterPDF / pdf
            } 
            else if (mat.materialType == METAL) 
            {
                ray.direction = modifyDirectionWithRoughness(rec.normal, reflect(ray.direction, rec.normal), mat.fuzz, seed);            
                intensity *= mat.albedo.x;  // TODO: Make this more legible.
            } 
            else 
            { 
            // DIELECTRIC
                intensity *= 1.;
                vec3 normal, refracted;
                float ni_over_nt, cosine, reflectProb = 1.;
                float refractionIndex = mat.refractionIndex;
                refractionIndex = n_wavelength(ray.wavelength);
                
                // Determine if ray is inside or outside
                bool ray_inside = dot(ray.direction, rec.normal) > 0.;
                
                if (ray_inside) {
                    // Ray is inside
                    normal = -rec.normal;
                    ni_over_nt = refractionIndex;
                    cosine = dot(ray.direction, rec.normal) / length(ray.direction);
                } else {
                    // Ray is outside  
                    normal = rec.normal;
                    ni_over_nt = 1. / refractionIndex;
                    cosine = -dot(ray.direction, rec.normal) / length(ray.direction);
                }

                // Refract the ray
                refracted = refract(normalize(ray.direction), normal, ni_over_nt);
                
                // Handle total internal reflection
                if(refracted != vec3(0)) {
                    float r0 = (1. - ni_over_nt) / (1. + ni_over_nt);
                    reflectProb = FresnelSchlickRoughness(abs(cosine), r0 * r0, mat.fuzz);
                }
                
                // Use a larger, wavelength-independent offset for better precision
                float ray_offset = 0.002;
                
                if (hash1(seed) <= reflectProb) {
                    ray.direction = reflect(ray.direction, normal);
                    ray.origin += normal * ray_offset;  // Use surface normal for offset
                } else {
                    ray.direction = refracted;
                    ray.origin -= normal * ray_offset;  // Push in opposite direction of surface normal
                }           
                        }
                    } else {
                        intensity *= skyColor(ray);
                        return intensity;
                    }
                }  
    return 0.;
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr ) {
	vec3 cw = normalize(ta - ro);
	vec3 cp = vec3(sin(cr), cos(cr), 0.0);
	vec3 cu = normalize(cross(cw, cp));
	vec3 cv = (cross(cu, cw));
    return mat3(cu, cv, cw);
}

vec3 render(in Ray ray, inout float seed) {
    vec3 col = vec3(0.);
    // Loop over the wavelengths
    for (int i = 0; i < NUM_WAVELENGTHS; i++) {
        ray.wavelength = float(LOWER_BOUND + i * (UPPER_BOUND - LOWER_BOUND) / NUM_WAVELENGTHS);
        //ray.wavelength = float(600);
        float intensity = trace(ray, seed);
        vec3 color = wavelength2XYZ(ray.wavelength);

        col += color * intensity;
    }
    col = XYZ_2_RGB * col;
    col /= float(NUM_WAVELENGTHS);
    col /= 40.0;
	col = clamp(col, vec3(0.0), vec3(1.0));
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    bool reset = iFrame == 0;
        
    vec4 data = texelFetch(iChannel0, ivec2(0), 0);

    // Default camera values
    vec3 ro = vec3(3., 0., 0.);
    vec3 ta = vec3(1., 0., 0.);

    mat3 ca = setCamera(ro, ta, 0.);
    Material mat;

    float fpd = data.x;
    if(all(equal(ivec2(fragCoord), ivec2(0)))) {
        // Calculate focus plane.
        Hit rec;
        Ray focus_ray = Ray(ro, normalize(vec3(.5,0,-.5)-ro), 0.);
        bool didHit = worldhit(focus_ray, vec2(0, 100), rec);
        fragColor = vec4(rec.t, iResolution.xy, iResolution.x);
    } else { 
        vec2 p = (-iResolution.xy + 2. * fragCoord - 1.) / iResolution.y;
        float seed = float(baseHash(floatBitsToUint(p - iTime))) / float(0xffffffffU);

        // AA
        p += 2. * hash2(seed) / iResolution.y;
        vec3 rd = ca * normalize(vec3(p.xy, 1.6));  

        // DOF
        vec3 fp = ro + rd * fpd;
        ro = ro + ca * vec3(randomInUnitDisk(seed), 0.) * .005;
        rd = normalize(fp - ro);

        Ray ray = Ray(ro, rd, 0.);

        vec3 col = render(ray, seed);

        if (reset) {
            fragColor = vec4(col, 1);
        } else {
            fragColor = vec4(col, 1) + texelFetch(iChannel0, ivec2(fragCoord), 0);
        }
    }
    
}