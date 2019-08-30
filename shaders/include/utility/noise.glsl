#if !defined INCLUDE_UTILITY_NOISE
#define INCLUDE_UTILITY_NOISE

//--// Texture noise //-------------------------------------------------------//

float GetNoise(sampler2D noiseSampler, vec2 position) {
	return texture(noiseSampler, position / 256.0).x;
}
vec2 GetNoise2HQ(sampler2D noiseSampler, vec2 position) {
	vec2  f = fract(position);
	ivec2 i = ivec2(position - f);

	vec4 samples0 = textureGather(noiseSampler, i / 256.0, 0);
	vec4 samples1 = textureGather(noiseSampler, i / 256.0, 1);

	vec4 w = f.xxyy;
	w.yw = 1.0 - w.yw;
	w = w.yxxy * w.zzww;

	return vec2(dot(samples0, w), dot(samples1, w));
}
float GetNoise(sampler2D noiseSampler, vec3 position) {
	float flr = floor(position.z);

	vec2 coord = (position.xy / 256.0) + (flr * (97.0/256.0));
	vec2 noise = texture(noiseSampler, coord).xy;

	return mix(noise.x, noise.y, position.z - flr);
}
#if !defined PROGRAM_WATER && !defined PROGRAM_HAND_WATER
vec2 GetNoise3D(sampler3D noiseSampler, vec3 position) {
	return texture(noiseSampler, fract(position)).rg;
}
#endif

float GetNoiseSmooth(sampler2D noiseSampler, vec2 position) {
	vec2 flr  = floor(position);
	vec2 frc  = position - flr;
	     frc *= frc * (3.0 - 2.0 * frc);

	vec2 coord = (flr.xy + frc.xy) / 256.0;
	return texture(noiseSampler, coord).x;
}
float GetNoiseSmooth(sampler2D noiseSampler, vec3 position) {
	vec3 flr  = floor(position);
	vec3 frc  = position - flr;
	     frc *= frc * (3.0 - 2.0 * frc);

	vec2 coord = ((flr.xy + frc.xy) / 256.0) + (flr.z * (97.0/256.0));
	vec2 noise = texture(noiseSampler, coord).xy;

	return mix(noise.x, noise.y, frc.z);
}

// Using defines so noisetex isn't a required uniform
#define GetNoise(pos) GetNoise(noisetex, pos)
#define GetNoise2HQ(pos) GetNoise2HQ(noisetex, pos)
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
#define HASHSCALE1 443.8975
#define HASHSCALE3 vec3(443.897, 441.423, 437.195)
#define HASHSCALE4 vec4(443.897, 441.423, 437.195, 444.129)
//#define HASHSCALE1 .1031
//#define HASHSCALE3 vec3(.1031, .1030, .0973)
//#define HASHSCALE4 vec4(.1031, .1030, .0973, .1099)

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
	vec2 i = floor(position);
	vec2 f = fract(position);

	float distSq = 2.5; // max possible
	for (int x = -1; x <= 1; ++x) {
		for (int y = -1; y <= 1; ++y) {
			vec2 cell = Hash2(i + vec2(x, y)) + vec2(x, y) - f;
			distSq = min(distSq, dot(cell, cell));
		}
	}

	return sqrt(distSq);
}
float CellNoise1(vec3 position) {
	vec3 i = floor(position);
	vec3 f = fract(position);

	float distSq = 2.75; // max possible
	for (int x = -1; x <= 1; ++x) {
		for (int y = -1; y <= 1; ++y) {
			for (int z = -1; z <= 1; ++z) {
				vec3 cell = Hash3(i + vec3(x, y, z)) + vec3(x, y, z) - f;
				distSq = min(distSq, dot(cell, cell));
			}
		}
	}

	return sqrt(distSq);
}

#endif
