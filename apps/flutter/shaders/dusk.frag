#version 460 core

#include <flutter/runtime_effect.glsl>

// Cielo de crepúsculo: índigo arriba, ciruela en medio y un resto de ocaso
// que se desplaza despacio sobre el horizonte. El grano evita las bandas.

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uPointer;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / max(uSize.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * 0.035;

  vec3 deep = vec3(0.067, 0.051, 0.125);
  vec3 night = vec3(0.110, 0.086, 0.192);
  vec3 plum = vec3(0.243, 0.141, 0.278);
  vec3 dusk = vec3(0.784, 0.471, 0.416);
  vec3 lamp = vec3(0.957, 0.749, 0.447);

  // Nubes lentas que deforman la línea del ocaso.
  vec2 q = vec2(fbm(p * 1.4 + vec2(t, -t * 0.4)), fbm(p * 1.4 + vec2(-t * 0.6, t)));
  float clouds = fbm(p * 2.2 + q * 1.6 + vec2(t * 0.8, 0.0));

  float horizon = 0.78 + (q.x - 0.5) * 0.18;
  float band = smoothstep(horizon - 0.55, horizon + 0.12, uv.y);

  vec3 col = mix(deep, night, smoothstep(0.0, 0.45, uv.y));
  col = mix(col, plum, band * 0.85);
  col = mix(col, dusk, pow(band, 3.4) * (0.22 + clouds * 0.3));
  col += lamp * pow(band, 7.0) * 0.12 * clouds;

  // Un halo que sigue al dedo o al ratón, como una farola que se acerca.
  vec2 d = (uv - uPointer) * vec2(aspect, 1.0);
  col += lamp * 0.05 * exp(-dot(d, d) * 7.0);

  // Estrellas lejanas, casi quietas, solo en la parte oscura.
  vec2 grid = floor(frag / 3.0);
  float star = step(0.9985, hash(grid));
  float twinkle = 0.55 + 0.45 * sin(uTime * 1.3 + hash(grid + 3.1) * 40.0);
  col += vec3(0.95, 0.92, 0.86) * star * twinkle * (1.0 - band) * 0.55;

  col += (hash(frag + fract(uTime)) - 0.5) * 0.028;
  float vignette = smoothstep(1.25, 0.35, length((uv - vec2(0.5, 0.55)) * vec2(aspect * 0.8, 1.0)));
  col *= mix(0.72, 1.0, vignette);

  fragColor = vec4(col, 1.0);
}
