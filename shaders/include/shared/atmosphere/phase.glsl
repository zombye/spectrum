#if !defined INCLUDE_SHARED_ATMOSPHERE_PHASE
#define INCLUDE_SHARED_ATMOSPHERE_PHASE

float PhaseRayleigh(float cosTheta) {
	return (cosTheta * cosTheta + 1.0) * 0.375 / tau;
}
float PhaseMie(float cosTheta, float g) {
	float gg = g * g;
	float p1 = (0.375 * (1.0 - gg)) / (pi * (2.0 + gg));
	float p2 = (cosTheta * cosTheta + 1.0) * pow(-2.0 * g * cosTheta + 1.0 + gg, -1.5);
	return p1 * p2;
}

vec2 AtmospherePhases(float cosTheta, const float g) {
	return vec2(PhaseRayleigh(cosTheta), PhaseMie(cosTheta, g));
}

#endif
