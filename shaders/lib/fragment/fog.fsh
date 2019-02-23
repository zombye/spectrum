#if !defined INCLUDE_FRAGMENT_FOG
#define INCLUDE_FRAGMENT_FOG

#define SEA_LEVEL 63 // [4 63]

float CalculateAtmosphereRayleighDensity(vec3 worldPosition) {
	return FOG_AIR_DENSITY * exp(-atmosphere_inverseScaleHeights.x * (worldPosition.y - SEA_LEVEL));
}
float CalculateAtmosphereMieDensity(vec3 worldPosition) {
	return FOG_AIR_DENSITY * exp(-atmosphere_inverseScaleHeights.y * (worldPosition.y - SEA_LEVEL));
}
float CalculateMistDensity(vec3 worldPosition) {
	float heightFade = Pow4(smoothstep(32.0, 0.0, worldPosition.y - SEA_LEVEL));
	float timeFade   = sunAngle < 0.5 ? Pow2(smoothstep(0.1, 0.0, sunAngle)) : smoothstep(0.5, 1.0, sunAngle);

	float noise = 2.0 * GetNoise(worldPosition / 3.5);

	return heightFade * timeFade * noise;
}

float GetDensity(vec3 worldPosition, int componentIndex) {
	switch (componentIndex) {
		case 0: return CalculateAtmosphereRayleighDensity(worldPosition);
		case 1: return CalculateAtmosphereMieDensity(worldPosition);
		case 2: return CalculateMistDensity(worldPosition);
		default: return 0.0;
	}
}
float GetPhase(float cosTheta, int componentIndex) {
	switch (componentIndex) {
		case 0: return PhaseRayleigh(cosTheta);
		case 1: return PhaseMie(cosTheta, atmosphere_mieg);
		case 2: return PhaseHenyeyGreenstein(cosTheta, 0.4);
		default: return 0.25 / pi;
	}
}

vec3 CalculateVolumeSunlighting(vec3 scenePosition, vec3 shadowPosition) {
	#ifdef SHADOW_INFINITE_RENDER_DISTANCE
		vec3 lighting = vec3(ReadShadowMaps(DistortShadowSpace(shadowPosition) * 0.5 + 0.5));
	#else
		vec3 lighting;
		if (dot(shadowPosition.xy, shadowPosition.xy) < 1.0) {
			lighting = vec3(ReadShadowMaps(DistortShadowSpace(shadowPosition) * 0.5 + 0.5));
		} else {
			lighting = vec3(1.0);
		}
	#endif

	#ifdef CLOUDS3D
		lighting *= GetCloudShadows(scenePosition);
	#endif

	return lighting;
}

vec3 CalculateFog(vec3 background, vec3 startPosition, vec3 endPosition, float skylight, float dither) {
	const int steps = VL_AIR_STEPS;

	vec3 worldIncrement = (endPosition - startPosition) / steps;
	vec3 worldPosition  = startPosition + worldIncrement * dither;
	     worldPosition += cameraPosition;

	vec3 shadowIncrement    = mat3(shadowModelView) * worldIncrement;
	     shadowIncrement   *= Diagonal(shadowProjection).xyz;
	     shadowIncrement.z /= SHADOW_DEPTH_SCALE;
	vec3 shadowPosition     = mat3(shadowModelView) * startPosition + shadowModelView[3].xyz;
	     shadowPosition     = Diagonal(shadowProjection).xyz * shadowPosition + shadowProjection[3].xyz;
	     shadowPosition.z  /= SHADOW_DEPTH_SCALE;
	     shadowPosition    += dither * shadowIncrement;

	float stepSize = length(worldIncrement);
	vec3 viewVector = worldIncrement / stepSize;

	//--//

	const int componentCount = 3;
	const vec3[componentCount] attenuationCoefficients = vec3[componentCount](atmosphere_coefficientsAttenuation[0], atmosphere_coefficientsAttenuation[1], vec3(0.01));
	const vec3[componentCount] scatteringCoefficients = vec3[componentCount](atmosphere_coefficientsScattering[0], atmosphere_coefficientsScattering[1], 0.9 * attenuationCoefficients[2]);

	float LoV = dot(viewVector, shadowLightVector);
	float[componentCount] phase;
	for (int compIdx = 0; compIdx < componentCount; ++compIdx) {
		phase[compIdx] = GetPhase(LoV, compIdx);
	}

	//--//

	vec3 scatteringSun = vec3(0.0);
	vec3 scatteringSky = vec3(0.0);
	vec3 transmittance = vec3(1.0);
	for (int i = 0; i < steps; ++i) {
		float[componentCount] density;
		float[componentCount] stepAirmass;
		vec3 opticalDepth = vec3(0.0);
		for (int compIdx = 0; compIdx < componentCount; ++compIdx) {
			density[compIdx] = GetDensity(worldPosition, compIdx);
			stepAirmass[compIdx] = density[compIdx] * stepSize;
			opticalDepth += attenuationCoefficients[compIdx] * stepAirmass[compIdx];
		}

		//--//

		vec3 stepTransmittance       = exp(-opticalDepth);
		vec3 stepTransmittedFraction = Clamp01((stepTransmittance - 1.0) / -opticalDepth);
		vec3 stepVisibleFraction     = transmittance * stepTransmittedFraction;

		//--//

		vec3 lightingSun = CalculateVolumeSunlighting(worldPosition - cameraPosition, shadowPosition);

		//--//

		vec3 stepScatteringSun = vec3(0.0);
		vec3 stepScatteringSky = vec3(0.0);
		for (int compIdx = 0; compIdx < componentCount; ++compIdx) {
			stepScatteringSun += scatteringCoefficients[compIdx] * stepAirmass[compIdx] * phase[compIdx];
			stepScatteringSky += scatteringCoefficients[compIdx] * stepAirmass[compIdx] * 0.25 / pi;
		}

		//--//

		scatteringSun += stepScatteringSun * stepVisibleFraction * lightingSun;
		scatteringSky += stepScatteringSky * stepVisibleFraction;
		transmittance *= stepTransmittance;

		worldPosition  += worldIncrement;
		shadowPosition += shadowIncrement;
	}

	scatteringSun *= illuminanceShadowlight;
	scatteringSky *= illuminanceSky * skylight;

	//--//

	vec3 scattering = scatteringSun + scatteringSky;

	return background * transmittance + scattering;
}

#endif
