// Code by Simon LUCAS - 26/01/2022
#include "FresnelGlass/common.wgsl"
#iChannel0 "FresnelGlass/buffer-a.wgsl"

// Scene
// GRID CONFIGURATION
#define GRID_WIDTH 9
#define GRID_HEIGHT 9
#define GRID_SPACING 0.1      // Distance between sphere centers
#define SPHERE_BASE_RADIUS 0.04
#define SPHERE_RADIUS_VARIATION 0.0175
#define GRID_CENTER_X 0.0
#define GRID_CENTER_Y 0.0

// Light configuration
#define NUM_LIGHTS 10
#define LIGHT_RADIUS 0.005

// Calculate total spheres needed
const int nSphere = GRID_WIDTH * GRID_HEIGHT + NUM_LIGHTS;

// Global spheres array
Sphere spheres[nSphere];

// Initialize the sphere grid
void init_sphere_grid() {
    int sphere_idx = 0;
    
    // Create main grid of spheres
    for(int y = 0; y < GRID_HEIGHT; y++) {
        for(int x = 0; x < GRID_WIDTH; x++) {
            // Calculate position relative to grid center
            float pos_x = GRID_CENTER_X + (float(x) - float(GRID_WIDTH-1) * 0.5) * GRID_SPACING;
            float pos_y = GRID_CENTER_Y + (float(y) - float(GRID_HEIGHT-1) * 0.5) * GRID_SPACING;
            
            // Add some variation to radius based on position
            float radius_variation = sin(float(x) * 2.0) * cos(float(y) * 1.5) * SPHERE_RADIUS_VARIATION;
            float radius = SPHERE_BASE_RADIUS + radius_variation;
            
            spheres[sphere_idx] = Sphere(
                vec2(pos_x, pos_y),
                radius,
                false  // Not emissive
            );
            sphere_idx++;
        }
    }
    
    // Add light sources around the grid
    float light_distance = max(float(GRID_WIDTH), float(GRID_HEIGHT)) * GRID_SPACING * 0.8;
    for(int i = 0; i < NUM_LIGHTS; i++) {
        float angle = float(i) * 2.0 * Pi / float(NUM_LIGHTS);
        angle += 45.0;
        spheres[sphere_idx] = Sphere(
            vec2(GRID_CENTER_X + cos(angle) * light_distance,
                 GRID_CENTER_Y + sin(angle) * light_distance),
            LIGHT_RADIUS,
            true  // Emissive
        );
        sphere_idx++;
    }
}
// return distance to intersection
// intersection valid if len is positive
float intersect_sphere(in vec2 ro,in vec2 rd,in int i) {
    vec2 oc = spheres[i].pos - ro;
    float l = dot(rd, oc);
    float det = l*l - dot(oc, oc) + spheres[i].rad*spheres[i].rad;
    if (det < 0.0) return -1.;
    float len = l - sqrt(det);
    if (len < 0.0) len = l + sqrt(det);
    return len;
}

// SPATIAL OPTIMIZATION CONFIGURATION
#define USE_SPATIAL_GRID 0
#define SPATIAL_GRID_SIZE 16  // Subdivisions per axis
#define MAX_SPHERES_PER_CELL 2

// Spatial grid cell structure
struct GridCell {
    int sphere_indices[MAX_SPHERES_PER_CELL];
    int count;
};

// Global spatial grid
GridCell spatial_grid[SPATIAL_GRID_SIZE * SPATIAL_GRID_SIZE];

// Scene bounds for spatial mapping
const float SCENE_MIN = -0.3;
const float SCENE_MAX = 0.3;
const float SCENE_SIZE = SCENE_MAX - SCENE_MIN;
const float CELL_SIZE = SCENE_SIZE / float(SPATIAL_GRID_SIZE);

// Convert world position to grid coordinates
ivec2 world_to_grid(vec2 pos) {
    vec2 normalized_pos = (pos - vec2(SCENE_MIN)) / SCENE_SIZE;
    ivec2 grid_pos = ivec2(normalized_pos * float(SPATIAL_GRID_SIZE));
    return clamp(grid_pos, ivec2(0), ivec2(SPATIAL_GRID_SIZE - 1));
}

// Get grid cell index from grid coordinates
int grid_coord_to_index(ivec2 coord) {
    return coord.y * SPATIAL_GRID_SIZE + coord.x;
}

// Initialize spatial grid
void init_spatial_grid() {
    // Clear all cells
    for(int i = 0; i < SPATIAL_GRID_SIZE * SPATIAL_GRID_SIZE; i++) {
        spatial_grid[i].count = 0;
    }
    
    // Insert each sphere into appropriate cells
    for(int s = 0; s < nSphere; s++) {
        vec2 sphere_pos = spheres[s].pos;
        float sphere_rad = spheres[s].rad;
        
        // Calculate AABB of sphere in grid space
        ivec2 min_cell = world_to_grid(sphere_pos - vec2(sphere_rad));
        ivec2 max_cell = world_to_grid(sphere_pos + vec2(sphere_rad));
        
        // Insert sphere into all overlapping cells
        for(int y = min_cell.y; y <= max_cell.y; y++) {
            for(int x = min_cell.x; x <= max_cell.x; x++) {
                int cell_idx = grid_coord_to_index(ivec2(x, y));
                GridCell cell = spatial_grid[cell_idx];
                
                if(cell.count < MAX_SPHERES_PER_CELL) {
                    spatial_grid[cell_idx].sphere_indices[cell.count] = s;
                    spatial_grid[cell_idx].count++;
                }
            }
        }
    }
}

// Optimized ray-sphere intersection using spatial grid
Inter intersect_optimized(in vec2 ro, in vec2 rd) {
    Inter best_inter;
    best_inter.t = -1.;
    float min_dist = 10000.;
    
    // DDA-like traversal of spatial grid
    vec2 current_pos = ro;
    float step_size = CELL_SIZE * 0.1; // Small step size for traversal
    int max_steps = int(length(vec2(SCENE_SIZE)) / step_size) + 1;
    
    for(int step = 0; step < max_steps; step++) {
        // Check if we're still in scene bounds
        if(current_pos.x < SCENE_MIN || current_pos.x > SCENE_MAX ||
           current_pos.y < SCENE_MIN || current_pos.y > SCENE_MAX) {
            break;
        }
        
        ivec2 grid_coord = world_to_grid(current_pos);
        int cell_idx = grid_coord_to_index(grid_coord);
        GridCell cell = spatial_grid[cell_idx];
        
        // Test spheres in current cell
        for(int i = 0; i < cell.count; i++) {
            int sphere_idx = cell.sphere_indices[i];
            float dist = intersect_sphere(ro, rd, sphere_idx);
            
            if(dist > 0. && dist < min_dist) {
                min_dist = dist;
                best_inter.t = dist;
                best_inter.pos = ro + rd * dist;
                best_inter.nor = normalize(best_inter.pos - spheres[sphere_idx].pos);
                best_inter.emi = spheres[sphere_idx].emi;
            }
        }
        
        // If we found an intersection closer than our current position, we can stop
        if(best_inter.t > 0. && best_inter.t < length(current_pos - ro)) {
            break;
        }
        
        current_pos += rd * step_size;
    }
    
    return best_inter;
}

// Modified intersect function with optimization toggle
Inter intersect(in vec2 ro, in vec2 rd) {
#if USE_SPATIAL_GRID == 1
    return intersect_optimized(ro, rd);
#else
    // Original brute force method
    Inter i;
    i.t = -1.;
    float d = 10000.;
    
    for(int s = 0; s < nSphere; s++){
        float d_ = intersect_sphere(ro,rd,s);
        if(d_ > 0. && d_ < d){
            d = d_;
            i.t = d;
            i.pos = ro + rd * i.t;
            i.nor = normalize(i.pos - spheres[s].pos);
            i.emi = spheres[s].emi;
        }
    }
    
    return i;
#endif
}


void mainImage( out vec4 Col, in vec2 Coo )
{
    init_sphere_grid();
#if USE_SPATIAL_GRID == 1
    init_spatial_grid();
#endif

    Col = vec4(0.);
    // Higher number of sample can cause problems with the PRNG
    if(iFrame > 20000){
        Col = texture(iChannel0,Coo/R.xy);
        return;
    }
    
    // Set seed for the PRNG (pcg)
    seed = vec2(float(iFrame+1) * Coo);
    
    // Evaluation point position
    vec2 p = (Coo-R.xy/2.)/R.y;
    // Jitter for anti-aliasing
    p += (vec2(hash(),hash())-0.5)/R.y;

    // Interate over random wavelengths
    for(int idx = 0; idx < NUM_WL_SAMPLES; idx++){
    
        // Sample random wavelength
        float wl = hash() * WL_RANGE + WL_START;
        // Sample random direction
        float th = hash() * 2. * Pi;
        
        // Setup ray tracing
        vec2 ro = p;
        vec2 rd = vec2(cos(th),sin(th));
        Inter i;
        i.emi = false;
        
        float t = 0.;
        for(int dep = 0; dep < MAX_DEPTH && !i.emi ; dep++){
            i = intersect(ro,rd);
            
            if(i.t > 0.){
                t += i.t;
                // wavelength dependant index of refraction
                float ior = enhanced_cauchy_ior(wl);
                vec2 pi = ro + i.t * rd;
                float n1,n2;
                if(dot(i.nor,rd)>0.){ // hit from inside
                    n1 = ior;
                    n2 = N1;
                    i.nor = -i.nor;
                } else { // hit from outside
                    n1 = N1;
                    n2 = ior;
                }
                
                if(i.emi){ // hit light
                    float light_emission = lighting(wl);
                    vec3 xyz_value = xyz_bar(wl);
                    Col.xyz += 0.5 * light_emission * xyz_value;
                    break;
                }
                else { // hit glass
                    // Compute fresnel approx
                    float cosTheta = dot(-rd,i.nor);
                    float s1 = (ior - N1);
                    float s2 = (ior + N1);
                    float f0 = s1*s1/(s2*s2);
                    float fr =  f0 + (1.0 - f0)*pow(1.0 - cosTheta, 5.0);
                    float r = hash();
                    // Change ray direction based on fresnel
                    if(r < fr){
                        rd = reflect(rd, i.nor);   
                        pi += rd * EPS;
                    } else {
                        rd = refract(rd, i.nor, n1/n2);
                        pi += rd * EPS;
                    }                 

                }
                
                // Set the new ray origin
                ro = pi;
                
            }
            else{break;}
            
        }
    
    } // wavelengths iteration
    
    // Color in XYZ
    Col /= float(NUM_WL_SAMPLES);
    
    // Add previous frame
    Col.w = 1.;
    Col += texture(iChannel0,Coo/R.xy);

}