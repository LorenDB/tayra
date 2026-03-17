#version 460
#include <flutter/runtime_effect.glsl>

// ─────────────────────────────────────────────
//  Uniforms supplied by Flutter's FragmentProgram
//    shader.setFloat(0, uTime);
//    shader.setFloat(1, uResolution.x);
//    shader.setFloat(2, uResolution.y);
// ─────────────────────────────────────────────
uniform float uTime;
uniform vec2  uResolution;

out vec4 fragColor;

// ── Helpers ──────────────────────────────────

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// ── Spark parameters ─────────────────────────

const int   NUM_SPARKS   = 80;
const float SPEED        = 0.8;   // base vertical speed
const float DRIFT_SCALE  = 0.08;   // horizontal turbulence amplitude
const float DRIFT_FREQ   = 0.8;    // horizontal oscillation frequency
const float BASE_FRAC    = 0.96;   // spawn band
const float SPAWN_WIDTH  = 0.38;   // half-width of spawn zone
const float GLOW_RADIUS  = 0.022;  // soft glow radius in UV space
const float CORE_RADIUS  = 0.007;  // hard bright core radius
const float MAX_ALPHA    = 0.3;   // overall opacity ceiling

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    float brightness = 0.0;

    for (int i = 0; i < NUM_SPARKS; i++) {
        float fi = float(i);

        // ── Per-spark seed values ─────────────────
        float seedX     = hash11(fi * 1.7123);
        float seedPhase = hash11(fi * 2.3456 + 7.89);
        float seedLife  = hash11(fi * 3.1415 + 1.23);
        float seedSize  = hash11(fi * 0.9876 + 4.56);
        float seedDelay = hash11(fi * 5.4321 + 0.11);

        // ── Lifetime cycle ────────────────────────
        float lifetime  = 3.0 + seedLife * 3.0;
        float t = mod(uTime * SPEED + seedDelay * lifetime, lifetime) / lifetime;

        // ── Spark position ────────────────────────
        float spawnX = 0.5 + (seedX - 0.5) * 2.0 * SPAWN_WIDTH;
        float drift  = DRIFT_SCALE * sin(DRIFT_FREQ * 6.2832 * t + seedPhase * 6.2832);

        // Rise from bottom (y=1) to top (y=0)
        float riseY  = 1.0 - t;
        float sparkY = riseY * BASE_FRAC + (1.0 - BASE_FRAC);

        vec2 sparkPos = vec2(spawnX + drift * t, sparkY);

        // ── Distance-based glow ───────────────────
        vec2 delta = (uv - sparkPos) * vec2(uResolution.x / uResolution.y, 1.0);
        float dist = length(delta);

        float glowR  = GLOW_RADIUS * (0.7 + seedSize * 0.6);
        float coreR  = CORE_RADIUS * (0.7 + seedSize * 0.6);

        float glow   = exp(-dist * dist / (glowR * glowR * 0.5));
        float core   = exp(-dist * dist / (coreR * coreR * 0.5));

        // ── Alpha envelope ────────────────────────
        float fadeIn  = smoothstep(0.0,  0.08, t);
        float fadeOut = 1.0 - smoothstep(0.90, 1.0,  t);
        float alpha   = fadeIn * fadeOut;

        float flicker = 0.82 + 0.18 * sin(uTime * (3.5 + seedPhase * 4.0) + fi);

        brightness += (glow * 0.55 + core * 1.0) * alpha * flicker;
    }

    brightness    = clamp(brightness, 0.0, 1.0);
    float alpha   = brightness * MAX_ALPHA;

    vec3 sparkCol = mix(vec3(1.0, 0.97, 0.92), vec3(1.0), brightness);

    fragColor = vec4(sparkCol * alpha, alpha);
}
