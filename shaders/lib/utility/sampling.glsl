#if !defined INCLUDE_UTILITY_SAMPLING
#define INCLUDE_UTILITY_SAMPLING

vec3 GenUnitVector(vec2 xy) {
	xy.x *= tau; xy.y = xy.y * 2.0 - 1.0;
	return vec3(SinCos(xy.x) * sqrt(1.0 - xy.y * xy.y), xy.y);
}
vec3 GenConeVector(vec3 vector, float angle, vec2 xy) {
	vec3 dir = GenUnitVector(xy);
	float VoD = dot(vector, dir);
	float noiseAngle = acos(VoD) * (angle / pi);

	return sin(noiseAngle) * (dir - vector * VoD) * inversesqrt(1.0 - VoD * VoD) + cos(noiseAngle) * vector;
}

vec3 GenCosineVector(vec3 vector, vec3 xyz) {
	vec3 dir = GenUnitVector(xyz.xy);
	float VoD = dot(vector, dir);

	return sqrt(xyz.z) * (dir - vector * VoD) * inversesqrt(1.0 - VoD * VoD) + sqrt(1.0 - xyz.z) * vector;
}

#endif
