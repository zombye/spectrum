float pow2(float x) { return x * x; }
vec2  pow2(vec2  x) { return x * x; }
vec3  pow2(vec3  x) { return x * x; }
float pow3(float x) { return x * x * x; }
float pow4(float x) { x *= x; return x * x; }
float pow5(float x) { float x2 = x * x; return x2 * x2 * x; }
vec2  pow5(vec2 x)  { vec2  x2 = x * x; return x2 * x2 * x; }
