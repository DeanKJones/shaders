
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
