// Code by Simon LUCAS - 26/01/2022

#define R iResolution.xy
#define MP (iMouse.xy/iResolution.xy)
#define Pi 3.141593
#define EPS 0.001

#define N1 1.

#define MAX_DEPTH 16
#define NUM_WL_SAMPLES 10


// RANDOM

vec2 seed;

uint pcg(uint v) {
  uint state = v * uint(747796405) + uint(2891336453);
  uint word = ((state >> ((state >> uint(28)) + uint(4))) ^ state) * uint(277803737);
  return (word >> uint(22)) ^ word;
}

float hash () {
    seed += 1.;
	return float(pcg(pcg(uint(seed.x)) + uint(seed.y))) / float(uint(0xffffffff));
}

// STRUCTS

struct Inter
{
    float t;
    vec2 nor;
    vec2 pos;
    bool emi;
};

struct Sphere
{
    vec2 pos;
    float rad;
    bool emi;
};

// WAVELENGTHS
#define WL_START   400.0
#define WL_END     800.0
#define WL_RANGE   (WL_END - WL_START)
#define USE_ENHANCED_D65 1


float d65_standard(float wavelength) {
    float wl = wavelength * 1e-9; // Convert nm to meters
    float temp = 6504.0; // D65 color temperature in Kelvin
    float c1 = 3.74183e-16;
    float c2 = 1.4388e-2;
    
    return (c1 / (pow(wl, 5.0) * (exp(c2 / (wl * temp)) - 1.0))) * 1e-12;
}

// Analytical CIE XYZ color matching functions
vec3 xyz_bar(float wavelength) {
    float wl = wavelength;
    
    // Gaussian approximations for CIE XYZ color matching functions
    float x = 1.056 * exp(-0.5 * pow((wl - 599.8) / 37.9, 2.0)) +
              0.362 * exp(-0.5 * pow((wl - 442.0) / 16.0, 2.0)) +
              -0.065 * exp(-0.5 * pow((wl - 501.1) / 20.7, 2.0));
              
    float y = 0.821 * exp(-0.5 * pow((wl - 568.8) / 46.9, 2.0)) +
              0.286 * exp(-0.5 * pow((wl - 530.9) / 16.3, 2.0));
              
    float z = 1.217 * exp(-0.5 * pow((wl - 437.0) / 11.8, 2.0)) +
              0.681 * exp(-0.5 * pow((wl - 459.0) / 26.0, 2.0));
    
    return vec3(max(x, 0.0), max(y, 0.0), max(z, 0.0));
}

float enhanced_cauchy_ior(in float lambda_nm) {
    float lambda_um = lambda_nm * 1e-3;
    float lambda2 = lambda_um * lambda_um;
    return 1.6 + 0.01342 / lambda2 + 0.0001 / (lambda2 * lambda2);
}

// More accurate D65 with atmospheric absorption effects
float d65_enhanced(float wavelength) {
    float base = d65_standard(wavelength);
    // Add atmospheric absorption bands
    float ozone_abs = exp(-0.0001 * pow((wavelength - 600.0) / 50.0, 2.0));
    return base * ozone_abs;
}

float d65(float wavelength) {
    if (USE_ENHANCED_D65 == 1){
        return d65_enhanced(wavelength);
    } else {
        return d65_standard(wavelength);
    }
}

// LIGHT SOURCE CONFIGURATION
struct LightSource {
    float wavelength;    // Peak wavelength in nm
    float intensity;     // Relative intensity
    float bandwidth;     // Bandwidth for spectral width
};

// Define available light colors
const int NUM_LIGHT_SOURCES = 5;
const LightSource light_sources[NUM_LIGHT_SOURCES] = LightSource[NUM_LIGHT_SOURCES](
    LightSource(485.0, 1.0, 20.0),  // Cyan
    LightSource(530.0, 1.2, 25.0),  // Green  
    LightSource(590.0, 0.9, 30.0),  // Orange
    LightSource(650.0, 0.8, 35.0),  // Red
    LightSource(750.0, 0.6, 40.0)   // Near-infrared
);

// Option 1: Warm lighting (reds and oranges)
const LightSource warm_lights[3] = LightSource[3](
    LightSource(590.0, 1.0, 25.0),  // Orange
    LightSource(650.0, 1.2, 30.0),  // Red
    LightSource(700.0, 0.8, 35.0)   // Deep red
);

// Option 2: Cool lighting (blues and cyans)
const LightSource cool_lights[3] = LightSource[3](
    LightSource(450.0, 1.0, 20.0),  // Blue
    LightSource(485.0, 1.2, 25.0),  // Cyan
    LightSource(520.0, 0.9, 30.0)   // Blue-green
);

// Option 3: RGB primaries
const LightSource rgb_lights[3] = LightSource[3](
    LightSource(650.0, 1.0, 20.0),  // Red
    LightSource(530.0, 1.0, 20.0),  // Green
    LightSource(470.0, 1.0, 20.0)   // Blue
);

// Light configuration settings
#define LIGHTING_MODE_FULL_SPECTRUM 0
#define LIGHTING_MODE_WARM 1
#define LIGHTING_MODE_COOL 2
#define LIGHTING_MODE_RGB_Green 3

#define CURRENT_LIGHTING_MODE LIGHTING_MODE_FULL_SPECTRUM


// Spectral emission function for a single light source
float spectral_emission(float wavelength, LightSource source) {
    float delta = wavelength - source.wavelength;
    return source.intensity * exp(-0.5 * pow(delta / source.bandwidth, 2.0));
}

// Combined lighting function
float lighting(float wavelength) {
#if CURRENT_LIGHTING_MODE == LIGHTING_MODE_FULL_SPECTRUM
    float total_emission = 0.0;
    
    // Sum contributions from all light sources
    for(int i = 0; i < NUM_LIGHT_SOURCES; i++) {
        total_emission += spectral_emission(wavelength, light_sources[i]);
    }

    // Add D65 as background illumination (scaled down)
    total_emission += 0.1 * d65(wavelength);
    
    return total_emission;

#elif CURRENT_LIGHTING_MODE == LIGHTING_MODE_WARM
    float total_emission = 0.0;
    
    // Sum contributions from warm light sources
    for(int i = 0; i < 3; i++) {
        total_emission += spectral_emission(wavelength, warm_lights[i]);
    }

    // Add D65 as background illumination (scaled down)
    //total_emission += 0.1 * d65(wavelength);
    
    return total_emission;

#elif CURRENT_LIGHTING_MODE == LIGHTING_MODE_COOL
    float total_emission = 0.0;
    // Sum contributions from cool light sources
    for(int i = 0; i < 3; i++) {
        total_emission += spectral_emission(wavelength, cool_lights[i]);
    }
    // Add D65 as background illumination (scaled down)
    //total_emission += 0.1 * d65(wavelength);
    return total_emission;

#elif CURRENT_LIGHTING_MODE == LIGHTING_MODE_RGB_Green
    float total_emission = 0.0;
    
    // Sum contributions from RGB primaries
    for(int i = 0; i < 3; i++) {
        total_emission += spectral_emission(wavelength, rgb_lights[1]);
    }

    // Add D65 as background illumination (scaled down)
    total_emission += 0.0025 * d65(wavelength);
    
    return total_emission;
#endif
}

const mat3 xyz_to_rgb = mat3(
        vec3( 3.2406, -0.9689,  0.0557),
        vec3(-1.5372,  1.8758, -0.2040),
        vec3(-0.4986,  0.0415,  1.0570));

int wavelength_to_idx(in float wavelength) {
    return int(wavelength - WL_START);
}

float cauchy_ior(in float lambda_nm) {
    float lambda_mum = lambda_nm*1e-3;
    return 1.6 + 0.01342 / (lambda_mum*lambda_mum);
}