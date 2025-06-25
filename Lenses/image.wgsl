// Created by Justin Shrake - @j2rgb/2019
// Created in https://github.com/jshrake/grimoire
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// An artistic lens dispersion effect. This is not intended to be physically realistic.

// Resources:
// - https://web.archive.org/web/20061128135550/http://home.iitk.ac.in/~shankars/reports/dispersionraytrace.pdf
// - inspired by https://www.taylorpetrick.com/blog/post/dispersion-opengl

// Use the mouse to move the lens

#iChannel0 "Lenses/grid.wgsl"

// Comment to hide the lens ring
#define SHOW_RING

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec2 lens_uv = fragCoord / iResolution.y;
  vec2 lens_pos = iMouse.xy / iResolution.y;
  if (iMouse.xy == vec2(0, 0)) {
	lens_pos = vec2(1.0, 0.5);
  }
  vec2 lens_delta = (lens_uv - lens_pos);
  float lens_dist = length(lens_delta);

  // Knobs to control the size and the "zoom" amount of the lens
  float lens_radius = 0.45;
  float lens_zoom = 2.0;

  // pretend that the lens is spherical
  // For the z component, see https://www.desmos.com/calculator/5p0apo0bqm
  // Fudge the z component for stylistic control
  float lens_radius_fudge = 0.5;
  vec3 lens_normal =
      normalize(vec3(lens_delta.xy, lens_zoom * sqrt(lens_radius_fudge * lens_radius - lens_dist*lens_dist)));
  // the incoming light direction
  vec3 incident = normalize(vec3(0.0, 0.0, -1.0));
    
  // ior ratios of (medium A)/(medium B). 
  // medium A is outside the lens, medium B is inside the lens
  // - Use an ior of 1.0, corresponding to air, for medium A
  // - Use a slightly higher ior for medium B. Tune to taste!
  // See 
  // - https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/refract.xhtml
  // - https://pixelandpoly.com/ior.html
  float eta_r = 1.0 / 1.015;
  float eta_y = 1.0 / 1.017;
  float eta_g = 1.0 / 1.019;
  float eta_c = 1.0 / 1.021;
  float eta_b = 1.0 / 1.023;
  float eta_v = 1.0 / 1.025;


  // Calculate different refraction vectors for each color channel
  vec2 refract_r = refract(incident, lens_normal, eta_r).xy;
  vec2 refract_y = refract(incident, lens_normal, eta_y).xy;
  vec2 refract_g = refract(incident, lens_normal, eta_g).xy;
  vec2 refract_c = refract(incident, lens_normal, eta_c).xy;
  vec2 refract_b = refract(incident, lens_normal, eta_b).xy;
  vec2 refract_v = refract(incident, lens_normal, eta_v).xy;

  vec3 tex = texture(iChannel0, uv).rgb;
  vec3 tex_r = texture(iChannel0, refract_r + uv).rgb;
  vec3 tex_y = texture(iChannel0, refract_y + uv).rgb;
  vec3 tex_g = texture(iChannel0, refract_g + uv).rgb;
  vec3 tex_c = texture(iChannel0, refract_c + uv).rgb;
  vec3 tex_b = texture(iChannel0, refract_b + uv).rgb;
  vec3 tex_v = texture(iChannel0, refract_v + uv).rgb;

  float r = tex_r.r * 0.5;
  float g = tex_g.g * 0.5;
  float b = tex_b.b * 0.5;
  float y = dot(vec3(2.0, 2.0, -1.0), tex_y)/6.0;
  float c = dot(vec3(-1.0, 2.0, 2.0), tex_c)/6.0;
  float v = dot(vec3(2.0, -1.0, 2.0), tex_v)/6.0;

  float R = r + (2.0 * v + 2.0 * y - c)/3.0;
  float G = g + (2.0 * y + 2.0 * c - v)/3.0;
  float B = b + (2.0 * c + 2.0 * v - y)/3.0;

  vec3 color = mix(tex, vec3(R, G, B), step(lens_dist, lens_radius));
    
#ifdef SHOW_RING
  float ring = smoothstep(
      0.0, 3.0 / iResolution.y,
      abs(length((lens_uv - lens_pos)) - lens_radius) - 0.002);
  color *= ring;
#endif
  fragColor = vec4(color, 1.0);
}