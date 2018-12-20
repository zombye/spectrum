#if !defined INCLUDE_SHARED_BLURTILEOFFSET
#define INCLUDE_SHARED_BLURTILEOFFSET

vec2 CalculateTileOffset(int id) {
	// offsets approximately follow this curve: (1 - 4⁻ˣ) / 3

	const vec2 paddingPixels = vec2(12.0, 12.0); // Set as needed

	vec2 idMult = floor(id * 0.5 + vec2(0.0, 0.5));
	vec2 offset = vec2(1.0 / 3.0, 2.0 / 3.0) * (1.0 - exp2(-2.0 * idMult));

	vec2 paddingAccum = idMult * paddingPixels;

	return paddingAccum * viewPixelSize + offset;
}

#endif
