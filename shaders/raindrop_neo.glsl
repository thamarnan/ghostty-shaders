// Neo: cursor-triggered Matrix typing rain for Ghostty.
//
// This shader does not read terminal text. It uses the cursor movement event as
// the trigger, then draws procedural green glyphs in the cursor column and the
// columns behind it.

// ----------------------------- CONFIG --------------------------------------
const float DURATION = 1.45;                // total fade time after a keypress
const float HOLD = 0.10;                    // stay bright briefly before fading
const float FALL_SPEED = 18.0;              // falling head speed in rows/second
const int WAKE_COLUMNS = 10;                // columns trailing behind the cursor
const float BASE_ROWS = 12.0;               // rain height for normal typing
const float MAX_ROWS = 40.0;                // rain height cap for cursor jumps
const float TRAIL_ROWS = 9.0;               // visible rows above each bright head
const float TRAIL_DECAY = 0.28;             // larger = shorter fading tail
const float GLYPH_RATE = 7.0;               // glyph mutation rate
const float CELL_WIDTH_FROM_HEIGHT = 0.50;  // fallback for thin bar cursors
const float GREEN_ALPHA = 0.68;             // glyph opacity
const float SCREEN_DARKEN = 0.12;           // dim terminal under active rain

const vec3 GREEN_BODY = vec3(0.10, 0.85, 0.28);
const vec3 GREEN_HEAD = vec3(0.70, 1.00, 0.76);
const vec3 GREEN_GLOW = vec3(0.20, 1.00, 0.42);

// The browser preview uses a y-up framebuffer; Ghostty uses y-down.
#if defined(WEB)
const float UP = 1.0;
#else
const float UP = -1.0;
#endif
// ---------------------------------------------------------------------------

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float strokeBox(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    float outside = length(max(d, 0.0));
    float inside = min(max(d.x, d.y), 0.0);
    return 1.0 - smoothstep(0.0, 0.035, outside + inside);
}

float glyph(vec2 uv, float id) {
    uv = (uv - 0.5) / 0.84 + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;

    vec2 g = floor(uv * vec2(5.0, 7.0));
    vec2 local = fract(uv * vec2(5.0, 7.0));

    float shape = 0.0;

    float spine = floor(hash11(id + 1.0) * 5.0);
    float top = floor(hash11(id + 2.0) * 3.0);
    float bottom = 4.0 + floor(hash11(id + 3.0) * 3.0);
    if (abs(g.x - spine) < 0.5 && g.y >= top && g.y <= bottom) {
        shape = max(shape, strokeBox(local, vec2(0.5), vec2(0.17, 0.42)));
    }

    float h0 = floor(hash11(id + 4.0) * 7.0);
    float h1 = floor(hash11(id + 5.0) * 7.0);
    float x0 = floor(hash11(id + 6.0) * 3.0);
    float x1 = x0 + 1.0 + floor(hash11(id + 7.0) * 3.0);
    if ((abs(g.y - h0) < 0.5 || abs(g.y - h1) < 0.5) && g.x >= x0 && g.x <= x1) {
        shape = max(shape, strokeBox(local, vec2(0.5), vec2(0.42, 0.16)));
    }

    float diagonal = abs((g.x - hash11(id + 8.0) * 2.0) - (g.y * 0.58 - 1.0));
    if (diagonal < 0.45 && hash11(id + 9.0) > 0.42) {
        shape = max(shape, strokeBox(local, vec2(0.5), vec2(0.18, 0.18)));
    }

    if (hash21(g + id * 13.7) > 0.94) {
        shape = max(shape, strokeBox(local, vec2(0.5), vec2(0.16, 0.16)));
    }

    return shape;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < 0.0 || elapsed > DURATION) return;

    float fade = 1.0 - smoothstep(HOLD, DURATION, elapsed);
    if (fade <= 0.0) return;

    float cellH = max(max(iCurrentCursor.w, iPreviousCursor.w), 1.0);
    float cellW = max(max(iCurrentCursor.z, iPreviousCursor.z), cellH * CELL_WIDTH_FROM_HEIGHT);

    vec2 cursorDelta = iCurrentCursor.xy - iPreviousCursor.xy;
    float movingLeft = step(cursorDelta.x, -0.35 * cellW);

    float relX = (fragCoord.x - iCurrentCursor.x) / cellW;
    float col = floor(relX);
    float behindColumn = mix(-col, col, movingLeft);
    if (behindColumn < 0.0 || behindColumn > float(WAKE_COLUMNS)) return;

    float rowAboveCursor = UP * (fragCoord.y - iCurrentCursor.y) / cellH + 1.0;
    if (rowAboveCursor < 0.0) return;

    float row = floor(rowAboveCursor);
    vec2 cellUv = vec2(fract(relX), fract(rowAboveCursor));

    vec2 jumpCells2D = abs(cursorDelta / vec2(cellW, cellH));
    float jumpRows = max(jumpCells2D.y, length(jumpCells2D) * 0.35);
    float rainRows = clamp(max(BASE_ROWS, jumpRows), 4.0, MAX_ROWS);

    float eventSeed = floor(iTimeCursorChange * 97.0);
    float columnSeed = behindColumn * 17.0 + eventSeed;
    float columnLag = behindColumn * 0.025 + hash11(columnSeed + 2.0) * 0.08;
    float localTime = max(0.0, elapsed - columnLag);

    float columnHeight = rainRows * (0.72 + 0.38 * hash11(columnSeed + 5.0));
    float headRow = columnHeight - localTime * FALL_SPEED;
    float distFromHead = row - headRow;

    if (distFromHead < -0.65 || distFromHead > TRAIL_ROWS) return;

    float head = smoothstep(0.90, 0.0, abs(distFromHead));
    float trail = exp(-max(distFromHead, 0.0) * TRAIL_DECAY);
    float columnFade = 1.0 - clamp(behindColumn / float(WAKE_COLUMNS + 1), 0.0, 1.0);
    float intensity = fade * mix(0.35, 1.0, columnFade) * max(head, trail);

    float glyphPhase = floor(iTime * GLYPH_RATE);
    float glyphId = eventSeed + behindColumn * 41.0 + row * 7.0 + glyphPhase;
    float mask = glyph(cellUv, glyphId);

    vec3 rainColor = mix(GREEN_BODY, GREEN_HEAD, head);
    fragColor.rgb *= 1.0 - SCREEN_DARKEN * intensity;
    fragColor.rgb = mix(fragColor.rgb, rainColor, GREEN_ALPHA * intensity * mask);
    fragColor.rgb += GREEN_GLOW * head * intensity * mask * 0.22;
    fragColor.rgb = min(fragColor.rgb, vec3(1.15));
}
