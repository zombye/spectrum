#if !defined INCLUDE_SHARED_ATMOSPHERE_RAYMARCH_TRANSMITTANCE
#define INCLUDE_SHARED_ATMOSPHERE_RAYMARCH_TRANSMITTANCE

vec3 AtmosphereAirmass(float R, float Mu, float rayLength, int steps) {
	float stepSize = rayLength / steps;

	float twoRMu = 2.0 * R * Mu;
	float rSquared = R * R;

	vec3 airmass = vec3(0.0);
	for (float i = 0.5; i < steps; ++i) {
		float ds = i * stepSize;
		float stepR = sqrt(ds * ds + twoRMu * ds + rSquared);
		airmass += AtmosphereDensity(stepR);
	} airmass *= stepSize;

	return airmass;
}
vec3 AtmosphereAirmass(float R, float Mu, int steps) {
	float rayLength = AtmosphereDistanceToUpperLimit(R, Mu);

	return AtmosphereAirmass(R, Mu, rayLength, steps);
}
vec3 AtmosphereOpticalDepth(float R, float Mu, float rayLength, int steps) {
	return atmosphere_coefficientsAttenuation * AtmosphereAirmass(R, Mu, rayLength, steps);
}
vec3 AtmosphereOpticalDepth(float R, float Mu, int steps) {
	return atmosphere_coefficientsAttenuation * AtmosphereAirmass(R, Mu, steps);
}
vec3 AtmosphereTransmittance(float R, float Mu, float rayLength, int steps) {
	return exp(-AtmosphereOpticalDepth(R, Mu, rayLength, steps));
}
vec3 AtmosphereTransmittance(float R, float Mu, int steps) {
	return exp(-AtmosphereOpticalDepth(R, Mu, steps));
}

vec3 AtmosphereTransmittance(vec3 position, vec3 direction, float rayLength, int steps) {
	float R  = length(position);
	float Mu = dot(position, direction) / R;

	return AtmosphereTransmittance(R, Mu, rayLength, steps);
}
vec3 AtmosphereTransmittance(vec3 position, vec3 direction, int steps) {
	float R  = length(position);
	float Mu = dot(position, direction) / R;

	return AtmosphereTransmittance(R, Mu, steps);
}

#endif
