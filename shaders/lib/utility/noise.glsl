#if !defined INCLUDE_UTILITY_NOISE
#define INCLUDE_UTILITY_NOISE

uint Hash(uint x) {
	// Source: https://stackoverflow.com/a/17479300
	x += x << 10u;
	x ^= x >>  6u;
	x += x <<  3u;
	x ^= x >> 11u;
	x += x << 15u;
	return x;
}

// The following are originally by Dave Hoskins (https://www.shadertoy.com/view/4djSRW, license: https://creativecommons.org/licenses/by-sa/4.0/)
//*
#define HASHSCALE1 443.8975
#define HASHSCALE3 vec3(443.897, 441.423, 437.195)
#define HASHSCALE4 vec4(443.897, 441.423, 437.195, 444.129)
//*/
/*
#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)
#define HASHSCALE4 vec4(.1031, .1030, .0973, .1099)
//*/

float Hash1(float p) {
	vec3 p3 = fract(vec3(p) * HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
float Hash1(vec2 p) {
	vec3 p3 = fract(p.xyx * HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}
float Hash1(vec3 p3) {
	p3  = fract(p3 * HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 Hash2(float p) {
	vec3 p3 = fract(vec3(p) * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xx + p3.yz) * p3.zy);
}
vec2 Hash2(vec2 p) {
	vec3 p3 = fract(p.xyx * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xx + p3.yz) * p3.zy);
}
vec2 Hash2(vec3 p3) {
	p3 = fract(p3 * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 Hash3(float p) {
	vec3 p3 = fract(vec3(p) * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}
vec3 Hash3(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
	p3 += dot(p3, p3.yxz + 19.19);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}
vec3 Hash3(vec3 p3) {
	p3 = fract(p3 * HASHSCALE3);
	p3 += dot(p3, p3.yxz + 19.19);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

vec4 Hash4(float p) {
	vec4 p4 = fract(vec4(p) * HASHSCALE4);
	p4 += dot(p4, p4.wzxy + 19.19);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
vec4 Hash4(vec2 p) {
	vec4 p4 = fract(p.xyxy * HASHSCALE4);
	p4 += dot(p4, p4.wzxy + 19.19);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
vec4 Hash4(vec3 p) {
	vec4 p4 = fract(p.xyzx  * HASHSCALE4);
	p4 += dot(p4, p4.wzxy + 19.19);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
vec4 Hash4(vec4 p4) {
	p4  = fract(p4  * HASHSCALE4);
	p4 += dot(p4, p4.wzxy + 19.19);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

#undef HASHSCALE1
#undef HASHSCALE3
#undef HASHSCALE4

//----------------------------------------------------------------------------//

float CellNoise1(vec2 position) {
	// Might be worth looking into making a hexagonal grid.
	// Would in theory be more efficient (7 cells to calculate vs 9). - Zombye

	ivec2 i = ivec2(floor(position));
	vec2  f = fract(position);

	float dist = sqrt(2.5); // max possible
	for (int x = -1; x <= 1; ++x) {
		for (int y = -1; y <= 1; ++y) {
			vec2 cell = Hash2(i + vec2(x, y)) + vec2(x, y);

			dist = min(dist, distance(cell, f));
		}
	}

	return dist;
}

#endif
