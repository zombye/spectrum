#if !defined INCLUDE_UTILITY_SPHERICALHARMONICS
#define INCLUDE_UTILITY_SPHERICALHARMONICS

vec4 CalculateSphericalHarmonics(vec3 xyz) {
	const vec2 freqW = vec2(0.5 * sqrt(1.0 / pi), sqrt(3.0 / (4.0 * pi)));
	return vec4(freqW.x, freqW.y * xyz.yzx);
}

vec3[4] CalculateSphericalHarmonicCoefficients(vec3 value, vec3 xyz) {
	vec4 harmonics = CalculateSphericalHarmonics(xyz);
	return vec3[4](value * harmonics.x, value * harmonics.y, value * harmonics.z, value * harmonics.w);
}
vec3 ValueFromSphericalHarmonicCoefficients(vec3[4] coefficients, vec3 xyz) {
	vec4 harmonics = CalculateSphericalHarmonics(xyz);
	return coefficients[0] * harmonics.x + coefficients[1] * harmonics.y + coefficients[2] * harmonics.z + coefficients[3] * harmonics.w;
}

#endif
