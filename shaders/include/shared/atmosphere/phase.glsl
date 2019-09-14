#if !defined INCLUDE_SHARED_ATMOSPHERE_PHASE
#define INCLUDE_SHARED_ATMOSPHERE_PHASE

vec2 AtmospherePhases(float cosTheta, const float g) {
	return vec2(PhaseRayleigh(cosTheta), PhaseMie(cosTheta, g));
}

#endif
