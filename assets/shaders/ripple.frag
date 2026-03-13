#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2  uResolution;
uniform vec4  uColorA;   // gradient start colour (left / top-left)
uniform vec4  uColorB;   // gradient end colour   (right / bottom-right)

out vec4 fragColor;

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

    // Layer two sine waves at different frequencies to break up regularity.
    // Primary ring pattern.
    float phase1 = dist * 14.0 - t * 10.0;
    float wave1  = sin(phase1);

    // Secondary wave at 1.618x frequency (golden ratio) for non-repeating interference.
    float phase2 = dist * 22.65 - t * 13.0;
    float wave2  = sin(phase2) * 0.4;   // lower amplitude so it doesn't dominate

    // Combine waves with exponential decay (shared decay for consistency).
    float decay  = 1.1;
    float wave   = (wave1 + wave2) * exp(-dist * decay) * 0.6;  // 0.6 scales combined amplitude back

    // Fade out at far distances (scaled for 4x zoom)
    wave *= 1.0 - smoothstep(2.2, 5.2, dist);

    // Unit vector from center (needed for gradient and CA).
    vec2 safeToC = (dist > 0.001) ? toC / dist : vec2(0.0);

    // ── Surface normal from wave gradient (for 3-D lighting) ─────────────────
    // Use finite differences: sample the wave slightly farther out to approximate
    // the gradient.  Simpler than analytic differentiation with two waves.
    float eps = 0.015;   // step size in dist
    float distEps = dist + eps;

    float phase1eps = distEps * 14.0 - t * 10.0;
    float wave1eps  = sin(phase1eps);
    float phase2eps = distEps * 22.65 - t * 13.0;
    float wave2eps  = sin(phase2eps) * 0.4;
    float waveEps   = (wave1eps + wave2eps) * exp(-distEps * decay) * 0.6;
    waveEps        *= 1.0 - smoothstep(2.2, 5.2, distEps);

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
    float iridPhase = phase1 * 0.35 + t * 0.18;
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
