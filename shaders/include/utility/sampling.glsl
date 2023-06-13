#if !defined INCLUDE_UTILITY_SAMPLING
#define INCLUDE_UTILITY_SAMPLING

vec3 SampleSphere(vec2 xy) {
	xy.x *= tau;
	xy.y = xy.y * 2.0 - 1.0;
	return vec3(vec2(cos(xy.x), sin(xy.x)) * sqrt(1.0 - xy.y * xy.y), xy.y);
}
vec3 SampleSphereCap(float angle, vec2 xy) {
	xy.x *= tau;
	float cosAngle = cos(angle);
	xy.y = xy.y * (1.0 - cosAngle) + cosAngle;
	return vec3(vec2(cos(xy.x), sin(xy.x)) * sqrt(1.0 - xy.y * xy.y), xy.y);
}
vec3 SampleSphereCap(vec3 orientation, float angle, vec2 xy) {
	vec3 v = SampleSphere(xy);
	float VoD = dot(v, orientation);

	float cosAngle = cos(angle);
	float newCosTheta = VoD * (1.0 - cosAngle) + cosAngle;

	return sqrt(1.0 - newCosTheta * newCosTheta) * inversesqrt(1.0 - VoD * VoD) * (v - orientation * VoD) + newCosTheta * orientation;
}

vec3 SampleLambert(vec3 vector, vec2 xy) {
	// Apparently it is actually this simple.
	// http://www.amietia.com/lambertnotangent.html
	return normalize(vector + SampleSphere(xy));
}

vec3 SampleVNDFGGX(
	vec3 viewDirection,
	vec2 roughness, // along x and y axis of input space used for the view direction
	vec2 xy // uniform random numbers from 0 to 1 - x can be limited to < 1 to clamp tail
) {
	// GGX VNDF Sampling
	// For more information, see the paper:
	// https://ggx-research.github.io/publication/2023/06/09/publication-ggx.html

	// Transform viewer direction to the hemisphere configuration.
	viewDirection = normalize(vec3(roughness * viewDirection.xy, viewDirection.z));

	// Sample a reflection direction off a hemisphere
	// This is equivalent to sampling a spherical cap
	float phi = tau * xy.x;
	float cosTheta = fma(1.0 - xy.y, 1.0 + viewDirection.z, -viewDirection.z);
	float sinTheta = sqrt(clamp(1.0 - cosTheta * cosTheta, 0.0, 1.0));
	vec3 reflected = vec3(vec2(cos(phi), sin(phi)) * sinTheta, cosTheta);

	// Evaluate halfway direction
	// This points along a normal on a hemisphere
	vec3 halfway = reflected + viewDirection;

	// Transform halfway direction back to hemiellispoid configuation
	// This is the final sampled normal.
	return normalize(vec3(roughness * halfway.xy, halfway.z));
}

#endif
