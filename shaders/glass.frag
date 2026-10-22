#version 440
// LovelyRice glass: a rounded rectangle that shows the wallpaper behind it blurred, bent at the rim and lit from the top left.
// Build (needs qsb from qt6-shadertools):   lovelyrice shaders        (or:  qsb --qt6 -o glass.frag.qsb glass.frag)
//
// Everything is measured in logical screen pixels. `source` is the wallpaper for the whole screen (with mipmaps);
// `origin` is where this surface's top-left corner is on the screen, so each surface looks up the part behind itself.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // this surface, px
    vec2 origin;        // its top-left corner on the screen, px
    vec2 screenSize;    // the screen, px
    float radius;       // corner radius, px
    float bevel;        // how wide the bent rim is, px
    float refraction;   // how far the rim pulls in what is outside it, px
    float blurLod;      // mip level used for the blur (0 = sharp)
    vec4 tint;          // rgb = tint color, a = how much of it
    float light;        // 0..1 rim highlight
    float fringe;       // 0 or 1: color fringing at the rim
    float saturation;   // 1 = unchanged
} ubuf;

layout(binding = 1) uniform sampler2D source;

// signed distance to a rounded rectangle centered on the origin: negative inside, in px
float sdRoundRect(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// the wallpaper at a screen position, blurred: five taps spread over the mip level so the blur is smooth, not blocky
vec3 backdrop(vec2 screenPx, float lod) {
    vec2 px = 1.0 / ubuf.screenSize;
    float k = (exp2(lod) * 0.9);                       // in screen px
    vec2 uv = screenPx * px;
    vec3 c = textureLod(source, clamp(uv, vec2(0.001), vec2(0.999)), lod).rgb * 0.36;
    c += textureLod(source, clamp(uv + vec2( k,  k) * px, vec2(0.001), vec2(0.999)), lod).rgb * 0.16;
    c += textureLod(source, clamp(uv + vec2(-k,  k) * px, vec2(0.001), vec2(0.999)), lod).rgb * 0.16;
    c += textureLod(source, clamp(uv + vec2( k, -k) * px, vec2(0.001), vec2(0.999)), lod).rgb * 0.16;
    c += textureLod(source, clamp(uv + vec2(-k, -k) * px, vec2(0.001), vec2(0.999)), lod).rgb * 0.16;
    return c;
}

void main() {
    vec2 halfSize = 0.5 * ubuf.size;
    vec2 p = qt_TexCoord0 * ubuf.size - halfSize;            // from the center, px
    float r = min(ubuf.radius, min(halfSize.x, halfSize.y));
    float d = sdRoundRect(p, halfSize, r);                    // < 0 inside
    float coverage = clamp(0.5 - d, 0.0, 1.0);                // anti-aliased edge
    if (coverage <= 0.0) { fragColor = vec4(0.0); return; }

    // outward normal of the shape (from the gradient of the distance)
    vec2 e = vec2(1.0, 0.0);
    vec2 g = vec2(sdRoundRect(p + e.xy, halfSize, r) - sdRoundRect(p - e.xy, halfSize, r),
                  sdRoundRect(p + e.yx, halfSize, r) - sdRoundRect(p - e.yx, halfSize, r));
    float gl = length(g);
    vec2 n = gl > 1e-4 ? g / gl : vec2(0.0);

    float depth = max(-d, 0.0);                               // px inside the edge
    float t = clamp(depth / max(ubuf.bevel, 1.0), 0.0, 1.0);  // 0 at the rim, 1 once past the bevel
    float rim = (1.0 - t) * (1.0 - t);                        // strongest bending right at the rim

    // a convex lens pulls in what is just outside it: near the rim, look further out along the normal
    vec2 here = ubuf.origin + qt_TexCoord0 * ubuf.size;
    float bend = ubuf.refraction * rim;
    float spread = ubuf.fringe * 0.22;
    float lod = ubuf.blurLod * mix(0.55, 1.0, t);             // the rim stays a little sharper, so the bending is visible
    vec3 col;
    col.r = backdrop(here + n * bend * (1.0 + spread), lod).r;
    col.g = backdrop(here + n * bend, lod).g;
    col.b = backdrop(here + n * bend * (1.0 - spread), lod).b;

    // grade: a little more color, then the theme tint
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, ubuf.saturation);
    col = mix(col, ubuf.tint.rgb, ubuf.tint.a);

    // light from the top left: a bright rim on the edges that face it, a faint one on the far side, and a hairline all round
    vec2 L = normalize(vec2(-0.55, -0.83));
    float facing = dot(n, L);
    float edge = 1.0 - smoothstep(0.0, max(ubuf.bevel * 0.55, 2.0), depth);
    float spec = edge * (pow(max(facing, 0.0), 1.4) * 0.95 + pow(max(-facing, 0.0), 2.0) * 0.28);
    float hair = 1.0 - smoothstep(0.0, 1.6, depth);
    col += vec3(1.0) * ubuf.light * (spec * 0.55 + hair * 0.22);
    // a soft glow just inside the top edge, like light caught in the glass
    col += vec3(1.0) * ubuf.light * 0.05 * smoothstep(0.0, 1.0, max(-n.y, 0.0)) * (1.0 - t);

    fragColor = vec4(clamp(col, 0.0, 1.0) * coverage, coverage) * ubuf.qt_Opacity;
}
