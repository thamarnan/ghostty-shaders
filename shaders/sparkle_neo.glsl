// Sparkle Neo: cursor-triggered green sparkle burst.
//
// A calmer green variant of the sparkle effect: particles flare near the cursor
// after movement, drift outward briefly, then fade.

// ----------------------------- CONFIG --------------------------------------
const float DURATION = 0.38;
const float FADE_IN = 0.035;
const float PARTICLE_COUNT = 18.0;
const float SPREAD = 34.0;
const float SPARK_SIZE = 1.7;
const float TRAIL_LENGTH = 7.5;
const float CELL_WIDTH_FROM_HEIGHT = 0.50;
const float ADDITIVE_STRENGTH = 0.54;

const vec3 SPARK_GREEN = vec3(0.12, 0.95, 0.34);
const vec3 SPARK_HEAD = vec3(0.72, 1.00, 0.78);
// ---------------------------------------------------------------------------

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 hash21(float n) {
    return vec2(hash11(n + 17.1), hash11(n + 73.7));
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * h);
}

float spark(vec2 p, vec2 center, vec2 dir, float size, float tail) {
    vec2 tip = center + dir * tail;
    vec2 back = center - dir * tail * 0.32;
    float streak = 1.0 - smoothstep(0.0, size, sdSegment(p, back, tip));
    float core = 1.0 - smoothstep(0.0, size * 1.25, length(p - center));
    vec2 crossDir = vec2(-dir.y, dir.x);
    float cross = 1.0 - smoothstep(0.0, size * 0.65, sdSegment(p, center - crossDir * size * 1.6, center + crossDir * size * 1.6));
    return max(max(streak, core), cross * 0.45);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord.xy / iResolution.xy);
    fragColor = base;

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < 0.0 || elapsed > DURATION) return;

    float fadeIn = smoothstep(0.0, FADE_IN, elapsed);
    float fadeOut = 1.0 - smoothstep(DURATION * 0.28, DURATION, elapsed);
    float fade = fadeIn * fadeOut;
    if (fade <= 0.0) return;

    float cellH = max(iCurrentCursor.w, 1.0);
    float cellW = max(iCurrentCursor.z, cellH * CELL_WIDTH_FROM_HEIGHT);
    vec2 cursorCenter = iCurrentCursor.xy + vec2(cellW * 0.5, -cellH * 0.5);
    vec2 previousCenter = iPreviousCursor.xy + vec2(max(iPreviousCursor.z, cellH * CELL_WIDTH_FROM_HEIGHT) * 0.5, -max(iPreviousCursor.w, 1.0) * 0.5);
    vec2 motion = cursorCenter - previousCenter;
    float motionLen = length(motion);
    vec2 motionDir = motionLen > 0.001 ? motion / motionLen : vec2(1.0, 0.0);
    float moveBoost = clamp(motionLen / cellH, 0.0, 3.0);

    vec3 color = base.rgb;
    vec3 sparkColor = vec3(0.0);
    float glow = exp(-distance(fragCoord, cursorCenter) / 21.0) * fade * 0.12;

    float seed = floor(iTimeCursorChange * 101.0);
    for (float i = 0.0; i < PARTICLE_COUNT; i += 1.0) {
        vec2 rnd = hash21(seed + i * 19.37);
        float angle = rnd.x * 6.2831853;
        vec2 randomDir = vec2(cos(angle), sin(angle));
        vec2 dir = normalize(mix(randomDir, motionDir, 0.18 + 0.14 * hash11(seed + i)));
        float speed = mix(0.28, 0.86, rnd.y);
        float drift = elapsed * SPREAD * (0.70 + moveBoost * 0.12) * speed;
        vec2 center = cursorCenter + dir * drift + vec2(-dir.y, dir.x) * (hash11(seed + i + 5.0) - 0.5) * 7.5;

        float age = clamp(elapsed / DURATION, 0.0, 1.0);
        float particleFade = fade * (1.0 - age * (0.34 + 0.50 * rnd.y));
        float shape = spark(fragCoord, center, dir, SPARK_SIZE * (0.72 + rnd.y * 0.55), TRAIL_LENGTH * (0.55 + rnd.y)) * particleFade;
        sparkColor += mix(SPARK_GREEN, SPARK_HEAD, shape) * shape;
    }

    color += SPARK_GREEN * glow;
    color += sparkColor * ADDITIVE_STRENGTH;
    fragColor = vec4(min(color, vec3(1.15)), base.a);
}
