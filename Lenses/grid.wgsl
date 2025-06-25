
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float Size = 25.0;
    vec2 Pos = floor(fragCoord / Size);
    float PatternMask = mod(Pos.x + mod(Pos.y, 2.0), 2.0);
    fragColor = PatternMask * vec4(0.0, 1.0, 0.0, 1.0);
}