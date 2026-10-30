#version 440

// Halftone dots, drawn per pixel on the GPU.
//
// Each cell of the grid takes the colour (or the tone) of the picture at its
// middle and draws one dot there, as big as the picture is bright. Nothing here
// is per-dot work on the CPU, so changing the grid, the dot size or the light is
// only a change of numbers.
//
// Compiled with:  qsb --qt6 -o dots.frag.qsb dots.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // the item, in pixels
    vec2 uvScale;   // which part of the picture fills it (a centred crop)
    vec2 uvOffset;
    float cell;     // grid pitch, in pixels
    float dotScale; // dot radius as a share of the cell
    float light;    // 0..1, how bright the dots are drawn
    float mono;     // 1 for dots without colour
    float lo;       // tones the picture really spans, for mono
    float hi;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 centre = (floor(px / cell) + 0.5) * cell;
    vec2 uv = uvOffset + uvScale * (centre / size);

    // Mipmapped, so a read at the cell's middle is an average of the cell and
    // not a single speck that happens to sit there.
    vec3 c = textureLod(source, uv, log2(max(cell, 1.0))).rgb;
    float luma = dot(c, vec3(0.299, 0.587, 0.114));

    float v = luma;
    float radius;
    vec3 colour;
    if (mono > 0.5) {
        v = clamp((luma - lo) / max(hi - lo, 0.12), 0.0, 1.0);
        radius = cell * dotScale * sqrt(v);
        colour = vec3(1.0);
    } else {
        // A coloured dot has to be big enough to show its colour.
        radius = v < 0.04 ? 0.0 : cell * dotScale * (0.4 + 0.6 * sqrt(v));
        // Same hue, brightness raised to a floor, so shadows become small
        // saturated dots rather than disappearing.
        float peak = max(max(c.r, c.g), c.b);
        const float want = 0.62;
        colour = peak >= want ? c : (peak < 0.047 ? vec3(want) : c * (want / peak));
    }

    float a = clamp(radius - length(px - centre) + 0.5, 0.0, 1.0) * light;
    fragColor = vec4(colour * a, a) * qt_Opacity;
}
