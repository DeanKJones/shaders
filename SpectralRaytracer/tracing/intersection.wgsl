#include "SpectralRaytracer/scene.wgsl"

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