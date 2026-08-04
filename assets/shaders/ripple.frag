#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2  uResolution;
uniform vec4  uColorA;   // gradient start colour (left / top-left)
uniform vec4  uColorB;   // gradient end colour   (right / bottom-right)

out vec4 fragColor;

// Cheap hash → [0,1] for procedural noise (no texture sampler needed).
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise with smooth bilinear interpolation.
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Quintic smoothstep for softer derivatives (better lighting normals).
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Two-octave fBm for low-frequency spatial variation without harsh grain.
float fbm2(vec2 p) {
    return valueNoise(p) * 0.66 + valueNoise(p * 2.17 + 3.1) * 0.34;
}

// 2.5D noise: crossfade between uncorrelated time slices so a fixed point's
// value truly evolves (pure 2D domain-drift alone just slides a frozen field).
// Returns roughly [-1, 1].
float evolvingNoise(vec2 p, float time) {
    float slice = time;
    float i = floor(slice);
    float f = fract(slice);
    f = f * f * (3.0 - 2.0 * f);  // smooth hermite blend

    // Large, distinct offsets per integer slice → uncorrelated patterns.
    vec2 o0 = vec2(i * 17.13, i * 9.71);
    vec2 o1 = vec2((i + 1.0) * 17.13, (i + 1.0) * 9.71);

    float n0 = fbm2(p + o0);
    float n1 = fbm2(p + o1);
    return mix(n0, n1, f) * 2.0 - 1.0;
}

// Combined warp field at position `pos` (aspect-corrected, centered coords).
// Structured so successive rings see a different distortion at the same spot.
float noiseField(vec2 pos, float time) {
    // Large soft blobs — evolve ~1× per unit `t` (a bit faster than ring period).
    float n = evolvingNoise(pos * 1.4, time * 1.6) * 0.7;
    // Mid-scale detail — morphs a little quicker.
    n += evolvingNoise(pos * 3.2 + 4.2, time * 2.3 + 1.7) * 0.55;
    // Mild spatial advection so patterns also travel, not only dissolve in place.
    n += (fbm2(pos * 2.1 + vec2(time * 1.1, time * 0.75) + 7.3) * 2.0 - 1.0) * 0.3;
    return n;
}

// Wave height at a radial distance, with optional phase offset (for noise warp).
float waveAt(float dist, float t, float phaseOffset) {
    float phase1 = dist * 14.0 - t * 10.0 + phaseOffset;
    float wave1  = sin(phase1);

    // Secondary wave at ~φ× frequency for non-repeating interference.
    float phase2 = dist * 22.65 - t * 13.0 + phaseOffset * 1.3;
    float wave2  = sin(phase2) * 0.4;

    float decay = 1.1;
    float wave  = (wave1 + wave2) * exp(-dist * decay) * 0.6;
    wave *= 1.0 - smoothstep(2.2, 5.2, dist);
    return wave;
}

// ── Main ─────────────────────────────────────────────────────────────────────

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // Normalise to [0,1] with aspect-ratio correction so ripples are circular.
    // Keep uv in [0,1]^2 for gradient evaluation; use uvAR for geometry.
    float aspect = uResolution.x / uResolution.y;
    vec2 uv      = fragCoord / uResolution;
    vec2 uvAR    = vec2(uv.x * aspect, uv.y);

    // Ripple origin: left-centre in aspect-corrected space.
    // Scaling toC by 0.25 zooms out 4x for larger, sparser rings.
    vec2 center  = vec2(0.0, 0.5);
    vec2 toC     = (uvAR - center) * 0.25;
    float dist   = length(toC);

    // ── Wave field ───────────────────────────────────────────────────────────
    float speed  = 0.073;  // slowed to 1/3 (was 0.22); adjust here for tweaking
    float t      = uTime * speed;

    // Soft evolving noise warps ring phases so crests aren't perfect circles
    // and the warp at a fixed spot changes as rings pass through.
    // noiseAmt is phase offset in radians. Tweak as needed.
    float noiseAmt = 0.4;
    float phaseOffset = noiseField(toC, t) * noiseAmt;

    float wave = waveAt(dist, t, phaseOffset);

    // Unit vector from center (needed for gradient and CA).
    vec2 safeToC = (dist > 0.001) ? toC / dist : vec2(0.0);

    // ── Surface normal from wave gradient (for 3-D lighting) ─────────────────
    // Finite differences in the radial direction; re-sample noise at the
    // offset distance so normals follow the warped surface.
    float eps = 0.015;
    float distEps = dist + eps;
    vec2  toCEps  = safeToC * distEps;
    float phaseOffsetEps = noiseField(toCEps, t) * noiseAmt;

    float waveEps = waveAt(distEps, t, phaseOffsetEps);

    float dWdx = (waveEps - wave) / eps;   // gradient in radial direction
    vec2 grad  = safeToC * dWdx;            // project to 2D

    // normalStrength controls how deeply curved the surface appears.
    float normalStrength = 1.8;
    vec3  N = normalize(vec3(-grad * normalStrength, 1.0));

    // ── Lighting scalars (computed before col is built) ───────────────────────
    vec3 L = normalize(vec3(0.6, 0.8, 1.0));   // fixed light: slightly above-right
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0)); // half-vector (view = straight on)

    // Signed diffuse factor: positive on lit faces, negative on shadowed faces.
    // Using a multiplicative blend below keeps colours in-hue (no grey push).
    float nDotL  = dot(N, L);
    float litAmt = nDotL * 0.12;   // ±0.12 maximum swing

    // Specular: tight glint, low weight so it reads as a sheen not a hotspot.
    float spec   = pow(max(dot(N, H), 0.0), 96.0) * 0.22;

    // ── Iridescence scalars ───────────────────────────────────────────────────
    float tiltMag   = length(N.xy);
    // Use unwarped radial phase for iridescence so hue bands stay coherent.
    float iridPhase = (dist * 14.0 - t * 10.0) * 0.35 + t * 0.18;
    vec3  iridColor = 0.5 + 0.5 * cos(iridPhase + vec3(0.0, 2.094, 4.189));
    // sqrt mask ramps up gently; weight 0.18 keeps it a hue shift, not a tint.
    float iridMask  = sqrt(clamp(tiltMag * abs(wave) * 2.0, 0.0, 1.0)) * 0.18;

    // ── Chromatic aberration (refraction through the glassy surface) ──────────
    float caAmt = abs(wave) * 0.025;
    vec2 uvR = uv + safeToC * caAmt * 1.4;
    vec2 uvG = uv;
    vec2 uvB = uv - safeToC * caAmt * 1.4;

    // ── Base gradient colour (diagonal, matching AppTheme.primaryGradient) ────
    float tR = clamp((uvR.x + uvR.y) * 0.5, 0.0, 1.0);
    float tG = clamp((uvG.x + uvG.y) * 0.5, 0.0, 1.0);
    float tB = clamp((uvB.x + uvB.y) * 0.5, 0.0, 1.0);

    vec3 col;
    col.r = mix(uColorA.r, uColorB.r, tR);
    col.g = mix(uColorA.g, uColorB.g, tG);
    col.b = mix(uColorA.b, uColorB.b, tB);

    // ── Compose ──────────────────────────────────────────────────────────────
    // 1. Diffuse: multiplicative tint keeps hue, just lightens/darkens slightly.
    col = clamp(col + col * litAmt, 0.0, 1.0);

    // 2. Iridescence: mix toward a hue-shifted version — no brightness added.
    col = mix(col, col * iridColor * 1.4, iridMask);

    // 3. Specular: small additive white glint on ridge crests only.
    col += spec;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
