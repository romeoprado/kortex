#version 440
// Troca do papel de parede (modules/wallpaper/Wallpaper.qml). Só é desenhado enquanto a troca
// acontece; fora dela o papel de parede é uma Image comum. `mode` escolhe o efeito:
//   0 círculo    um círculo de borda suave cresce do centro
//   1 íris       a íris abre com a borda brilhando no acento, e a imagem nova assenta de um leve zoom
//   2 tinta      a imagem nova escorre por bordas de ruído, escurecendo a antiga à frente
//   3 ladrilhos  quadrados viram numa onda diagonal, com a borda no acento enquanto viram
//   4 varredura  uma linha brilhante desce a tela, deixando a imagem nova para trás
//   5 falha      blocos da imagem nova entram em momentos ao acaso, rasgados e com as cores separadas
// Recompile depois de mudar (Qt 6):
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
//       -o wallpaper_transition.frag.qsb wallpaper_transition.frag
// Adaptado de shaders/wallpaper_transition.frag do dhrruvsharma/shell (GPLv3), modos grow, warp,
// ink, tiles, scan e glitch.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;    // 0..1
    float mode;
    float aspect;      // largura / altura
    vec4 edgeColor;    // acento opaco, para bordas e linhas
} ubuf;

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    int mode = int(ubuf.mode + 0.5);
    vec2 c = (uv - 0.5) * vec2(ubuf.aspect, 1.0);
    float maxR = 0.5 * sqrt(ubuf.aspect * ubuf.aspect + 1.0);

    vec2 toUv = uv;
    if (mode == 1)
        toUv = (uv - 0.5) * (1.0 - 0.12 * (1.0 - p)) + 0.5;

    vec4 a = texture(fromTex, uv);
    vec4 b = texture(toTex, toUv);
    vec3 edge = vec3(0.0);
    float m;

    if (mode == 1) {
        float r = p * maxR * 1.05;
        float d = length(c);
        m = smoothstep(r, r - 0.03, d);
        edge = ubuf.edgeColor.rgb * exp(-abs(d - r) * 40.0) * step(p, 0.999) * 0.9;
    } else if (mode == 2) {
        float n = fbm(uv * vec2(3.0 * ubuf.aspect, 3.0));
        float front = p * 1.3 - 0.15;
        m = smoothstep(n - 0.06, n + 0.02, front);
        float band = smoothstep(n - 0.14, n - 0.04, front) * (1.0 - m);
        a.rgb *= 1.0 - band * 0.85;
    } else if (mode == 3) {
        vec2 grid = vec2(18.0 * ubuf.aspect / 1.6, 18.0);
        vec2 cell = floor(uv * grid);
        float delay = (cell.x / grid.x + cell.y / grid.y) * 0.5;
        float t = clamp((p * 1.6 - delay * 0.6 - hash(cell) * 0.1) / 0.45, 0.0, 1.0);
        vec2 f = abs(fract(uv * grid) - 0.5);
        float inside = step(max(f.x, f.y), t * 0.5);
        m = inside;
        float rim = inside * (1.0 - step(max(f.x, f.y), t * 0.5 - 0.06)) * step(t, 0.999);
        edge = ubuf.edgeColor.rgb * rim * 0.8;
    } else if (mode == 4) {
        float line = p * 1.08 - 0.04;
        m = step(uv.y, line);
        float glow = exp(-abs(uv.y - line) * 90.0) * step(p, 0.999);
        edge = ubuf.edgeColor.rgb * glow * 0.9;
    } else if (mode == 5) {
        vec2 block = vec2(floor(uv.x * 7.0), floor(uv.y * 28.0));
        float at = 0.06 + 0.78 * hash(block * vec2(0.37, 1.0));
        float spike = exp(-abs(p - at) * 22.0) * step(p, 0.999);
        float tear = (hash(vec2(block.y, 7.0)) - 0.5) * 0.14 * spike;
        vec2 suv = vec2(fract(uv.x + tear), uv.y);
        float split = 0.014 * spike;
        a = texture(fromTex, suv);
        b = texture(toTex, suv);
        b.r = texture(toTex, vec2(fract(suv.x + split), suv.y)).r;
        b.b = texture(toTex, vec2(fract(suv.x - split), suv.y)).b;
        m = step(at, p);
        edge = ubuf.edgeColor.rgb * spike * 0.3 * step(0.55, hash(block + 3.0));
    } else {
        float r = p * maxR * 1.05;
        m = smoothstep(r, r - 0.04, length(c));
    }

    vec3 col = mix(a.rgb, b.rgb, m) + edge;
    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
