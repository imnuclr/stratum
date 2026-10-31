#version 440

// Halftone dots, drawn per pixel on the GPU.
//
// Each cell of the grid takes the colour (or the tone) of the picture at its
// middle and draws one dot there, as big as the picture is bright. Nothing here
// is per-dot work on the CPU, so changing the grid, the dot size or the light is
// only a change of numbers.
//
// Compiled with:  qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o dots.frag.qsb dots.frag
//
// Only those GLSL versions, the same ones Qt's own ShaderEffect vertex shader
// ships. With 330 and 440 in the file as well, Qt paired a 440 fragment (inputs
// at explicit locations) with its 150 vertex (none): NVIDIA links that anyway,
// Mesa refuses it, and on Intel and AMD the dots drew nothing at all.

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

    /*
     * The cell's average, as nine taps across it rather than one mip level.
     *
     * Reading a blurred level is cheaper, but the level has to exist: where the
     * texture had none the read returned nothing and the whole wallpaper came
     * out black, on one machine and not another. Nothing here names a level.
     */
    vec2 tap = uvScale / size * (cell / 3.0);
    vec3 c = vec3(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++)
            c += texture(source, uv + vec2(float(i), float(j)) * tap).rgb;
    }
    c /= 9.0;
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
        /*
         * Sized as mono sizes them, from nothing: dark areas are a fine grain
         * of small dots rather than a floor of mid-sized ones, which made the
         * colour look a coarse, even grid where mono was crisp.
         */
        radius = cell * dotScale * sqrt(v);
        /*
         * The hue as it is, lifted to the brightness its stretched tone asks
         * for: a small dot in a dark area still shows its colour instead of
         * being a muddy speck.
         */
        float peak = max(max(c.r, c.g), c.b);
        float want = mix(0.6, 1.0, v);
        colour = peak < 0.02 ? vec3(want) : c * (want / peak);
    }

    float a = clamp(radius - length(px - centre) + 0.5, 0.0, 1.0) * light;
    fragColor = vec4(colour * a, a) * qt_Opacity;
}
