#if !defined INCLUDE_UTILITY
#define INCLUDE_UTILITY

// Common constants
const float tau         = radians(360.0);
const float pi          = radians(180.0);
const float hpi         = radians( 90.0);
const float phi         = sqrt(5.0) * 0.5 + 0.5;
const float goldenAngle = tau / (phi + 1.0);
const float ln2         = log(2.0);

const mat2 rotateGoldenAngle = mat2(cos(goldenAngle), -sin(goldenAngle), sin(goldenAngle), cos(goldenAngle));

//--// Helpers (mainly exist to give cleaner and/or clearer code)

// Clamps each component of x between 0 and 1. Generally free on instruction output.
#define Clamp01(x) clamp(x, 0.0, 1.0)

// Clamps each component of x to above or equal to 0
#define Max0(x) max(x, 0)

// Clamps each component of x to below or equal to 1
#define Min1(x) min(x, 1)

// Swaps two variables of the same type
void Swap(inout float x, inout float y) { float temp = x; x = y; y = temp; }
void Swap(inout vec2  x, inout vec2  y) { vec2  temp = x; x = y; y = temp; }
void Swap(inout vec3  x, inout vec3  y) { vec3  temp = x; x = y; y = temp; }
void Swap(inout vec4  x, inout vec4  y) { vec4  temp = x; x = y; y = temp; }

// Min and max component of a vector
float MaxOf(vec2 x) { return max(x.x, x.y); }
float MaxOf(vec3 x) { return max(max(x.x, x.y), x.z); }
float MaxOf(vec4 x) { return max(max(x.x, x.y), max(x.z, x.w)); }
float MinOf(vec2 x) { return min(x.x, x.y); }
float MinOf(vec3 x) { return min(min(x.x, x.y), x.z); }
float MinOf(vec4 x) { return min(min(x.x, x.y), min(x.z, x.w)); }

// Sum of the components of a vector
float SumOf(vec2 x) { return x.x + x.y; }
float SumOf(vec3 x) { return x.x + x.y + x.z; }
float SumOf(vec4 x) { x.xy += x.zw; return x.x + x.y; }

// Matrix diagonal
vec2 Diagonal(mat2 m) { return vec2(m[0].x, m[1].y); }
vec3 Diagonal(mat3 m) { return vec3(m[0].x, m[1].y, m[2].z); }
vec4 Diagonal(mat4 m) { return vec4(m[0].x, m[1].y, m[2].z, m[3].w); }

// Sine & cosine of x in a vec2
vec2 SinCos(float x) { return vec2(sin(x), cos(x)); }

// Solid angle and cone angle conversion
#define ConeAngleToSolidAngle(x) (tau * (1.0 - cos(x)))
#define SolidAngleToConeAngle(x) acos(1.0 - (x) / tau)

//--// Uncategorized stuff

float AddUvMargin(float uv, int   resolution) { return uv * (1.0 - 1.0 / resolution) + (0.5 / resolution); }
vec2  AddUvMargin(vec2 uv,  ivec2 resolution) { return uv * (1.0 - 1.0 / resolution) + (0.5 / resolution); }
vec3  AddUvMargin(vec3 uv,  ivec3 resolution) { return uv * (1.0 - 1.0 / resolution) + (0.5 / resolution); }
vec4  AddUvMargin(vec4 uv,  ivec4 resolution) { return uv * (1.0 - 1.0 / resolution) + (0.5 / resolution); }
float RemoveUvMargin(float uv, int   resolution) { return (uv - 0.5 / resolution) / (1.0 - 1.0 / resolution); }
vec2  RemoveUvMargin(vec2 uv,  ivec2 resolution) { return (uv - 0.5 / resolution) / (1.0 - 1.0 / resolution); }
vec3  RemoveUvMargin(vec3 uv,  ivec3 resolution) { return (uv - 0.5 / resolution) / (1.0 - 1.0 / resolution); }
vec4  RemoveUvMargin(vec4 uv,  ivec4 resolution) { return (uv - 0.5 / resolution) / (1.0 - 1.0 / resolution); }

// A sort of smooth minimum.
// value is n when x == 0, x when x >= m.
// slope is 0 when x == 0, 1 when x >= m.
float AlmostIdentity(float x, float m, float n) {
	if (x >= m) { return x; }
	x /= m;
	return ((2.0 * n - m) * x + (2.0 * m - 3.0 * n)) * x * x + n;
}

vec2 CircleMap(float index, float count) {
	// follows fermat's spiral with a divergence angle equal to the golden angle
	return SinCos(index * goldenAngle) * sqrt(index / count);
}

// Similar to smoothstep, but using linear interpolation instead of Hermite interpolation.
float LinearStep(float e0, float e1, float x) { return Clamp01((x - e0) / (e1 - e0)); }
vec2  LinearStep(vec2  e0, vec2  e1, vec2  x) { return Clamp01((x - e0) / (e1 - e0)); }
vec3  LinearStep(vec3  e0, vec3  e1, vec3  x) { return Clamp01((x - e0) / (e1 - e0)); }
vec4  LinearStep(vec4  e0, vec4  e1, vec4  x) { return Clamp01((x - e0) / (e1 - e0)); }
vec2  LinearStep(vec2  e0, vec2  e1, float x) { return Clamp01((x - e0) / (e1 - e0)); }
vec3  LinearStep(vec3  e0, vec3  e1, float x) { return Clamp01((x - e0) / (e1 - e0)); }
vec4  LinearStep(vec4  e0, vec4  e1, float x) { return Clamp01((x - e0) / (e1 - e0)); }
vec2  LinearStep(float e0, float e1, vec2  x) { return Clamp01((x - e0) / (e1 - e0)); }
vec3  LinearStep(float e0, float e1, vec3  x) { return Clamp01((x - e0) / (e1 - e0)); }
vec4  LinearStep(float e0, float e1, vec4  x) { return Clamp01((x - e0) / (e1 - e0)); }

// No intersection if returned y component is < 0.0
vec2 RaySphereIntersection(vec3 position, vec3 direction, float radius) {
	float PoD = dot(position, direction);
	float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
	      delta = sqrt(delta);

	return -PoD + vec2(-delta, delta);
}

// Calculates light interference caused by reflections on and inside of a (very) thin film.
// Can technically be used at larger scales, but interference is practically non-existent in these cases.
vec3 ThinFilmInterference(float filmThickness, float filmRefractiveIndex, float theta2) {
	const vec3 wavelengths = vec3(612.5, 549.0, 451.0); // should probably be an input

	float opd = 2.0 * filmRefractiveIndex * filmThickness * cos(theta2);

	return 2.0 * abs(cos(opd * pi / wavelengths));
}

/*\
 * returns coords & weights for sampling with bicubic filtering
 * use if you need to do so multiple times in the same location (or different locations an integer number of pixels away)
 * or if you need to do some custom stuff to the individual samples
 *
 * coord needs to be in pixels with integers at pixel centers
 * you can convert to this from normal coords with this:
 * coord = coord * resolution - 0.5
 *
 * use c & m like this:
 * mix(mix(texture(sampler, c.xy), texture(sampler, c.zy).x, m.x),
 *     mix(texture(sampler, c.xw), texture(sampler, c.zw).x, m.x),
 *     m.y);
 * remember that c will also be with integers at pixel centers
 * you can convert this to normal coords like this:
 * c = (c + 0.5) / resolution.xyxy
\*/
void FastBicubicCM(vec2 coord, out vec4 c, out vec2 m) {
	vec2 f = fract(coord);
	coord -= f;

	vec2 ff = f * f;

	vec2 w0 = ff * f;
	vec2 w3 = 1.0 - f; w3 *= w3 * w3;
	vec2 w1 = w3 + 6.0 * f - 2.0 * w0;
	vec2 w2 = 3.0 * w0 + 4.0 - 6.0 * ff;

	vec4 s = vec4(w3, w1) + vec4(w2, w0);
	c = coord.xyxy + vec4(w2, w0) / s;
	c.xy -= 1.0; c.zw += 1.0;

	m = s.zw / (s.xy + s.zw);
}
vec4 TextureBicubic(sampler2D sampler, vec2 coord) {
	ivec2 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec4 c; vec2 m;
	FastBicubicCM(coord, c, m);

	c = (c + 0.5) / res.xyxy;

	return mix(
		mix(texture(sampler, c.xy), texture(sampler, c.zy), m.x),
		mix(texture(sampler, c.xw), texture(sampler, c.zw), m.x),
		m.y
	);
}

#endif
