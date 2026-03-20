#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2  uResolution;
uniform sampler2D uTexture;

out vec4 fragColor;

// ── Helpers ──────────────────────────────────────────────────────────────────

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Returns the specular intensity [0,1] for a given cell coordinate.
float cellSpec(vec2 cell) {
    const float SPIN_SPEED      = 0.20;
    const float HIGHLIGHT_POWER = 28.0;  // high = very few cells fire at once

    float seed  = hash(cell);
    float seed2 = hash(cell + vec2(73.7, 19.3));

    // Per-cell rotating mirror normal
    float angle   = uTime * SPIN_SPEED + seed * 6.2832;
    vec2 normal2d = vec2(cos(angle + seed2 * 3.0),
                         sin(angle * 0.7 + seed * 5.0));

    // Slowly sweeping light direction
    float lightAngle = uTime * SPIN_SPEED * 0.6;
    vec2 lightDir    = vec2(cos(lightAngle), sin(lightAngle));

    float s = dot(normalize(normal2d), lightDir);
    return pow(clamp(s, 0.0, 1.0), HIGHLIGHT_POWER);
}

// ── Main ─────────────────────────────────────────────────────────────────────

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // === Tunable parameters ===
    // Default target tile size in pixels. We'll scale this to exactly fit the
    // containing image by computing an integer number of cells per axis so
    // there are no partial cells at the edges.
    const float CELL_SIZE    = 12.0;  // px per mirror tile (target)
    const float GAP          = 1.0;   // dark gap width (px)
    const float GLARE_RADIUS = 2.5;   // spill in cell-units (5×5 neighborhood)
    const float GLARE_GAIN   = 0.55;  // additive glare strength over the image
    const float RAINBOW_MIX  = 0.18;  // subtle rainbow tint — glints are mostly white

    // ── Which cell does this fragment live in? ───────────────────────────────
    // Compute an integer number of cells that fit exactly into the image
    // bounds so we never end up with partial cells at the edges. We pick the
    // largest integer cell count that doesn't exceed the target CELL_SIZE.
    vec2 cellCount = max(vec2(1.0), floor(uResolution / CELL_SIZE));
    vec2 cellSize  = uResolution / cellCount; // actual per-axis cell size

    vec2 cell  = floor(fragCoord / cellSize);
    vec2 local = mod(fragCoord, cellSize);

    bool inGap = any(lessThan(local, vec2(GAP)));

    // ── Sample base texture at this cell's center ────────────────────────────
    vec2 sampleUV = (cell + vec2(0.5)) * cellSize / uResolution;
    vec4 tex = texture(uTexture, sampleUV);

    // ── Accumulate glare from neighbouring cells ─────────────────────────────
    // Each lit neighbouring cell contributes a glow that falls off with
    // distance, so bright cells bleed light across cell borders (true spill).
    float glareAcc  = 0.0;
    vec3  colorAcc  = vec3(0.0);

    // Fragment position in cell-space (so distances are in cell units)
    vec2 fragInCells = fragCoord / cellSize;

    const int RADIUS = 2;  // sample ±2 cells → 5×5 = 25 taps
    for (int dy = -RADIUS; dy <= RADIUS; dy++) {
        for (int dx = -RADIUS; dx <= RADIUS; dx++) {
            vec2 nc = cell + vec2(float(dx), float(dy));

            float s = cellSpec(nc);
            if (s < 0.001) continue;  // skip dark cells early

            // Distance from this fragment to the neighbour cell's centre
            vec2  ncCenter = nc + 0.5;
            float dist     = length(fragInCells - ncCenter);

            // Smooth radial falloff — glare fades over GLARE_RADIUS cells
            float falloff = 1.0 - smoothstep(0.0, GLARE_RADIUS, dist);
            falloff = falloff * falloff;   // quadratic — tighter core, soft edge

            float contrib = s * falloff;

            // Rainbow colour keyed to that cell's random seed
            float ncSeed = hash(nc);
            vec3 rainbow = 0.5 + 0.5 * cos(
                6.2832 * (ncSeed + uTime * 0.05) + vec3(0.0, 2.1, 4.2));

            // White core + tinted halo
            vec3 glareColor = mix(vec3(1.0), rainbow, RAINBOW_MIX);

            glareAcc += contrib;
            colorAcc += glareColor * contrib;
        }
    }

    glareAcc *= GLARE_GAIN;

    // Average the colour contributions (avoid divide-by-zero)
    vec3 glareCol = (glareAcc > 0.001)
        ? colorAcc / (glareAcc / GLARE_GAIN)   // normalise colour, then rescale
        : vec3(1.0);

    // ── Compose ──────────────────────────────────────────────────────────────
    // Keep the full unmodified texture; glare is purely additive on top so it
    // never wipes out the image — it just brightens where a cell is firing.
    vec3 base  = tex.rgb;
    vec3 color = base + glareCol * clamp(glareAcc, 0.0, 1.0);
    color = min(color, 1.0);

    if (inGap) {
        // Gaps receive a small fraction of the spill so borders soften near glints.
        fragColor = vec4(base * 0.3 + glareCol * clamp(glareAcc * 0.25, 0.0, 0.15), tex.a);
    } else {
        fragColor = vec4(color, tex.a);
    }
}
