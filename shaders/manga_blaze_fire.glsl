// By Komsit37 (https://github.com/komsit37)
// Fire blaze variant: blue-to-orange flame glow, only on larger cursor jumps.

float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b)
{
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec2 norm(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialising(float distance) {
    return 1. - smoothstep(0., norm(vec2(2., 2.), 0.).x, distance);
}

vec2 getRectangleCenter(vec4 rectangle) {
    return vec2(rectangle.x + (rectangle.z / 2.), rectangle.y - (rectangle.w / 2.));
}

float ease(float x) {
    return 1.0 - pow(1.0 - x, 3.0);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float blazeSlash(vec2 p, vec2 start, vec2 end, float time, float seed) {
    float totalLength = distance(start, end);
    if (totalLength < 0.001) return 0.0;

    vec2 direction = (end - start) / totalLength;
    vec2 perpendicular = vec2(-direction.y, direction.x);

    vec2 localP = p - start;
    float alongPath = dot(localP, direction);
    float acrossPath = dot(localP, perpendicular);
    float t = clamp(alongPath / totalLength, 0.0, 1.0);

    float jagged = (noise(vec2(t * 18.0 + seed, time * 8.0)) - 0.5) * 0.018;
    float waveOffset = sin(t * 14.0 + time * 8.0 + seed) * 0.01 + jagged;
    float mainSlash = 1.0 / (abs(acrossPath - waveOffset) * 190.0 + 0.004);

    float flameLines = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float offset = (fi - 1.5) * 0.012;
        float wavePhase = sin(t * 10.0 + time * 6.0 + fi + seed) * 0.008;
        float emberBreak = noise(vec2(t * 24.0 + fi * 13.0, seed + time * 4.0));
        float lineIntensity = 0.35 / (abs(acrossPath - offset - wavePhase) * 155.0 + 0.008);
        float taper = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.75, 1.0, t));
        flameLines += lineIntensity * taper * (0.6 + emberBreak * 0.6);
    }

    return mainSlash + flameLines;
}

float emberBurst(vec2 p, vec2 center, float time, float intensity) {
    float dist = distance(p, center);
    float ember = sin(dist * 130.0 - time * 16.0) * exp(-dist * 42.0);
    return max(0.0, ember * intensity);
}

const vec3 FLAME_BLUE = vec3(0.01, 0.12, 1.0);
const vec3 FLAME_CYAN = vec3(0.10, 0.62, 1.0);
const vec3 FLAME_VIOLET = vec3(0.36, 0.18, 1.0);
const vec3 FLAME_ORANGE = vec3(1.0, 0.24, 0.0);
const vec3 FLAME_GOLD = vec3(1.0, 0.78, 0.12);
const vec3 FLAME_WHITE = vec3(1.0, 0.96, 0.68);
const float DURATION = 0.32;
const float MIN_JUMP_CELLS = 3.0;
const float MIN_VERTICAL_JUMP_CELLS = 2.0;
const float CELL_WIDTH_FROM_HEIGHT = 0.48;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);

    vec2 vu = norm(fragCoord, 1.);

    vec4 currentCursor = vec4(norm(iCurrentCursor.xy, 1.), norm(iCurrentCursor.zw, 0.));
    vec4 previousCursor = vec4(norm(iPreviousCursor.xy, 1.), norm(iPreviousCursor.zw, 0.));

    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float easedProgress = ease(progress);

    vec2 centerCC = getRectangleCenter(currentCursor);
    vec2 centerCP = getRectangleCenter(previousCursor);

    float cellW = max(max(iCurrentCursor.z, iPreviousCursor.z), max(iCurrentCursor.w, iPreviousCursor.w) * CELL_WIDTH_FROM_HEIGHT);
    float cellH = max(iCurrentCursor.w, iPreviousCursor.w);
    vec2 safeCellSize = max(vec2(cellW, cellH), vec2(1.0));
    vec2 jumpCells2D = abs((iCurrentCursor.xy - iPreviousCursor.xy) / safeCellSize);
    float jumpCells = length(jumpCells2D);
    float jumpColumns = jumpCells2D.x;
    float jumpRows = jumpCells2D.y;
    bool largeSameRowJump = jumpRows < 0.5 && jumpColumns >= MIN_JUMP_CELLS;
    bool largeVerticalJump = jumpRows >= MIN_VERTICAL_JUMP_CELLS;

    vec4 newColor = vec4(fragColor);

    if ((largeSameRowJump || largeVerticalJump) && progress < 1.0) {
        float seed = iTimeCursorChange;
        float jumpBoost = clamp((jumpCells - MIN_JUMP_CELLS) / 8.0, 0.0, 1.0);

        float slash = blazeSlash(vu, centerCP, centerCC, iTime, seed);
        float ember = emberBurst(vu, centerCC, iTime, 1.0 - progress);

        slash *= (1.0 - easedProgress) * (0.75 + jumpBoost * 0.65);

        float outerIntensity = clamp(slash * 0.28, 0.0, 1.0);
        float blueIntensity = clamp((slash - 0.03) * 0.36, 0.0, 1.0);
        float cyanIntensity = clamp((slash - 0.12) * 0.28, 0.0, 1.0);
        float violetIntensity = clamp((slash - 0.22) * 0.24, 0.0, 1.0);
        float orangeIntensity = clamp((slash - 0.36) * 0.50, 0.0, 1.0);
        float goldIntensity = clamp((slash - 0.54) * 0.62, 0.0, 1.0);
        float hotCore = clamp((slash - 0.85) * 0.75, 0.0, 1.0);

        newColor = mix(newColor, vec4(FLAME_BLUE, 0.70), outerIntensity * 0.62);
        newColor = mix(newColor, vec4(FLAME_CYAN, 0.68), blueIntensity * 0.42);
        newColor = mix(newColor, vec4(FLAME_VIOLET, 0.58), cyanIntensity * 0.22 + violetIntensity * 0.16);
        newColor = mix(newColor, vec4(FLAME_ORANGE, 0.86), orangeIntensity * 0.82);
        newColor = mix(newColor, vec4(FLAME_GOLD, 0.92), goldIntensity * 0.90);
        newColor = mix(newColor, vec4(FLAME_WHITE, 0.92), hotCore * 0.75);

        float emberIntensity = clamp(ember * 0.25, 0.0, 1.0);
        newColor = mix(newColor, vec4(FLAME_CYAN, 0.42), emberIntensity * 0.25);
        newColor = mix(newColor, vec4(FLAME_ORANGE, 0.62), emberIntensity * 0.75);
        newColor = mix(newColor, vec4(FLAME_GOLD, 0.70), emberIntensity * 0.80);
    }

    fragColor = newColor;
}
