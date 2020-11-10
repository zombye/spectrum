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

// Gives you a 1 with same sign bit as input
// 2 bitwise ops
float SignExtract(float x) {
	return uintBitsToFloat((floatBitsToUint(x) & 0x80000000u) | floatBitsToUint(1.0));
}
// Copies sign bit from source to destination
// 3 bitwise ops
void SignCopy(float source, inout float destination) {
	destination = uintBitsToFloat((floatBitsToUint(source) & 0x80000000u) | (floatBitsToUint(destination) & 0x7fffffffu));
}

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

vec4 TextureQuadratic(sampler2D sampler, vec2 coord) {
	ivec2 res = textureSize(sampler, 0);
	vec2 m = fract(coord * res);
	vec2 cLo = coord - (0.5 + 0.5 * m) / res;
	vec2 cHi = coord - (      0.5 * m) / res;

	return mix(
		mix(texture2D(sampler, vec2(cLo.x, cLo.y)), texture2D(sampler, vec2(cHi.x, cLo.y)), m.x),
		mix(texture2D(sampler, vec2(cLo.x, cHi.y)), texture2D(sampler, vec2(cHi.x, cHi.y)), m.x),
		m.y
	);
}

/*\
 * returns coords & weights for sampling with cubic filtering
 * use if you need to do so multiple times in the same location (or different locations an integer number of pixels away)
 * or if you need to do some custom stuff to the individual samples
 *
 * coord needs to be in pixels with integers at pixel centers
 * you can convert to this from normal coords with this:
 * coord = coord * resolution - 0.5
 *
 * use cLo, cHi & m like this:
 * mix(mix(texture(sampler, vec2(cLo.x, cLo.y)), texture(sampler, vec2(cHi.x, cLo.y)).x, m.x),
 *     mix(texture(sampler, vec2(cLo.x, cHi.y)), texture(sampler, vec2(cHi.x, cHi.y)).x, m.x),
 *     m.y);
 * cLo & cHi will also be with integers at pixel centers, so you'll probably need to convert it back
\*/
void FastCubicCM(vec2 coord, out vec2 cLo, out vec2 cHi, out vec2 m) {
	vec2 f = fract(coord);
	coord = floor(coord);

	vec2 ff = f * f;

	vec2[4] w;
	w[3] = ff * f;
	w[0] = 1.0 - f; w[0] *= w[0] * w[0];
	w[1] = 3.0 * w[3] + 4.0 - 6.0 * ff;
	w[2] = w[0] + 6.0 * f - 2.0 * w[3];

	vec2 sLo = w[0] + w[1];
	vec2 sHi = w[2] + w[3];
	cLo = coord + w[1] / sLo - 1.0;
	cHi = coord + w[3] / sHi + 1.0;

	m = sHi / 6.0;
}
void FastCubicCM(vec3 coord, out vec3 cLo, out vec3 cHi, out vec3 m) {
	vec3 f = fract(coord);
	coord -= f;

	vec3 ff = f * f;

	vec3[4] w;
	w[3] = ff * f;
	w[0] = 1.0 - f; w[0] *= w[0] * w[0];
	w[1] = 3.0 * w[3] + 4.0 - 6.0 * ff;
	w[2] = w[0] + 6.0 * f - 2.0 * w[3];

	vec3 sLo = w[0] + w[1];
	vec3 sHi = w[2] + w[3];
	cLo = coord + w[1] / sLo - 1.0;
	cHi = coord + w[3] / sHi + 1.0;

	m = sHi / 6.0;
}
// Version of the above for use when computing the Jacobian matrix
void FastCubicCMForJacobian(vec2 coord, out vec2 cLo, out vec2 cHi, out vec2 m) {
	vec2 f = fract(coord);
	coord = floor(coord);

	vec2 ff = f * f;

	vec2[4] w;
	w[3] =  3.0 * ff;
	w[0] = -3.0 * ff +  6.0 * f - 3.0;
	w[1] =  9.0 * ff - 12.0 * f;
	w[2] = -9.0 * ff +  6.0 * f + 3.0;

	vec2 sLo = w[0] + w[1];
	vec2 sHi = w[2] + w[3];
	cLo = coord + w[1] / sLo - 1.0;
	cHi = coord + w[3] / sHi + 1.0;

	m = sHi / 6.0;
}
void FastCubicCMForJacobian(vec3 coord, out vec3 cLo, out vec3 cHi, out vec3 m) {
	vec3 f = fract(coord);
	coord = floor(coord);

	vec3 ff = f * f;

	vec3[4] w;
	w[3] =  3.0 * ff;
	w[0] = -3.0 * ff +  6.0 * f - 3.0;
	w[1] =  9.0 * ff - 12.0 * f;
	w[2] = -9.0 * ff +  6.0 * f + 3.0;

	vec3 sLo = w[0] + w[1];
	vec3 sHi = w[2] + w[3];
	cLo = coord + w[1] / sLo - 1.0;
	cHi = coord + w[3] / sHi + 1.0;

	m = sHi / 6.0;
}

vec4 TextureCubic(sampler2D sampler, vec2 coord) {
	ivec2 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec2 cLo, cHi, m;
	FastCubicCM(coord, cLo, cHi, m);

	cLo = (cLo + 0.5) / res;
	cHi = (cHi + 0.5) / res;

	return mix(
		mix(texture(sampler, vec2(cLo.x, cLo.y)), texture(sampler, vec2(cHi.x, cLo.y)), m.x),
		mix(texture(sampler, vec2(cLo.x, cHi.y)), texture(sampler, vec2(cHi.x, cHi.y)), m.x),
		m.y
	);
}
mat2x4 TextureCubicJacobian(sampler2D sampler, vec2 coord) {
	ivec2 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec2 cLo, cHi, m;
	FastCubicCM(coord, cLo, cHi, m);

	cLo = (cLo + 0.5) / res;
	cHi = (cHi + 0.5) / res;

	vec2 dcLo, dcHi, dm;
	FastCubicCMForJacobian(coord, dcLo, dcHi, dm);

	dcLo = (dcLo + 0.5) / res;
	dcHi = (dcHi + 0.5) / res;

	return mat2x4(res.x * dm.x * mix(
		texture(sampler, vec2(dcHi.x, cLo.y)) - texture(sampler, vec2(dcLo.x, cLo.y)),
		texture(sampler, vec2(dcHi.x, cHi.y)) - texture(sampler, vec2(dcLo.x, cHi.y)),
		m.y
	), res.y * dm.y * mix(
		texture(sampler, vec2(cLo.x, dcHi.y)) - texture(sampler, vec2(cLo.x, dcLo.y)),
		texture(sampler, vec2(cHi.x, dcHi.y)) - texture(sampler, vec2(cHi.x, dcLo.y)),
		m.x
	));
}
vec4 TextureCubicLod(sampler2D sampler, vec2 coord, int lod) {
	ivec2 res = textureSize(sampler, lod);

	coord = coord * res - 0.5;

	vec2 cLo, cHi, m;
	FastCubicCM(coord, cLo, cHi, m);

	cLo = (cLo + 0.5) / res;
	cHi = (cHi + 0.5) / res;

	return mix(
		mix(textureLod(sampler, vec2(cLo.x, cLo.y), lod), textureLod(sampler, vec2(cHi.x, cLo.y), lod), m.x),
		mix(textureLod(sampler, vec2(cLo.x, cHi.y), lod), textureLod(sampler, vec2(cHi.x, cHi.y), lod), m.x),
		m.y
	);
}
vec4 TextureCubicLod(sampler2D sampler, vec2 coord, float lod) {
	return mix(
		TextureCubicLod(sampler, coord, int(floor(lod))),
		TextureCubicLod(sampler, coord, int(ceil (lod))),
		fract(lod)
	);
}

vec4 TextureCubic(sampler3D sampler, vec3 coord) {
	ivec3 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec3 cLo, cHi; vec3 m;
	FastCubicCM(coord, cLo, cHi, m);

	cLo = (cLo + 0.5) / res;
	cHi = (cHi + 0.5) / res;

	return mix(mix(
		mix(texture3D(sampler, vec3(cLo.x, cLo.y, cLo.z)), texture3D(sampler, vec3(cHi.x, cLo.y, cLo.z)), m.x),
		mix(texture3D(sampler, vec3(cLo.x, cHi.y, cLo.z)), texture3D(sampler, vec3(cHi.x, cHi.y, cLo.z)), m.x),
		m.y
	), mix(
		mix(texture3D(sampler, vec3(cLo.x, cLo.y, cHi.z)), texture3D(sampler, vec3(cHi.x, cLo.y, cHi.z)), m.x),
		mix(texture3D(sampler, vec3(cLo.x, cHi.y, cHi.z)), texture3D(sampler, vec3(cHi.x, cHi.y, cHi.z)), m.x),
		m.y
	), m.z);
}
mat3x4 TextureCubicJacobian(sampler3D sampler, vec3 coord) {
	ivec3 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec3 cLo, cHi, m;
	FastCubicCM(coord, cLo, cHi, m);

	cLo = (cLo + 0.5) / res;
	cHi = (cHi + 0.5) / res;

	vec3 dcLo, dcHi, dm;
	FastCubicCMForJacobian(coord, dcLo, dcHi, dm);

	dcLo = (dcLo + 0.5) / res;
	dcHi = (dcHi + 0.5) / res;

	return mat3x4(res.x * dm.x * mix(
		mix(
			texture3D(sampler, vec3(dcHi.x, cLo.y, cLo.z)) - texture3D(sampler, vec3(dcLo.x, cLo.y, cLo.z)),
			texture3D(sampler, vec3(dcHi.x, cHi.y, cLo.z)) - texture3D(sampler, vec3(dcLo.x, cHi.y, cLo.z)),
			m.y
		), mix(
			texture3D(sampler, vec3(dcHi.x, cLo.y, cHi.z)) - texture3D(sampler, vec3(dcLo.x, cLo.y, cHi.z)),
			texture3D(sampler, vec3(dcHi.x, cHi.y, cHi.z)) - texture3D(sampler, vec3(dcLo.x, cHi.y, cHi.z)),
			m.y
		),
		m.z
	), res.y * dm.y * mix(
		mix(
			texture3D(sampler, vec3(cLo.x, dcHi.y, cLo.z)) - texture3D(sampler, vec3(cLo.x, dcLo.y, cLo.z)),
			texture3D(sampler, vec3(cHi.x, dcHi.y, cLo.z)) - texture3D(sampler, vec3(cHi.x, dcLo.y, cLo.z)),
			m.x
		), mix(
			texture3D(sampler, vec3(cLo.x, dcHi.y, cHi.z)) - texture3D(sampler, vec3(cLo.x, dcLo.y, cHi.z)),
			texture3D(sampler, vec3(cHi.x, dcHi.y, cHi.z)) - texture3D(sampler, vec3(cHi.x, dcLo.y, cHi.z)),
			m.x
		),
		m.z
	), res.z * dm.z * mix(
		mix(
			texture3D(sampler, vec3(cLo.x, cLo.y, dcHi.z)) - texture3D(sampler, vec3(cLo.x, cLo.y, dcLo.z)),
			texture3D(sampler, vec3(cHi.x, cLo.y, dcHi.z)) - texture3D(sampler, vec3(cHi.x, cLo.y, dcLo.z)),
			m.x
		), mix(
			texture3D(sampler, vec3(cLo.x, cHi.y, dcHi.z)) - texture3D(sampler, vec3(cLo.x, cHi.y, dcLo.z)),
			texture3D(sampler, vec3(cHi.x, cHi.y, dcHi.z)) - texture3D(sampler, vec3(cHi.x, cHi.y, dcLo.z)),
			m.x
		),
		m.y
	));
}
vec4 TextureCubic(sampler3D sampler, vec3 coord, int lod) {
	ivec3 res = textureSize(sampler, lod);

	coord = coord * res - 0.5;

	vec3 cLo, cHi, m;
	FastCubicCM(coord, cLo, cHi, m);

	cLo = (cLo + 0.5) / res;
	cHi = (cHi + 0.5) / res;

	vec4 s000 = textureLod(sampler, vec3(cLo.x, cLo.y, cLo.z), lod);
	vec4 s100 = textureLod(sampler, vec3(cHi.x, cLo.y, cLo.z), lod);
	vec4 s010 = textureLod(sampler, vec3(cLo.x, cHi.y, cLo.z), lod);
	vec4 s110 = textureLod(sampler, vec3(cHi.x, cHi.y, cLo.z), lod);
	vec4 s001 = textureLod(sampler, vec3(cLo.x, cLo.y, cHi.z), lod);
	vec4 s101 = textureLod(sampler, vec3(cHi.x, cLo.y, cHi.z), lod);
	vec4 s011 = textureLod(sampler, vec3(cLo.x, cHi.y, cHi.z), lod);
	vec4 s111 = textureLod(sampler, vec3(cHi.x, cHi.y, cHi.z), lod);

	return mix(mix(
		mix(s000, s100, m.x),
		mix(s010, s110, m.x),
		m.y
	), mix(
		mix(s001, s101, m.x),
		mix(s011, s111, m.x),
		m.y
	), m.z);
}

#endif
