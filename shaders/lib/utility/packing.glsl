#if !defined INLCUDE_UTILITY_PACKING
#define INCLUDE_UTILITY_PACKING

// As far as I know, this is the fastest possible method for pack2x8 and unpack2x8
float Pack2x8(vec2 x) {
	return dot(floor(255.0 * x + 0.5), vec2(1.0 / 65535.0, 256.0 / 65535.0));
} float Pack2x8(float x, float y) { return Pack2x8(vec2(x, y)); }
float Pack2x8Dithered(vec2 x, float pattern) {
	return dot(floor(255.0 * x + pattern), vec2(1.0 / 65535.0, 256.0 / 65535.0));
} float Pack2x8Dithered(float x, float y, float pattern) { return Pack2x8Dithered(vec2(x, y), pattern); }

vec2 Unpack2x8(float pack) {
	pack *= 65535.0 / 256.0;
	vec2 xy; xy.y = floor(pack); xy.x = pack - xy.y;
	return vec2(256.0 / 255.0, 1.0 / 255.0) * xy;
}
void Unpack2x8(float pack, out float x, out float y) {
	vec2 xy = Unpack2x8(pack);
	x = xy.x; y = xy.y;
}
float Unpack2x8X(float x) { return (256.0 / 255.0) * fract(x * (65535.0 / 256.0)); }
float Unpack2x8Y(float x) { return floor(x * (65535.0 / 256.0)) / 255.0; }

uint PackUnormArbitrary(vec4 x, uvec4 bitCount) {
	// Clamp between 0 and 1 to prevent overflowing into a neighboring value
	x = clamp(x, 0.0, 1.0);

	// Scale to give the correct range once converted into uints
	x *= vec4(uvec4(1u) << bitCount) - 1.0;

	// Convert to uints
	uvec4 ix = uvec4(x);

	// Bitshift to position bitfields to not overlap
	// 00000001 << 5 == 00100000
	ix = ix << uvec4(0u, bitCount.x, bitCount.x + bitCount.y, bitCount.x + bitCount.y + bitCount.z);

	// Merge with logical or operations.
	// Output bit is 1 if either input bit is 1. 01010000 | 00001101 == 01011101
	return ix.x | ix.y | ix.z | ix.w;

	// Side note: Addition is equivalent to a logical or provided that the bitfields of the inputs don't overlap
	// return ix.x + ix.y + ix.z + ix.w;
}
vec4 UnpackUnormArbitrary(uint x, uvec4 bitCount) {
	// Initial component separation, undo bit shift
	uvec4 ix = uvec4(x) >> uvec4(0u, bitCount.x, bitCount.x + bitCount.y, bitCount.x + bitCount.y + bitCount.z);

	// Finish separating components using logical and operations
	// `(1 << bitCount) - 1` sets the first bitCount bits to 1
	uvec4 bits = (uvec4(1u) << bitCount) - 1u;
	ix = ix & bits;

	// Convert to floats, scale back to 0-1 range
	return vec4(ix) / vec4(bits);
}

#endif
