
#iChannel0 "SpectralRaytracer/buffer-a.wgsl"
#include "SpectralRaytracer/common.wgsl"

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


bool Sphere_hit(Sphere sphere, Ray ray, float t_min, float t_max, out Hit rec)
{
    vec3 oc = ray.origin - sphere.center;
    float a = dot(ray.direction, ray.direction);
    float b = dot(oc, ray.direction);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;

    float discriminant = b * b - a * c;

    if (discriminant > 0.0f)
    {
        float temp = (-b - sqrt(discriminant)) / a;

        if (temp < t_max && temp > t_min){
            rec.t = temp;
            rec.p = ray.origin + rec.t * ray.direction;
            rec.normal = (rec.p - sphere.center) / sphere.radius;
            rec.mat = sphere.mat;
            return true;
        }

        temp = (-b + sqrt(discriminant)) / a;

        if (temp < t_max && temp > t_min){
            rec.t = temp;
            rec.p = ray.origin + rec.t * ray.direction;
            rec.normal = (rec.p - sphere.center) / sphere.radius;
            rec.mat = sphere.mat;
            return true;
        }
    }

    return false;
}

//
// Ray tracer helper functions
//

float FresnelSchlickRoughness(float cosTheta, float F0, float roughness) {
    return F0 + (max((1. - roughness), F0) - F0) * pow(abs(1. - cosTheta), 5.0);
}

vec3 cosWeightedRandomHemisphereDirection(const vec3 n, inout float seed) {
  	vec2 r = hash2(seed);
	vec3  uu = normalize(cross(n, abs(n.y) > .5 ? vec3(1.,0.,0.) : vec3(0.,1.,0.)));
	vec3  vv = cross(uu, n);
	float ra = sqrt(r.y);
	float rx = ra*cos(6.28318530718*r.x); 
	float ry = ra*sin(6.28318530718*r.x);
	float rz = sqrt(1.-r.y);
	vec3  rr = vec3(rx*uu + ry*vv + rz*n);
    return normalize(rr);
}

vec3 modifyDirectionWithRoughness(const vec3 normal, const vec3 n, const float roughness, inout float seed) {
    vec2 r = hash2(seed);
    
	vec3  uu = normalize(cross(n, abs(n.y) > .5 ? vec3(1.,0.,0.) : vec3(0.,1.,0.)));
	vec3  vv = cross(uu, n);
	
    float a = roughness*roughness;
    
	float rz = sqrt(abs((1.0-r.y) / clamp(1.+(a - 1.)*r.y,.00001,1.)));
	float ra = sqrt(abs(1.-rz*rz));
	float rx = ra*cos(6.28318530718*r.x); 
	float ry = ra*sin(6.28318530718*r.x);
	vec3  rr = vec3(rx*uu + ry*vv + rz*n);
    
    vec3 ret = normalize(rr);
    return dot(ret,normal) > 0. ? ret : n;
}

vec2 randomInUnitDisk(inout float seed) {
    vec2 h = hash2(seed) * vec2(1,6.28318530718);
    float phi = h.y;
    float r = sqrt(h.x);
	return r*vec2(sin(phi),cos(phi));
}

//
// Scene description
//

vec3 rotateY(const in vec3 p, const in float t) {
    float co = cos(t);
    float si = sin(t);
    vec2 xz = mat2(co,si,-si,co)*p.xz;
    return vec3(xz.x, p.y, xz.y);
}

bool opU(inout vec2 d, float iResult, in Material mat) {
    if (iResult < d.y) {
        d.y = iResult;
        return true;
    }
    return false;
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

bool worldhit(in Ray ray, in vec2 dist, out Hit rec) {
    Hit temp_rec;
    bool hit_anything = false;
    float closest_so_far = dist.y;

    for (int i = 0; i < sceneList.length(); i++) {
        if (Sphere_hit(sceneList[i], ray, dist.x, closest_so_far, temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }
    return hit_anything;
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

//
// Simple ray tracer
//

float schlick(float cosine, float r0) {
    return r0 + (1. - r0) * pow(abs(1. - cosine), 5.);
}

vec3 refract_mine(vec3 v, vec3 n, float ni_over_nt) {
    float cos_theta = min(dot(-v, n), 1.0);
    vec3 r_out_perp = ni_over_nt * (v + cos_theta * n);
    vec3 r_out_parallel = -sqrt(abs(1. - dot(r_out_perp, r_out_perp))) * n;
    return r_out_perp + r_out_parallel;
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