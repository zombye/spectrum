#if !defined INCLUDE_FRAGMENT_CLOUDS2D
#define INCLUDE_FRAGMENT_CLOUDS2D

#define CLOUDS2D_SELFSHADOW_QUALITY 3 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]

#define CLOUDS2D_COVERAGE 0.5 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1]

#define CLOUDS2D_USE_WORLD_TIME

#define CLOUDS2D_ALTITUDE 10000
#define CLOUDS2D_THICKNESS 500

#define CLOUDS2D_ATTENUATION_COEFFICIENT 0.02
#define CLOUDS2D_SCATTERING_ALBEDO 0.8

//--// Shape //---------------------------------------------------------------//

vec2 GetDistortionNoise2(vec2 position) {
	vec2 noise = GetNoise2HQ(position);
	return SinCos(noise.x * tau) * (1.0 - noise.y * noise.y);
}

float Get2DCloudsDensity(vec2 position, float cloudsTime) {
	//--// Main Noise

	vec2 distortionPosition = position * 8e-6 + cloudsTime * 0.1;

	const int distortionOctaves = 10;
	vec2 distortionNoise = GetDistortionNoise2(distortionPosition);
	for (int i = 1; i < distortionOctaves; ++i) {
		distortionPosition *= rotateGoldenAngle;
		distortionPosition  = distortionPosition * 2.0 + cloudsTime * 0.1;
		distortionNoise += GetDistortionNoise2(distortionPosition) * exp2(log2(0.52) * i);
	}

	//--// Distorted "main" noise

	vec2 mainPosition  = (position + distortionNoise * 0.15 / 8e-6) * 4e-5 + cloudsTime;

	const int mainOctaves = 6;

	float mainNoise = GetNoise(mainPosition);
	for (int i = 1; i < mainOctaves; ++i) {
		mainPosition *= rotateGoldenAngle;
		mainPosition = mainPosition * pi + cloudsTime;
		mainNoise += GetNoise(mainPosition) * exp2(-i);
	} mainNoise = mainNoise * 0.5 + (0.5 * exp2(-mainOctaves));

	//--// Apply Coverage

	float density  = Clamp01(mainNoise + CLOUDS2D_COVERAGE - 1.0);
	      density *= density * (3.0 - 2.0 * density);
	      density  = 1.0 - Pow2(1.0 - density);

	return density;
}

//--// Lighting //------------------------------------------------------------//

float CloudsPhase2(float cosTheta, vec3 g, vec3 w) {
	vec3 gmn2 = -2.0 * g;
	vec3 gg   = g * g;
	vec3 gga1 = 1.0 + gg;
	vec3 p1   = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));

	vec3 res = p1 * (cosTheta * cosTheta + 1.0) * pow(gmn2 * cosTheta + gga1, vec3(-1.5));

	return dot(res, w) / (w.x + w.y + w.z);
}

vec3 Calculate2DCloudsSunlightAndMoonlight(vec3 position, vec3 viewVector, float viewRayLength, float density, float cloudsTime, float dither) {
	const float upperAltitude = CLOUDS2D_ALTITUDE + CLOUDS2D_THICKNESS / 2.0;
	const float lowerAltitude = CLOUDS2D_ALTITUDE - CLOUDS2D_THICKNESS / 2.0;

	position.y += atmosphere_planetRadius;

	float shadowStartDist   = RaySphereIntersection(position, shadowLightVector, atmosphere_planetRadius + lowerAltitude).y;
	float shadowEndDist     = RaySphereIntersection(position, shadowLightVector, atmosphere_planetRadius + upperAltitude).y;
	float stepSizeShadowing = (shadowStartDist > 0.0 ? shadowEndDist - shadowStartDist : shadowEndDist) / CLOUDS2D_SELFSHADOW_QUALITY;

	float stepSize          = viewRayLength / CLOUDS2D_SELFSHADOW_QUALITY;
	float stepOpticalDepth  = CLOUDS2D_ATTENUATION_COEFFICIENT * stepSize * density;

	/* single-scattering
	float stepTransmittance = exp(-stepOpticalDepth);
	float stepScattering    = CLOUDS2D_SCATTERING_ALBEDO * (1.0 - stepTransmittance);
	float densityMult       = CLOUDS2D_ATTENUATION_COEFFICIENT * stepSizeShadowing;
	//*/
	//* fake multiscattering
	float stepTransmittance = exp((CLOUDS2D_SCATTERING_ALBEDO - 1.0) * stepOpticalDepth);
	float stepScattering    = CLOUDS2D_SCATTERING_ALBEDO * (1.0 - stepTransmittance) / (1.0 - CLOUDS2D_SCATTERING_ALBEDO);
	float densityMult       = (1.0 - CLOUDS2D_SCATTERING_ALBEDO) * CLOUDS2D_ATTENUATION_COEFFICIENT * stepSizeShadowing;
	//*/

	vec2 incrementSun  = stepSizeShadowing * sunVector.xz;
	vec2 incrementMoon = stepSizeShadowing * moonVector.xz;
	vec2 positionSun   = incrementSun  * dither + position.xz;
	vec2 positionMoon  = incrementMoon * dither + position.xz;


	float scatteringSun = 0.0, scatteringMoon = 0.0, transmittanceSun = 1.0, transmittanceMoon = 1.0;
	if (dot(position, sunVector) >= 0.0) {
		for (int i = 0; i < CLOUDS2D_SELFSHADOW_QUALITY; ++i, positionSun += incrementSun, positionMoon += incrementMoon) {
			transmittanceSun *= exp(-densityMult * Get2DCloudsDensity(positionSun, cloudsTime));
			scatteringSun     = scatteringSun * stepTransmittance + transmittanceSun;

			transmittanceMoon *= exp(-densityMult * Get2DCloudsDensity(positionMoon, cloudsTime));
			scatteringMoon    += transmittanceMoon;
			transmittanceMoon *= stepTransmittance;
		}
	} else {
		for (int i = 0; i < CLOUDS2D_SELFSHADOW_QUALITY; ++i, positionSun += incrementSun, positionMoon += incrementMoon) {
			transmittanceSun *= exp(-densityMult * Get2DCloudsDensity(positionSun, cloudsTime));
			scatteringSun    += transmittanceSun;
			transmittanceSun *= stepTransmittance;

			transmittanceMoon *= exp(-densityMult * Get2DCloudsDensity(positionMoon, cloudsTime));
			scatteringMoon     = scatteringMoon * stepTransmittance + transmittanceMoon;
		}
	}

	scatteringSun  *= stepScattering;
	scatteringMoon *= stepScattering;

	// TODO: Add shadows cast by other, more distant clouds, as an option.

	vec3 sunlight   = sunIlluminance * AtmosphereTransmittance(transmittanceLut, position, sunVector);
	     sunlight  *= CloudsPhase2(dot(viewVector, sunVector), vec3(-0.1, 0.3, 0.9), vec3(0.3, 0.6, 0.1));
	vec3 moonlight  = moonIlluminance * AtmosphereTransmittance(transmittanceLut, position, moonVector);
	     moonlight *= CloudsPhase2(dot(viewVector, moonVector), vec3(-0.1, 0.3, 0.9), vec3(0.3, 0.6, 0.1));

	vec3 scattering = vec3(0.0);
	scattering += scatteringSun  * sunlight;
	scattering += scatteringMoon * moonlight;

	return scattering;
}

vec4 Calculate2DClouds(vec3 viewVector, float dither) {
	const float upperAltitude = CLOUDS2D_ALTITUDE + CLOUDS2D_THICKNESS / 2.0;
	const float lowerAltitude = CLOUDS2D_ALTITUDE - CLOUDS2D_THICKNESS / 2.0;

	vec3 viewPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

	float endDistance = RaySphereIntersection(vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector, atmosphere_planetRadius + upperAltitude).y;
	if (endDistance <= 0.0) { return vec4(vec3(0.0), 1.0); }
	float startDistance = RaySphereIntersection(vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector, atmosphere_planetRadius + lowerAltitude).y;

	float centerDistance = (endDistance + startDistance) / 2.0;
	vec3 centerPosition = viewPosition + viewVector * centerDistance;

	#ifdef CLOUDS2D_USE_WORLD_TIME
		float cloudsTime = 3.7 * TIME_SCALE * (worldDay % 128 + worldTime / 24000.0);
	#else
		float cloudsTime = 3.7 * TIME_SCALE * (1.0 / 1200.0) * frameTimeCounter;
	#endif

	float density = Get2DCloudsDensity(centerPosition.xz, cloudsTime);
	if (density <= 0.0) { return vec4(vec3(0.0), 1.0); }

	float viewRayLength = endDistance - startDistance;

	vec3 scattering = Calculate2DCloudsSunlightAndMoonlight(centerPosition, viewVector, viewRayLength, density, cloudsTime, dither);
	float transmittance = exp(-CLOUDS2D_ATTENUATION_COEFFICIENT * density * viewRayLength);

	return vec4(scattering, transmittance);
}

#endif
