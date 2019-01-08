#if !defined INCLUDE_UTILITY_NOISE
#define INCLUDE_UTILITY_NOISE

//--// Texture noise //-------------------------------------------------------//

float GetNoise(sampler2D noiseSampler, vec2 position) {
	return texture(noiseSampler, 0.015625 * position.xy).x;
}
float GetNoise(sampler2D noiseSampler, vec3 position) {
	float flr = floor(position.z);

	vec2 coord = (position.xy * 0.015625) + (flr * 0.265625); // 1/64 | 17/64
	vec2 noise = texture(noiseSampler, coord).xy;

	return mix(noise.x, noise.y, position.z - flr);
}

float GetNoiseSmooth(sampler2D noiseSampler, vec2 position) {
	vec2 flr  = floor(position);
	vec2 frc  = position - flr;
	     frc *= frc * (3.0 - 2.0 * frc);

	vec2 coord = (flr.xy + frc.xy) * 0.015625; // 1/64
	return texture(noiseSampler, coord).x;
}
float GetNoiseSmooth(sampler2D noiseSampler, vec3 position) {
	vec3 flr  = floor(position);
	vec3 frc  = position - flr;
	     frc *= frc * (3.0 - 2.0 * frc);

	vec2 coord = ((flr.xy + frc.xy) * 0.015625) + (flr.z * 0.265625); // 1/64 | 17/64
	vec2 noise = texture(noiseSampler, coord).xy;

	return mix(noise.x, noise.y, frc.z);
}

// Using defines so noisetex isn't a required uniform
#define GetNoise(pos) GetNoise(noisetex, pos)
#define GetNoiseSmooth(pos) GetNoiseSmooth(noisetex, pos)

//----------------------------------------------------------------------------//

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

float ValueNoise1(float c, uint seed) {
	float cf = fract(c);
	uint c0 = uint(c - cf);
	uint c1 = c0 + 1u;

	uint hashedSeed = Hash(seed);

	return mix(
		float(Hash(c0 ^ hashedSeed)) * exp2(-32.0), // * 2.3283064365386962890625e-10,
		float(Hash(c1 ^ hashedSeed)) * exp2(-32.0),
		cf * cf * (3.0 - 2.0 * cf)
	);
}

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

float CellNoise1(vec3 position) {
	ivec3 i = ivec3(floor(position));
	vec3  f = fract(position);

	float dist = sqrt(1*1+1*1+1*1); // max possible?
	for (int x = -1; x <= 1; ++x) {
		for (int y = -1; y <= 1; ++y) {
			for (int z = -1; z <= 1; ++z) {
				vec3 cell = Hash3(i + vec3(x, y, z)) + vec3(x, y, z);

				dist = min(dist, distance(cell, f));
			}
		}
	}

	return dist;
}

#endif
