
#define PI 3.14159265358979323
#define PATH_LENGTH 12

#define LOWER_BOUND 350
#define UPPER_BOUND 950
#define NUM_WAVELENGTHS 75

#define LAMBERTIAN 0
#define METAL 1
#define DIELECTRIC 2

const mat3 XYZ_2_RGB = (mat3(
     3.2404542,-0.9692660, 0.0556434,
    -1.5371385, 1.8760108,-0.2040259,
    -0.4985314, 0.0415560, 1.0572252
));

const mat3 RGB_2_XYZ = (mat3(
    0.4124564, 0.2126729, 0.0193339,
    0.3575761, 0.7151522, 0.1191920,
    0.1804375, 0.0721750, 0.9503041
));


//######################################//
//############  STRUCTURES  ############//
//######################################//

struct Ray
{
    vec3 origin;
    vec3 direction;
    float wavelength;
};

struct Material
{
    int   materialType;
    vec3  albedo;
    float fuzz;
    float refractionIndex;
};

struct Hit
{
    float t;
    vec3 p;
    vec3 normal;
    Material mat;
};

struct Sphere{
    vec3 center;
    float radius;
    Material mat;
};


//######################################//
//######## SCENE DEFINITION   ##########//
//######################################//

Sphere sceneList[] = Sphere[5](
    Sphere(
        vec3(0., 0., 0.),
        1.,
        Material(DIELECTRIC, vec3(.5, .4, .4), 1., 1.5)
    ),
    Sphere(
        vec3(1.5, 0.2, 0.2),
        0.2,
        Material(DIELECTRIC, vec3(.5, .4, .4), 1., 1.5)
    ),
    Sphere(
        vec3(0., 0., 0.),
        0.3,
        Material(DIELECTRIC, vec3(.5, .4, .4), 1., 1.5)
    ),
    Sphere(
        vec3(-0.5, -0.8, -1.0),
        0.2,
        Material(DIELECTRIC, vec3(.5, .4, .4), 1., 1.5)
    ),
    Sphere(
        vec3(0., -1001., 0.),
        1000.,
        Material(LAMBERTIAN, vec3(.5, .5, .2), .4, 0.)
    )
);




//######################################//
//############     RNG     #############//
//######################################//

//
// Hash functions by Nimitz:
// https://www.shadertoy.com/view/Xt3cDn
//

uint baseHash(uvec2 p) {
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    return h32^(h32 >> 16);
}

float hash1(inout float seed) {
    uint n = baseHash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    return float(n)/float(0xffffffffU);
}

vec2 hash2(inout float seed) {
    uint n = baseHash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    uvec2 rz = uvec2(n, n*48271U);
    return vec2(rz.xy & uvec2(0x7fffffffU))/float(0x7fffffff);
}