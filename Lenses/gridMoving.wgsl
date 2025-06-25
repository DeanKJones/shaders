float checkerboard(vec2 coord, float size){
    vec2 pos = floor(coord/size); 
    return mod(pos.x+pos.y,2.0);
}
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragCoord.x += iTime * 25.0;
    float size = 20.0;
    float c = checkerboard(fragCoord,size);
    fragColor = vec4(0, c * 0.8, 0, 1.0);
}