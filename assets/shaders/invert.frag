#version 440

// Light ink for dark ink, and the reverse, keeping every shade's place in the
// scale: a widget drawn for one theme, shown over a wallpaper that suits the
// other. Colours arrive premultiplied, so inverting is alpha minus colour.
//
// Compiled with:  qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o invert.frag.qsb invert.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    fragColor = vec4(c.a - c.rgb, c.a) * qt_Opacity;
}
