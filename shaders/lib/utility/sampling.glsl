#if !defined INCLUDE_UTILITY_SAMPLING
#define INCLUDE_UTILITY_SAMPLING

vec3 GenerateUnitVector(vec2 xy) {
	xy.x *= tau; xy.y = xy.y * 2.0 - 1.0;
	return vec3(SinCos(xy.x) * sqrt(1.0 - xy.y * xy.y), xy.y);
}
vec3 GenerateConeVector(vec3 vector, float angle, vec2 xy) {
	vec3 dir = GenerateUnitVector(xy);
	float VoD = dot(vector, dir);
	float noiseAngle = acos(VoD) * (angle / pi);

	return sin(noiseAngle) * (dir - vector * VoD) * inversesqrt(1.0 - VoD * VoD) + cos(noiseAngle) * vector;
}

vec3 GenerateCosineVector(vec3 vector, vec2 xy) {
	// Apparently this is actually this simple.
	// http://www.amietia.com/lambertnotangent.html
	// (cosine lobe around vector = lambertian BRDF)
	return normalize(vector + GenerateUnitVector(xy));
}

#endif
