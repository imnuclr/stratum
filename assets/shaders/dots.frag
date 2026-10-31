#version 440

// Halftone dots, drawn per pixel on the GPU.
//
// Each cell of the grid takes the colour (or the tone) of the picture at its
// middle and draws one dot there, as big as the picture is bright. Nothing here
// is per-dot work on the CPU, so changing the grid, the dot size or the light is
// only a change of numbers.
//
// Compiled with:  qsb --glsl "100 es,120,150,300 es,310 es,330,440" --hlsl 50 --msl 12 -o dots.frag.qsb dots.frag

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
    float ink;      // 1 on a light theme: dark dots on paper, sized by shade
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
    if (ink > 0.5) {
        // Printed rather than lit: the darker the picture, the bigger the dot,
        // and highlights are left as clean paper instead of a grey wash of
        // large pale dots.
        float shade = mono > 0.5
            ? 1.0 - clamp((luma - lo) / max(hi - lo, 0.12), 0.0, 1.0)
            : 1.0 - luma;
        radius = shade < 0.06 ? 0.0 : cell * dotScale * (0.25 + 0.75 * sqrt(shade));
        if (mono > 0.5) {
            colour = vec3(0.08);
        } else {
            // Same hue, brightness held under a ceiling so every dot reads
            // against white.
            float peak = max(max(c.r, c.g), c.b);
            const float most = 0.42;
            colour = peak <= most ? c : c * (most / peak);
        }
    } else if (mono > 0.5) {
        v = clamp((luma - lo) / max(hi - lo, 0.12), 0.0, 1.0);
        radius = cell * dotScale * sqrt(v);
        colour = vec3(1.0);
    } else {
        /*
         * Colour, with the same tone stretch mono gets: the dot's size spans
         * the range the picture really uses, rather than the whole scale. A
         * dark picture used most of the scale on tones it never reaches, so
         * every dot came out small and dim where mono was crisp.
         */
        v = clamp((luma - lo) / max(hi - lo, 0.12), 0.0, 1.0);
        // A coloured dot has to be big enough to show its colour.
        radius = v < 0.02 ? 0.0 : cell * dotScale * (0.34 + 0.66 * sqrt(v));
        /*
         * The hue as it is, lifted to the brightness its stretched tone asks
         * for: a dark but saturated area keeps its colour and still reads,
         * instead of being a muddy speck.
         */
        float peak = max(max(c.r, c.g), c.b);
        float want = mix(0.42, 1.0, v);
        colour = peak < 0.02 ? vec3(want) : c * (want / peak);
    }

    float a = clamp(radius - length(px - centre) + 0.5, 0.0, 1.0) * light;
    fragColor = vec4(colour * a, a) * qt_Opacity;
}
