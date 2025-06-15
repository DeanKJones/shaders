
#include "SpectralRaytracer/common.wgsl"

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