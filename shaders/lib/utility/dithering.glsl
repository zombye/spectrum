#if !defined INCLUDE_UTILITY_DITHERING
#define INCLUDE_UTILITY_DITHERING

float Bayer2  (vec2 c) { c = 0.5 * floor(c); return fract(1.5 * fract(c.y) + c.x); }
float Bayer4  (vec2 c) { return 0.25 * Bayer2 (0.5 * c) + Bayer2(c); }
float Bayer8  (vec2 c) { return 0.25 * Bayer4 (0.5 * c) + Bayer2(c); }
float Bayer16 (vec2 c) { return 0.25 * Bayer8 (0.5 * c) + Bayer2(c); }
float Bayer32 (vec2 c) { return 0.25 * Bayer16(0.5 * c) + Bayer2(c); }
float Bayer64 (vec2 c) { return 0.25 * Bayer32(0.5 * c) + Bayer2(c); }
float Bayer128(vec2 c) { return 0.25 * Bayer64(0.5 * c) + Bayer2(c); }

// 1D "bayer" functions
float LinearBayer2  (float c) { return fract(c * 0.5); }
float LinearBayer4  (float c) { return 0.5 * LinearBayer2 (c * 0.5) + LinearBayer2(c); }
float LinearBayer8  (float c) { return 0.5 * LinearBayer4 (c * 0.5) + LinearBayer2(c); }
float LinearBayer16 (float c) { return 0.5 * LinearBayer8 (c * 0.5) + LinearBayer2(c); }
float LinearBayer32 (float c) { return 0.5 * LinearBayer16(c * 0.5) + LinearBayer2(c); }
float LinearBayer64 (float c) { return 0.5 * LinearBayer32(c * 0.5) + LinearBayer2(c); }
float LinearBayer128(float c) { return 0.5 * LinearBayer64(c * 0.5) + LinearBayer2(c); }

#endif
