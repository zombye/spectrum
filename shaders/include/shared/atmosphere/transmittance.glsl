#if !defined INCLUDE_SHARED_ATMOSPHERE_TRANSMITTANCE
#define INCLUDE_SHARED_ATMOSPHERE_TRANSMITTANCE

vec3 AtmosphereTransmittance(sampler2D sampler, float R, float Mu) {
	if (R > atmosphere_upperLimitRadius) {
		float discriminant = R * R * (Mu * Mu - 1.0) + atmosphere_upperLimitRadiusSquared;
		bool intersectsUpperLimit = Mu < 0.0 && discriminant >= 0.0;

		if (!intersectsUpperLimit) {
			return vec3(1.0);
		} else {
			float d = -R * Mu - sqrt(discriminant);

			// move r, mu, mus, to atmosphere starting point
			float newR = sqrt(d * d + 2.0 * R * Mu * d + R * R);
			Mu = (R * Mu + d) / newR;
			R = newR;
		}
	}

	vec2 coord = AtmosphereTransmittanceLookupUv(R, Mu);

	return texture(sampler, coord).rgb / atmosphere_valueScale;
}
vec3 AtmosphereTransmittance(sampler2D sampler, float R, float Mu, float distance) {
	// Transmittance from A to B is same as transmittance from B to A

	float endR  = sqrt(distance * distance + 2 * R * Mu * distance + R * R);
	float endMu = (R * Mu + distance) / endR;

	return AtmosphereTransmittance(sampler, R, Mu) / AtmosphereTransmittance(sampler, endR, endMu);
}
vec3 AtmosphereTransmittance(sampler2D sampler, vec3 position, vec3 direction) {
	float coreDistance = length(position);
	return AtmosphereTransmittance(sampler, coreDistance, dot(position, direction) / coreDistance);
}
vec3 AtmosphereTransmittance(sampler2D sampler, vec3 position, vec3 direction, float distance) {
	float coreDistance = length(position);
	return AtmosphereTransmittance(sampler, coreDistance, dot(position, direction) / coreDistance, distance);
}

#endif
