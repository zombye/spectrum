#if !defined INCLUDE_FRAGMENT_CLOUDS3D
#define INCLUDE_FRAGMENT_CLOUDS3D

// quality
#define CLOUDS3D_STEPS_VIEW 10 // [5 10 20 50]
#define CLOUDS3D_STEPS_SUN 5 // [5 10 20 50]
#define CLOUDS3D_STEPS_SKY 2 // [2 5 10]
#define CLOUDS3D_ALTERNATE_SKYLIGHT

#define CLOUDS3D_MIN_TRANSMITTANCE 0.01 // Minimum transmittance before raymarch is stopped. After the raymarch, transmittance is then re-mapped so this value becomes 0.

#define CLOUDS3D_NOISE_OCTAVES_2D 2 // 2D noise octaves, determines overall shape.
#define CLOUDS3D_DETAIL_NOISE_OCTAVES 0 // [0 1 2]

// shape
#define CLOUDS3D_STATIC_COVERAGE 0.4 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1]

#define CLOUDS3D_USE_WORLD_TIME
#define CLOUDS3D_SPEED 3 // [0.2 0.4 0.6 0.8 1 1.2 1.4 1.6 1.8 2 2.2 2.4 2.6 2.8 3 3.2 3.4 3.6 3.8 4 4.2 4.4 4.6 4.8 5 5.2 5.4 5.6 5.8 6 6.2 6.4 6.6 6.8 7 7.2 7.4 7.6 7.8 8 8.2 8.4 8.6 8.8 9 9.2 9.4 9.6 9.8 10]
#define CLOUDS3D_ALTITUDE 700 // [300 400 500 600 700 800 900 1000]
#define CLOUDS3D_THICKNESS_MULT 0.7 // [0.5 0.6 0.7 0.8 0.9 1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2]
#define CLOUDS3D_SCALE 1.4 // [1 1.4 2 2.8 4]

#define CLOUDS3D_THICKNESS (CLOUDS3D_ALTITUDE * CLOUDS3D_THICKNESS_MULT)
#define CLOUDS3D_ALTITUDE_MIN CLOUDS3D_ALTITUDE
#define CLOUDS3D_ALTITUDE_MAX (CLOUDS3D_ALTITUDE + CLOUDS3D_THICKNESS)

// shading
#define CLOUDS3D_POWDER_STRENGTH 0.6

#define CLOUDS3D_ATTENUATION_COEFFICIENT (0.2 * 500.0 / CLOUDS3D_THICKNESS)
#define CLOUDS3D_SCATTERING_ALBEDO 1.0

#define CLOUDS3D_MSA_N 5    // scattering "octaves"
#define CLOUDS3D_MSA_A 0.35 // od scale per octave
#define CLOUDS3D_MSA_B 0.6  // g scale per octave

#if defined PROGRAM_DEFERRED
float Get3DCloudsDensity(vec3 position) {
	#ifdef CLOUDS3D_USE_WORLD_TIME
		float cloudsTime = CLOUDS3D_SPEED * TIME_SCALE * (worldDay % 128 + worldTime / 24000.0);
	#else
		float cloudsTime = CLOUDS3D_SPEED * TIME_SCALE * (1.0 / 1200.0) * frameTimeCounter;
	#endif

	float cloudAltitude = length(position + vec3(-cameraPosition.x, atmosphere_planetRadius, -cameraPosition.z)) - atmosphere_planetRadius;
	      cloudAltitude = (cloudAltitude - CLOUDS3D_ALTITUDE_MIN) / CLOUDS3D_THICKNESS;

	//--// 2D noise to determine where to place clouds

	const int octaves2D = CLOUDS3D_NOISE_OCTAVES_2D;

	vec2 noisePos2D  = position.xz * (1.0 / (CLOUDS3D_SCALE * CLOUDS3D_THICKNESS)) - cloudsTime;
	     noisePos2D -= (0.2 / CLOUDS3D_SCALE) * cloudAltitude * cloudAltitude;

	float noise2D = GetNoise(noisePos2D);
	for (int i = 1; i < octaves2D; ++i) {
		noisePos2D *= rotateGoldenAngle;
		noisePos2D = noisePos2D * pi - cloudsTime;
		noise2D += GetNoise(noisePos2D) * exp2(-i);
	} noise2D = noise2D * 0.5 + (0.5 * exp2(-octaves2D));

	// altitude & wheather-dependent coverage
	float coverageFade = Clamp01(cloudAltitude);
	      coverageFade = 1.0 - coverageFade * coverageFade;
	float coverage = mix(float(CLOUDS3D_STATIC_COVERAGE), 1.0, wetness) * coverageFade;
	float cloudsMask = Clamp01(2.5 * (noise2D + coverage + 0.125 - 1.0));

	// return early if no clouds
	if (cloudsMask <= 0.0) { return 0.0; }

	//--// 3D noise for detail

	const int octaves3D = CLOUDS3D_DETAIL_NOISE_OCTAVES + 2;

	vec3 noisePos3D = position * (4.5 / CLOUDS3D_THICKNESS) - cloudsTime * vec3(16.5, 6.0, 16.5);

	float noise3D = dot(GetNoise3D(colortex7, noisePos3D * 0.1), vec2(0.2, 1.0));

	noisePos3D *= 6.4;
	for (int i = 2; i < octaves3D; ++i) {
		noisePos3D.xz *= rotateGoldenAngle;
		noisePos3D = noisePos3D * pi - cloudsTime;
		//noise3D += GetNoise3D(colortex7, noisePos3D * 0.015625).x * exp2(-i);
		noise3D += GetNoise(noisePos3D) * 0.5 * exp2(-i);
	} noise3D += 0.5 * exp2(-octaves3D);
	noise3D = max(noise3D - 0.25, 0.0);

	float densityScale = Clamp01(cloudAltitude * 2.0);
	return Clamp01(2.0 * cloudsMask - noise3D) * densityScale;
}

float Calculate3DCloudsOpticalDepth(vec3 rayPosition, vec3 rayDirection, float startOffset, const int steps, const float stepGrowth) {
	vec2 outerDistances = RaySphereIntersection(rayPosition + vec3(0.0, atmosphere_planetRadius, 0.0), rayDirection, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX);
	if (outerDistances.y <= 0.0) { return 0.0; }
	vec2 innerDistances = RaySphereIntersection(rayPosition + vec3(0.0, atmosphere_planetRadius, 0.0), rayDirection, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN);

	float startDistance = rayPosition.y < CLOUDS3D_ALTITUDE_MIN ? innerDistances.y : (rayPosition.y > CLOUDS3D_ALTITUDE_MAX ? outerDistances.x : 0.0);
	float endDistance   = rayPosition.y < CLOUDS3D_ALTITUDE_MIN ? outerDistances.y : (innerDistances.y >= 0.0 ? innerDistances.x : outerDistances.y);

	float baseStepSize = (endDistance - startDistance) / (pow(stepGrowth, steps) - 1.0);

	rayPosition += rayDirection * startDistance;

	float stepSize = (pow(stepGrowth, startOffset + 0.5) - 1.0) * baseStepSize;
	float stepDist = (pow(stepGrowth, startOffset      ) - 1.0) * baseStepSize;
	float densitySum = stepSize * Get3DCloudsDensity(rayPosition + rayDirection * stepDist);
	stepSize = (sqrt(stepGrowth) - inversesqrt(stepGrowth)) * pow(stepGrowth, startOffset) * baseStepSize; //stepSize = baseStepSize * ((pow(stepGrowth, startOffset + 0.5) - 1.0) - (pow(stepGrowth, startOffset - 0.5) - 1.0));
	for (int i = 1; i < steps - 1; ++i) {
		stepSize *= stepGrowth; //stepSize = baseStepSize * ((pow(stepGrowth, i + startOffset + 0.5) - 1.0) - (pow(stepGrowth, i + startOffset - 0.5) - 1.0));
		float stepDist = baseStepSize * (pow(stepGrowth, i + startOffset) - 1.0);
		densitySum += stepSize * Get3DCloudsDensity(rayPosition + rayDirection * stepDist);
	}

	{ // handle last step separately
		stepSize = baseStepSize * ((pow(stepGrowth, steps) - 1.0) - (pow(stepGrowth, (steps - 1) + startOffset - 0.5) - 1.0));
		float stepDist = baseStepSize * (pow(stepGrowth, (steps - 1) + startOffset) - 1.0);
		densitySum += stepSize * Get3DCloudsDensity(rayPosition + rayDirection * stepDist);
	}

	return CLOUDS3D_ATTENUATION_COEFFICIENT * densitySum;
}
float Calculate3DCloudsOpticalDepth(vec3 rayPosition, vec3 rayDirection, float startOffset, const int steps) {
	vec2 outerDistances = RaySphereIntersection(rayPosition + vec3(0.0, atmosphere_planetRadius, 0.0), rayDirection, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX);
	if (outerDistances.y <= 0.0) { return 0.0; }
	vec2 innerDistances = RaySphereIntersection(rayPosition + vec3(0.0, atmosphere_planetRadius, 0.0), rayDirection, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN);

	float startDistance = rayPosition.y < CLOUDS3D_ALTITUDE_MIN ? innerDistances.y : (rayPosition.y > CLOUDS3D_ALTITUDE_MAX ? outerDistances.x : 0.0);
	float endDistance   = rayPosition.y < CLOUDS3D_ALTITUDE_MIN ? outerDistances.y : (innerDistances.y >= 0.0 ? innerDistances.x : outerDistances.y);

	float stepSize = (endDistance - startDistance) / steps;

	vec3 rayStep = rayDirection * stepSize;
	rayPosition += rayDirection * (startDistance + stepSize * startOffset);

	float densitySum = Get3DCloudsDensity(rayPosition);
	for (int i = 1; i < steps; ++i) {
		densitySum += Get3DCloudsDensity(rayPosition += rayStep);
	}

	return CLOUDS3D_ATTENUATION_COEFFICIENT * stepSize * densitySum;
}

void Calculate3DCloudsScattering(
	vec3 position, vec3 direction, float VdotL, float dither,
	float viewOpticalDepth, float stepOpticalDepth, float stepCoefficient,
	inout float scatteringSun, inout float scatteringSky
) {
	float stepTransmittance = exp(-stepOpticalDepth);

	float sunOpticalDepth = Calculate3DCloudsOpticalDepth(position, shadowLightVector, dither, CLOUDS3D_STEPS_SUN, 1.5);
	float sunPathOpticalDepth = viewOpticalDepth + sunOpticalDepth;
	float sunPathTransmittance = exp(-sunPathOpticalDepth);

	#ifdef CLOUDS3D_ALTERNATE_SKYLIGHT
	vec3 skyDir = GenerateUnitVector(Hash2(position));
	if (skyDir.y < 0.0) { skyDir.y = -skyDir.y; }
	float skyOpticalDepth = Calculate3DCloudsOpticalDepth(position, skyDir, dither, CLOUDS3D_STEPS_SKY, 1.5);
	#else
	float skyOpticalDepth = Calculate3DCloudsOpticalDepth(position, vec3(0.0, 1.0, 0.0), dither, CLOUDS3D_STEPS_SKY);
	#endif
	float skyPathOpticalDepth = viewOpticalDepth + skyOpticalDepth;
	float skyPathTransmittance = exp(-skyPathOpticalDepth);

	/* single-scattering, only here for reference
	float phase = PhaseHenyeyGreenstein(VdotL, 0.5);
	scatteringSun += CLOUDS3D_SCATTERING_ALBEDO * phase     * (sunPathTransmittance - sunPathTransmittance * stepTransmittance);
	scatteringSky += CLOUDS3D_SCATTERING_ALBEDO * (0.25/pi) * (skyPathTransmittance - skyPathTransmittance * stepTransmittance);
	//*/

	//* approximated multiple scattering
	const float scatterStrength = 1.5;
	const float slope = 0.3;
	float sunPath = exp(-viewOpticalDepth) * pow(1.0 + slope * scatterStrength * sunOpticalDepth, -1.0 / scatterStrength);
	float skyPath = exp(-viewOpticalDepth) * pow(1.0 + slope * scatterStrength * skyOpticalDepth, -1.0 / scatterStrength);

	float fakePowder = 1.0 - CLOUDS3D_POWDER_STRENGTH * exp(-70.0 * stepCoefficient);
	float sharedpart = 2.0 * CLOUDS3D_SCATTERING_ALBEDO * fakePowder * (1.0 - stepTransmittance);

	float sunPhase = mix(
		PhaseHenyeyGreenstein(VdotL,  pow(0.8, sunOpticalDepth + 1.0)),
		PhaseHenyeyGreenstein(VdotL, -pow(0.5, sunOpticalDepth + 1.0)),
		0.5
	);
	#ifdef CLOUDS3D_ALTERNATE_SKYLIGHT
	// having a multiply by 2 here gives a closer result to actually sampling the sky in each direction
	float skyPhase = 2.0 * mix(
		PhaseHenyeyGreenstein(dot(direction, skyDir),  pow(0.8, skyOpticalDepth + 1.0)),
		PhaseHenyeyGreenstein(dot(direction, skyDir), -pow(0.5, skyOpticalDepth + 1.0)),
		0.5
	);
	#else
	const float skyPhase = 0.25 / pi;
	#endif

	scatteringSun += sharedpart * sunPhase * sunPath;
	scatteringSky += sharedpart * skyPhase * skyPath;
	//*/
}

vec4 Render3DClouds(
	vec3 viewVector, float dither,
	inout float cloudsDistance
) {
	const int steps = CLOUDS3D_STEPS_VIEW;

	//--// raymarch init

	vec3 viewPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

	vec2 outerDistances = RaySphereIntersection(vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX);
	if (outerDistances.y <= 0.0) { return vec4(0.0, 0.0, 0.0, 1.0); }
	vec2 innerDistances = RaySphereIntersection(vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN);
	bool innerIntersected = innerDistances.y >= 0.0;

	float startDistance = eyeAltitude < CLOUDS3D_ALTITUDE_MIN ? innerDistances.y : (eyeAltitude > CLOUDS3D_ALTITUDE_MAX ? outerDistances.x : 0.0);
	float endDistance   = eyeAltitude < CLOUDS3D_ALTITUDE_MIN ? outerDistances.y : (innerIntersected ? innerDistances.x : outerDistances.y);

	cloudsDistance = endDistance;

	float stepSize = (endDistance - startDistance) / steps;

	vec3 rayPosition = viewPosition + viewVector * (startDistance + stepSize * dither);
	vec3 rayStep     = viewVector * stepSize;

	float VdotL = dot(viewVector, shadowLightVector);

	float scatteringSun = 0.0;
	float scatteringSky = 0.0;
	float opticalDepth = 0.0;

	//--// raymarch loop

	const float maxOpticalDepth = -log(CLOUDS3D_MIN_TRANSMITTANCE);
	for (int i = 0; i < steps && opticalDepth < maxOpticalDepth; ++i, rayPosition += rayStep) {
		float stepDensity = Get3DCloudsDensity(rayPosition);
		if (stepDensity <= 0.0) { continue; }
		float stepCoefficient = CLOUDS3D_ATTENUATION_COEFFICIENT * stepDensity;
		float stepOpticalDepth = stepCoefficient * stepSize;

		Calculate3DCloudsScattering(
			rayPosition, viewVector, VdotL, Hash1(rayPosition),
			opticalDepth, stepOpticalDepth, stepCoefficient,
			scatteringSun, scatteringSky
		);

		opticalDepth += stepOpticalDepth;

		// This will give the distance to the first step that had clouds.
		cloudsDistance = min((i + dither) * stepSize + startDistance, cloudsDistance);
	}

	//--//

	vec3 scattering = illuminanceShadowlight * scatteringSun + scatteringSky * skyAmbientUp;

	float transmittance = exp(-opticalDepth);
	transmittance = Clamp01(transmittance / (1.0 - CLOUDS3D_MIN_TRANSMITTANCE) - (CLOUDS3D_MIN_TRANSMITTANCE / (1.0 - CLOUDS3D_MIN_TRANSMITTANCE)));

	return vec4(scattering, transmittance);
}

float Calculate3DCloudsAverageTransmittance() {
	vec3 viewPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

	const ivec2 samples = ivec2(16, 4);

	float transmittance = 0.0;
	for (int x = 0; x < samples.x; ++x) {
		for (int y = 0; y < samples.y; ++y) {
			vec2 xy = (vec2(x, y) + 0.5) / samples;
			xy.y = xy.y * 0.5 + 0.5;
			vec3 dir = GenerateUnitVector(xy).xzy;

			transmittance += exp(-Calculate3DCloudsOpticalDepth(viewPosition, dir, 0.5, 25));
		}
	}

	return transmittance / (samples.x * samples.y);
}
#else
float GetCloudShadows(vec3 position) {
	position     = mat3(shadowModelView) * position;
	position.xy /= 200.0;
	position.xy /= 1.0 + length(position.xy);
	position.xy  = position.xy * 0.5 + 0.5;
	position.xy *= CLOUD_SHADOW_MAP_RESOLUTION * viewPixelSize;

	return texture(colortex6, position.xy).a;
}
#endif

#endif
