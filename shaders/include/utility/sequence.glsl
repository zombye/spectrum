#if !defined INCLUDE_UTILITY_SEQUENCE
#define INCLUDE_UTILITY_SEQUENCE

// all of this is just stuff from this page:
// http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
// don't ask me about any of this stuff, go to that page instead

// R1, R2, R3, etc would be better implemented by reapeated add then fract instead of the multiply
// that way you keep more precision for high n

// also might be better to make s0 an optional input, defaulting to 0.5
// that way dithering it could be done more easily

const float phi1 = 1.61803398874989484820458683436563; // = phi
const float phi2 = 1.32471795724474602596090885447809; // = plastic constant, plastic ratio, etc
const float phi3 = 1.220744084605759475361685349108831;

float R1(float n) {
	const float s0 = 0.5;
	const float alpha = 1.0 / phi1;
	return fract(s0 + n * alpha);
}
vec2 R2(float n) {
	const float s0 = 0.5;
	const vec2 alpha = 1.0 / vec2(phi2, phi2 * phi2);
	return fract(s0 + n * alpha);
}
vec3 R3(float n) {
	const float s0 = 0.5;
	const vec3 alpha = 1.0 / vec3(phi3, phi3 * phi3, phi3 * phi3 * phi3);
	return fract(s0 + n * alpha);
}

float R2Dither(vec2 xy) {
	const vec2 alpha = 1.0 / vec2(phi2, phi2 * phi2);
	return fract(dot(xy, alpha));
}
float R2DitherContinuous(vec2 xy) { // technically better but only slightly
	float z = R2Dither(xy);
	return z < 0.5 ? 2.0 * z : 2.0 - 2.0 * z;
}

#endif
