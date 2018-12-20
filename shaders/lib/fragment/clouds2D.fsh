#if !defined INCLUDE_FRAGMENT_CLOUDS2D
#define INCLUDE_FRAGMENT_CLOUDS2D

#define CLOUDS2D_SELFSHADOW_QUALITY 3 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]

#define CLOUDS2D_COVERAGE 0.5 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1]

#define CLOUDS2D_USE_WORLD_TIME
#define CLOUDS2D_SPEED 3.7

#define CLOUDS2D_ALTITUDE 10000
#define CLOUDS2D_THICKNESS 500

#define CLOUDS2D_ATTENUATION_COEFFICIENT 0.02
#define CLOUDS2D_SCATTERING_ALBEDO 0.8

//--// Utility functions, should be moved //----------------------------------//

float Get2DNoise(vec2 position) {
	return texture(noisetex, position.xy * 0.015625).x; // 1/64
}

//--// Shape //---------------------------------------------------------------//

float Get2DCloudsDensity(vec2 position, float cloudsTime) {
	//--// Main Noise

	const int mainOctaves = 6;

	vec2 mainPosition = position;
	float mainNoise = Get2DNoise(mainPosition = mainPosition * 4e-5 + cloudsTime);
	for (int i = 1; i < mainOctaves; ++i) {
		mainPosition *= rotateGoldenAngle;
		mainNoise += Get2DNoise(mainPosition = mainPosition * pi + cloudsTime) * exp2(-i);
	} mainNoise /= 2.0 - exp2(-mainOctaves);

	//--// Apply Coverage

	float density  = Clamp01(mainNoise + CLOUDS2D_COVERAGE - 1.0);
	      density *= density * (3.0 - 2.0 * density);

	//--// Modulate based on cell noise

	if (density > 0.0) {
		// TODO: Small-scale distortion?
		// TODO: Modulate strength based on more noise.
		float cellNoise = CellNoise1(position * 1e-3 + cloudsTime);
		density -= clamp(density, 0.0, 0.04) * Clamp01(cellNoise * cellNoise * (3.0 - 2.0 * cellNoise));
	}

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
vec3 Calculate2DCloudsSunlight(vec3 position, vec3 viewVector, float viewRayLength, float density, float cloudsTime, float dither) {
	const float upperAltitude = CLOUDS2D_ALTITUDE + CLOUDS2D_THICKNESS / 2.0;
	const float lowerAltitude = CLOUDS2D_ALTITUDE - CLOUDS2D_THICKNESS / 2.0;

	float shadowStartDist   = RaySphereIntersection(position + vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector, atmosphere_planetRadius + lowerAltitude).y;
	float shadowEndDist     = RaySphereIntersection(position + vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector, atmosphere_planetRadius + upperAltitude).y;
	float stepSizeShadowing = (shadowEndDist - shadowStartDist) / CLOUDS2D_SELFSHADOW_QUALITY;

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

	vec2 increment = stepSizeShadowing * shadowLightVector.xz;
	position.xz += increment * dither;

	float scattering = 0.0, transmittance = 1.0;
	for (int i = 0; i < CLOUDS2D_SELFSHADOW_QUALITY; ++i, position.xz += increment) {
		transmittance *= exp(-densityMult * Get2DCloudsDensity(position.xz, cloudsTime));
		scattering = scattering * stepTransmittance + transmittance;
	} scattering *= stepScattering;

	float phase = CloudsPhase2(dot(viewVector, shadowLightVector), vec3(-0.1, 0.3, 0.9), vec3(0.3, 0.6, 0.1));

	return illuminanceShadowlight * scattering * phase;
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
		float cloudsTime = (worldDay % 128 + worldTime / 24000.0) * CLOUDS2D_SPEED;
	#else
		float cloudsTime = frameTimeCounter * (1.0 / 1200.0) * CLOUDS2D_SPEED;
	#endif

	float density = Get2DCloudsDensity(centerPosition.xz, cloudsTime);
	if (density <= 0.0) { return vec4(vec3(0.0), 1.0); }

	float viewRayLength = endDistance - startDistance;

	vec3 scattering = Calculate2DCloudsSunlight(centerPosition, viewVector, viewRayLength, density, cloudsTime, dither);
	float transmittance = exp(-CLOUDS2D_ATTENUATION_COEFFICIENT * density * viewRayLength);

	return vec4(scattering, transmittance);
}

#endif
