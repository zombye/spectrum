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

	return sin(noiseAngle) * inversesqrt(1.0 - VoD * VoD) * (dir - vector * VoD) + cos(noiseAngle) * vector;
}

vec3 GenerateCosineVector(vec3 vector, vec2 xy) {
	// Apparently this is actually this simple.
	// http://www.amietia.com/lambertnotangent.html
	// (cosine lobe around vector = lambertian BRDF)
	return normalize(vector + GenerateUnitVector(xy));
}

vec3 GetFacetGGX(
	vec3 viewDirection,
	vec2 roughness, // along x and y axis of input space used for the view direction
	vec2 xy // uniform random numbers from 0 to 1 - x can be limited to < 1 to clamp tail
) {
	// GGX VNDF sampling
	// http://www.jcgt.org/published/0007/04/01/

	// transform view direction to hemisphere (section 3.2)
	viewDirection = normalize(vec3(roughness * viewDirection.xy, viewDirection.z));

	// orthonrmal basis (section 4.1)
	float clsq = dot(viewDirection.yx, viewDirection.yx);
	vec3 T1 = vec3(clsq > 0.0 ? vec2(-viewDirection.y, viewDirection.x) * inversesqrt(clsq) : vec2(1.0, 0.0), 0.0);
	vec3 T2 = vec3(-T1.y * viewDirection.z, viewDirection.z * T1.x, viewDirection.x * T1.y - T1.x * viewDirection.y);

	// parameterization of the projected area (section 4.2)
	float r = sqrt(xy.x);
	float phi = tau * xy.y;

	float t1 = r * cos(phi);
	float tmp = clamp(1.0 - t1 * t1, 0.0, 1.0);
	float t2 = mix(sqrt(tmp), r * sin(phi), 0.5 + 0.5 * viewDirection.z);

	// reprojection onto hemisphere (section 4.3)
	vec3 normalH = t1 * T1 + t2 * T2 + sqrt(clamp(tmp - t2 * t2, 0.0, 1.0)) * viewDirection;

	// transform normal back to ellipsoid (sectrion 3.4)
	return normalize(vec3(roughness * normalH.xy, normalH.z));
}

#endif
