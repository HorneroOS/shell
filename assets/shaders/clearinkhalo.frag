#version 440

// Cockpit Clear glyph halo (signal-visual-language §12.1): the silhouette of
// the foreground is dilated into an outline ring plus an optional soft
// shadow, both painted in the halo colour. Only the ring/shadow is output;
// the real glyphs are drawn above it, so the foreground keeps its own
// anti-aliasing. No box, slab or tint is ever produced: pixels further than
// outlinePx / shadowPx from a painted pixel stay fully transparent.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 haloOnLight; // halo drawn around light foreground pixels
    vec4 haloOnDark;  // halo drawn around dark foreground pixels
    vec2 texel;       // one logical pixel in texture coordinates
    float outlinePx;  // hard outline radius, logical px (0 = none)
    float shadowPx;   // soft shadow radius, logical px (0 = none)
    float haloAlpha;  // peak alpha of the ring
};

layout(binding = 1) uniform sampler2D source;

const float TAU = 6.28318530718;

vec4 gathered;   // alpha-weighted foreground colour seen by the taps (premultiplied sum)
float gatheredA; // sum of tap alphas

float tap(vec2 uv, vec2 dir, float r)
{
    vec4 t = texture(source, uv + dir * texel * r);
    gathered += t;
    gatheredA += t.a;
    return t.a;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec4 self = texture(source, uv);
    float own = self.a;
    gathered = self;
    gatheredA = own;
    float ring = own;

    if (outlinePx > 0.0) {
        for (int i = 0; i < 16; i++) {
            float a = float(i) * (TAU / 16.0);
            vec2 d = vec2(cos(a), sin(a));
            ring = max(ring, tap(uv, d, outlinePx));
            ring = max(ring, tap(uv, d, outlinePx * 0.5));
        }
    }

    float soft = 0.0;
    if (shadowPx > 0.0) {
        float sum = own;
        for (int i = 0; i < 12; i++) {
            float a = float(i) * (TAU / 12.0);
            vec2 d = vec2(cos(a), sin(a));
            sum += tap(uv, d, shadowPx);
            sum += tap(uv, d, shadowPx * 0.5);
        }
        // Dense near the glyph, fading out at shadowPx; 2.6 lifts the mean
        // of a thin stroke's neighbourhood to a usable alpha.
        soft = clamp(sum / 25.0 * 2.6, 0.0, 1.0);
    }

    // The halo takes the polarity opposite to the foreground it surrounds,
    // so it holds whatever colour a component paints (text, accents, app
    // icons) instead of trusting every component to follow the region tone.
    float lum = 0.0;
    if (gatheredA > 0.0001)
        lum = dot(gathered.rgb, vec3(0.2126, 0.7152, 0.0722)) / gatheredA;
    vec4 halo = pow(lum, 2.2) > 0.2 ? haloOnLight : haloOnDark;

    // Anti-aliased thin strokes only reach ~0.5 coverage in the dilation;
    // lift it so the ring is solid next to the glyph (RFC 0001 §5.1 needs
    // the foreground, not the wallpaper, to carry the contrast).
    ring = clamp(ring * 2.6, 0.0, 1.0);
    float a = clamp(max(ring, soft), 0.0, 1.0) * haloAlpha;
    fragColor = vec4(halo.rgb * a, a) * qt_Opacity;
}
