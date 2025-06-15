//######################################//
//######## SCENE DEFINITION   ##########//
//######################################//
#pragma once
#include "SpectralRaytracer/tracing/intersections/sphere.wgsl"

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