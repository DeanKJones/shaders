// Code by Simon LUCAS - 26/01/2022

#iChannel0 "FresnelGlass/buffer-a.wgsl"
#include "FresnelGlass/common.wgsl"

void mainImage( out vec4 Col, in vec2 Coo )
{
    vec2 p = Coo/R;
    
    Col = texture(iChannel0,p,10.);
    Col/= Col.w;
    
    // XYZ to RGB
    Col.xyz = xyz_to_rgb*vec3(Col.xyz);
    
    #if 0
    // Isoline
    float d = length((Coo-R.xy/2.)/R.y);
    Col = Col * 0.2 + smoothstep(1./R.y/(d*d),0.,abs(Col - 2.*MP.x));
    #else
    // Tonemapping
    Col = 1.0 - exp( -Col );
    // Gamma correction
    Col = pow(Col,vec4(1./2.2));
    #endif
    
}