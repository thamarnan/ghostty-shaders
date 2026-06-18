// CRT Cursor: restrained green cursor block blink with a soft glow.

// ----------------------------- CONFIG --------------------------------------
const float BLINK_SPEED = 8.0;
const float CHANGE_FLASH_DURATION = 0.26;
const float CELL_WIDTH_FROM_HEIGHT = 0.50;
const float BLOCK_ALPHA = 0.24;
const float FLASH_ALPHA = 0.16;
const float GLOW_RADIUS = 14.0;
const float GLOW_STRENGTH = 0.15;

const vec3 BLOCK_GREEN = vec3(0.12, 0.95, 0.34);
const vec3 HOT_GREEN = vec3(0.72, 1.00, 0.78);
// ---------------------------------------------------------------------------

float sdRect(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord.xy / iResolution.xy);
    fragColor = base;

    float cellH = max(iCurrentCursor.w, 1.0);
    float cellW = max(iCurrentCursor.z, cellH * CELL_WIDTH_FROM_HEIGHT);
    vec2 blockCenter = iCurrentCursor.xy + vec2(cellW * 0.5, -cellH * 0.5);
    vec2 blockHalf = vec2(cellW, cellH) * 0.5;

    float sdf = sdRect(fragCoord, blockCenter, blockHalf);
    float inside = 1.0 - smoothstep(-1.0, 1.2, sdf);
    float edge = 1.0 - smoothstep(0.0, 2.5, abs(sdf));
    float glow = exp(-max(sdf, 0.0) / GLOW_RADIUS);

    float elapsed = iTime - iTimeCursorChange;
    float changeFlash = 1.0 - smoothstep(0.0, CHANGE_FLASH_DURATION, elapsed);
    float blink = 0.5 + 0.5 * sin(iTime * BLINK_SPEED);
    float pulse = 0.55 + 0.45 * blink;

    vec3 blockColor = mix(BLOCK_GREEN, HOT_GREEN, changeFlash * 0.35 + edge * 0.12);
    float fillAlpha = inside * (BLOCK_ALPHA * pulse + FLASH_ALPHA * changeFlash);
    float glowAlpha = glow * GLOW_STRENGTH * (0.45 + 0.45 * pulse + changeFlash * 0.35);

    vec3 color = mix(base.rgb, blockColor, clamp(fillAlpha, 0.0, 0.46));
    color += BLOCK_GREEN * glowAlpha;
    color += HOT_GREEN * edge * 0.045 * pulse;

    fragColor = vec4(min(color, vec3(1.15)), base.a);
}
