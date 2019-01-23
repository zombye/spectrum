#if !defined INCLUDE_FRAGMENT_CLOUDS3D
#define INCLUDE_FRAGMENT_CLOUDS3D

#define CLOUDS3D_STEPS 15 // [5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]
#define CLOUDS3D_SELFSHADOW_STEPS_SUN 7 // Default 7
#define CLOUDS3D_SELFSHADOW_RANGE_SUN 350
#define CLOUDS3D_SELFSHADOW_STEPS_SKY 5 // Default 5
#define CLOUDS3D_NOISE_SMOOTH
#define CLOUDS3D_NOISE_OCTAVES_VIEW 5
#define CLOUDS3D_NOISE_OCTAVES_SHADOW 4

#define CLOUDS3D_DYNAMIC_COVERAGE
#define CLOUDS3D_STATIC_COVERAGE 0.5 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1]

#define CLOUDS3D_USE_WORLD_TIME
#define CLOUDS3D_SPEED 4.8 // [0 0.2 0.4 0.6 0.8 1 1.2 1.4 1.6 1.8 2 2.2 2.4 2.6 2.8 3 3.2 3.4 3.6 3.8 4 4.2 4.4 4.6 4.8 5 5.2 5.4 5.6 5.8 6 6.2 6.4 6.6 6.8 7 7.2 7.4 7.6 7.8 8 8.2 8.4 8.6 8.8 9 9.2 9.4 9.6 9.8 10]

//#define CLOUDS3D_SIMPLE_SKYLIGHT_SHADING // Simpler and much faster skylight shading on clouds.

#define CLOUDS3D_ATTENUATION_COEFFICIENT 0.15
#define CLOUDS3D_SCATTERING_ALBEDO 0.7

#define CLOUDS3D_ALTITUDE_MAX 900
#define CLOUDS3D_ALTITUDE_MIN 600
#define CLOUDS3D_THICKNESS (CLOUDS3D_ALTITUDE_MAX - CLOUDS3D_ALTITUDE_MIN)

//--// Shape //---------------------------------------------------------------//

float GetCloudCoverage() {
	#ifdef CLOUDS3D_DYNAMIC_COVERAGE
		const float changeFrequency = 1.0;
		const uint  octaves = 4u;

		float c  = worldDay + worldTime / 24000.0;
		      c *= changeFrequency;

		float coverage = ValueNoise1(c, 0u);
		for (uint i = 1u; i < octaves; ++i) {
			coverage += ValueNoise1(c *= 2.0, i) * exp2(-int(i));
		} coverage /= 2.0 - exp2(-int(octaves));

		coverage = mix(0.4, 0.6, coverage * coverage);
	#else
		const float coverage = CLOUDS3D_STATIC_COVERAGE;
	#endif

	return Clamp01(coverage + wetness);
}

float Get3DCloudDensity(vec3 position, float coreDistance, float coverage, const int octaves) {
	#ifdef CLOUDS3D_USE_WORLD_TIME
		float cloudsTime = (worldDay % 128 + worldTime / 24000.0) * CLOUDS3D_SPEED;
	#else
		float cloudsTime = frameTimeCounter * (1.0 / 1200.0) * CLOUDS3D_SPEED;
	#endif

	float cloudAltitude = coreDistance - atmosphere_planetRadius;
	      cloudAltitude = (cloudAltitude - CLOUDS3D_ALTITUDE_MIN) / CLOUDS3D_THICKNESS;

	//--// Noise

	position = position * 1e-3 + cloudsTime;

	#ifdef CLOUDS3D_NOISE_SMOOTH
		#define GetClouds3DNoise(pos) GetNoiseSmooth(pos)
	#else
		#define GetClouds3DNoise(pos) GetNoise(pos)
	#endif

	float density = GetClouds3DNoise(position);
	for (int i = 1; i < octaves; ++i) {
		position.xz *= rotateGoldenAngle;
		position = position * pi + cloudsTime;
		density += GetClouds3DNoise(position) * exp2(-i);
	} density = density * 0.5 + (0.5 * exp2(-octaves));

	#undef GetClouds3DNoise

	//--// Apply coverage

	float falloffCoverage = LinearStep(0.0, 0.3, cloudAltitude) * LinearStep(1.0, 0.7, cloudAltitude);
	      falloffCoverage = falloffCoverage * Clamp01(coverage) + Clamp01(1.0 - coverage);

	density = Clamp01(density + coverage * falloffCoverage - 1.0);
	density = 1.0 - Pow4(1.0 - density);

	return density;
}
float Get3DCloudDensity(vec3 position, float coverage, const int octaves) {
	vec3 corePosition = position + vec3(-cameraPosition.x, atmosphere_planetRadius, -cameraPosition.z);
	return Get3DCloudDensity(position, length(corePosition), coverage, octaves);
}

//--// Optical depth //-------------------------------------------------------//

float Calculate3DCloudsAirmass(vec3 position, vec3 direction, float coverage, const float range, const int steps) {
	float outerDistance = RaySphereIntersection(position + vec3(0.0, atmosphere_planetRadius, 0.0), direction, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX).y;
	float stepSize = min(outerDistance, range) / steps;
	if (stepSize < 0.0) { return 0.0; }

	vec3 increment = direction * stepSize;
	position += increment * 0.5;

	float airmass = 0.0;
	for (int i = 0; i < steps; ++i, position += increment) {
		airmass += Get3DCloudDensity(position, coverage, CLOUDS3D_NOISE_OCTAVES_SHADOW);
	} airmass *= stepSize;

	return airmass;
}
float Calculate3DCloudsAirmass(vec3 position, vec3 direction, float coverage, const int steps) {
	float stepSize = RaySphereIntersection(position + vec3(0.0, atmosphere_planetRadius, 0.0), direction, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX).y / steps;
	if (stepSize < 0.0) { return 0.0; }

	vec3 increment = direction * stepSize;
	position += increment * 0.5;

	float airmass = 0.0;
	for (int i = 0; i < steps; ++i, position += increment) {
		airmass += Get3DCloudDensity(position, coverage, CLOUDS3D_NOISE_OCTAVES_SHADOW);
	} airmass *= stepSize;

	return airmass;
}
float Calculate3DCloudsAirmassUp(vec3 position, float coverage, const int steps) {
	vec3 corePosition = position + vec3(-cameraPosition.x, atmosphere_planetRadius, -cameraPosition.z);
	float coreDistance = length(corePosition);

	float stepSize = (atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX - coreDistance) / steps;
	if (stepSize < 0.0) { return 0.0; }

	vec3 increment = corePosition * stepSize / coreDistance;
	position     += increment * 0.5;
	coreDistance += stepSize * 0.5;

	float airmass = 0.0;
	for (int i = 0; i < steps; ++i, position += increment, coreDistance += stepSize) {
		airmass += Get3DCloudDensity(position, coreDistance, coverage, CLOUDS3D_NOISE_OCTAVES_SHADOW);
	} airmass *= stepSize;

	return airmass;
}

float Calculate3DCloudsOpticalDepth(vec3 position, vec3 direction, float coverage, const float range, const int steps) {
	return CLOUDS3D_ATTENUATION_COEFFICIENT * Calculate3DCloudsAirmass(position, direction, coverage, range, steps);
}
float Calculate3DCloudsOpticalDepth(vec3 position, vec3 direction, float coverage, const int steps) {
	return CLOUDS3D_ATTENUATION_COEFFICIENT * Calculate3DCloudsAirmass(position, direction, coverage, steps);
}
float Calculate3DCloudsOpticalDepthUp(vec3 position, float coverage, const int steps) {
	float airmass = Calculate3DCloudsAirmassUp(position, coverage, steps);
	return CLOUDS3D_ATTENUATION_COEFFICIENT * airmass;
}
float Calculate3DCloudsOpticalDepthUp(vec3 position, float coverage) { // Simpler version
	vec3 corePosition = position + vec3(-cameraPosition.x, atmosphere_planetRadius, -cameraPosition.z);
	float coreDistance = length(corePosition);

	float altitude = coreDistance - atmosphere_planetRadius;
	float airmass = 0.5 * coverage * (CLOUDS3D_THICKNESS + CLOUDS3D_ALTITUDE_MIN - altitude);
	return CLOUDS3D_ATTENUATION_COEFFICIENT * airmass;
}

//--// Lighting //------------------------------------------------------------//

#if PROGRAM == PROGRAM_DEFERRED
	float CloudsPhase(float cosTheta, vec3 g, vec3 w) {
		vec3 gmn2 = -2.0 * g;
		vec3 gg   = g * g;
		vec3 gga1 = 1.0 + gg;
		vec3 p1   = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));

		vec3 res = p1 * (cosTheta * cosTheta + 1.0) * pow(gmn2 * cosTheta + gga1, vec3(-1.5));

		return dot(res, w) / (w.x + w.y + w.z);
	}

	float Calculate3DCloudsSunlight(vec3 position, float coverage, float phase) {
		float opticalDepth = Calculate3DCloudsOpticalDepth(position, shadowLightVector, coverage, CLOUDS3D_SELFSHADOW_RANGE_SUN, CLOUDS3D_SELFSHADOW_STEPS_SUN);

		// TODO: Merge single & multiple scattering, and blend phase function towards isotropic based on optical depth (and scattering albedo)
		float single = phase       * exp(-opticalDepth);
		float multi  = (0.25 / pi) * (1.0 - exp(-CLOUDS3D_SCATTERING_ALBEDO * opticalDepth)) * exp((CLOUDS3D_SCATTERING_ALBEDO - 1.0) * opticalDepth);

		return single + multi;
	}
	float Calcualte3DCloudsSkylight(vec3 position, float coverage) {
		const float phase = 0.25 / pi;

		#ifdef CLOUDS3D_SIMPLE_SKYLIGHT_SHADING
			float opticalDepth = Calculate3DCloudsOpticalDepthUp(position, coverage);
		#else
			float opticalDepth = Calculate3DCloudsOpticalDepthUp(position, coverage, CLOUDS3D_SELFSHADOW_STEPS_SKY);
		#endif

		opticalDepth *= 0.2; // Really inaccurate, but needed to get skylight to look right-ish.

		return phase * exp((CLOUDS3D_SCATTERING_ALBEDO - 1.0) * opticalDepth);
	}

	vec4 Calculate3DClouds(vec3 viewVector, float dither) {
		#ifndef CLOUDS3D
			return vec4(0.0, 0.0, 0.0, 1.0);
		#endif

		const int steps = CLOUDS3D_STEPS;

		const float phaseIsotropic = 0.25 / pi;
		float phaseShadow = CloudsPhase(dot(viewVector, shadowLightVector), vec3(-0.1, 0.3, 0.9), vec3(0.3, 0.6, 0.1));

		float coverage = GetCloudCoverage();

		//--//

		vec3 viewPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

		vec2 outerDistances = RaySphereIntersection(vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MAX);
		if (outerDistances.y <= 0.0) { return vec4(0.0, 0.0, 0.0, 1.0); }
		vec2 innerDistances = RaySphereIntersection(vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN);
		bool innerIntersected = innerDistances.y >= 0.0;

		// Assuming that we're inside the inner sphere
		float startDistance = innerDistances.y;
		float endDistance   = outerDistances.y;

		float stepSize = (endDistance - startDistance) / steps;

		vec3 increment = viewVector * stepSize;
		vec3 position  = increment * dither + (viewPosition + viewVector * startDistance);

		float scatteringSun = 0.0, scatteringSky = 0.0;
		float opticalDepth = 0.0;
		for (int i = 0; i < steps; ++i, position += increment) {
			//--// Optical depth

			float stepDensity = Get3DCloudDensity(position, coverage, CLOUDS3D_NOISE_OCTAVES_VIEW);
			if (stepDensity <= 0.0) { continue; } // Skip steps that would do nothing
			float stepOpticalDepth = CLOUDS3D_ATTENUATION_COEFFICIENT * stepSize * stepDensity;

			//--// Attenuation and unlit scattering

			/* Unoptimized version
			float stepTransmittedFraction = Clamp01((exp((CLOUDS3D_SCATTERING_ALBEDO - 1.0) * stepOpticalDepth) - 1.0) / ((CLOUDS3D_SCATTERING_ALBEDO - 1.0) * stepOpticalDepth)); // Fraction of light scattered in the step towards the viewer that leaves the step
			float stepVisibleFraction     = exp((CLOUDS3D_SCATTERING_ALBEDO - 1.0) * opticalDepth) * stepTransmittedFraction;                                                      // Fraction of light scattered in the step towards the viewer that reaches the viewer

			float stepScatteringUnlit = CLOUDS3D_SCATTERING_ALBEDO * stepOpticalDepth * stepVisibleFraction;
			//*/

			const float c1 = CLOUDS3D_SCATTERING_ALBEDO - 1.0, c2 = 1.0 / (1.0 - CLOUDS3D_SCATTERING_ALBEDO);
			float stepScatteringUnlit = CLOUDS3D_SCATTERING_ALBEDO * exp(c1 * opticalDepth) * (c2 - c2 * exp(c1 * stepOpticalDepth));

			//--// Light and ccumulate

			scatteringSun += stepScatteringUnlit * Calculate3DCloudsSunlight(position, coverage, phaseShadow);
			scatteringSky += stepScatteringUnlit * Calcualte3DCloudsSkylight(position, coverage);
			opticalDepth  += stepOpticalDepth;
		}

		vec3 scattering  = scatteringSun * illuminanceShadowlight;
		     scattering += scatteringSky * skyAmbientUp;

		return vec4(scattering, exp(-opticalDepth));
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

float Calculate3DCloudShadows(vec3 position, float coverage, const int steps) {
	#ifndef CLOUDS3D
		return 1.0;
	#endif

	float innerDistance = RaySphereIntersection(position + vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN).y;
	position += shadowLightVector * innerDistance;

	return exp(-Calculate3DCloudsOpticalDepth(position, shadowLightVector, coverage, steps));
}
float Calculate3DCloudShadows(vec3 position, float coverage) {
	#ifndef CLOUDS3D
		return 1.0;
	#endif

	return Calculate3DCloudShadows(position, coverage, 5);
}
float Calculate3DCloudShadows(vec3 position) {
	#ifndef CLOUDS3D
		return 1.0;
	#endif

	return Calculate3DCloudShadows(position, GetCloudCoverage(), 5);
}

float CalculateAverageCloudTransmittance(float coverage) {
	#ifndef CLOUDS3D
		return 1.0;
	#endif

	/*
	const int samplesDensity  = 100;
	const int samplesAltitude = 100;

	float avgDensity = 0.0, totalWeight = 0.0;
	for (float i = 0.5 / samplesDensity; i < 1.0; i += 1.0 / samplesDensity) {
		float density = pow(i, 10.0);

		for (float altitude = 0.5 / samplesAltitude; altitude < 1.0; altitude += 1.0 / samplesAltitude) {
			float falloffCoverage = LinearStep(0.0, 0.3, altitude) * LinearStep(1.0, 0.7, altitude);
			      falloffCoverage = falloffCoverage * Clamp01(coverage) + Clamp01(1.0 - coverage);

			float densitySample = Clamp01(density + coverage * falloffCoverage - 1.0);
			      densitySample = 1.0 - Pow4(1.0 - densitySample);
			avgDensity += densitySample;
		}
	}
	avgDensity /= samplesDensity * samplesAltitude;

	float upOpticalDepth = avgDensity * CLOUDS3D_ATTENUATION_COEFFICIENT * CLOUDS3D_THICKNESS;

	//return exp(-1.4 * upOpticalDepth); // Uncomment to use the value from directly above, faster but less accurate

	const float or = (CLOUDS3D_ALTITUDE_MAX + atmosphere_planetRadius) / CLOUDS3D_THICKNESS;
	const float ir = (CLOUDS3D_ALTITUDE_MIN + atmosphere_planetRadius) / CLOUDS3D_THICKNESS;
	const float vr = (atmosphere_planetRadius) / CLOUDS3D_THICKNESS;

	const int iterations = 50;
	float transmittance = 0.0;
	for (float theta = hpi * 0.5 / iterations; theta < hpi; theta += hpi / iterations) {
		float cosTheta = cos(theta);
		float dpboth = vr * vr * (cosTheta * cosTheta - 1.0);
		float dRel = sqrt(dpboth + or * or) - sqrt(dpboth + ir * ir); //dRel = 1.0 / cosTheta;
		transmittance += exp(-upOpticalDepth * dRel) * sin(theta);
	}
	return transmittance * hpi / iterations;
	//*/

	//* Average around the player, not actually accurate, but kept as a reference just in case.
	vec3 viewPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

	const ivec2 samples = ivec2(16, 4);

	float transmittance = 0.0;
	for (int x = 0; x < samples.x; ++x) {
		for (int y = 0; y < samples.y; ++y) {
			vec2 xy = (vec2(x, y) + 0.5) / samples;
			xy.y = xy.y * 0.5 + 0.5;
			vec3 dir = GenerateUnitVector(xy).xzy;

			float transmittanceSample = exp(-Calculate3DCloudsOpticalDepth(viewPosition, dir, coverage, 25));
			transmittance += transmittanceSample;
		}
	}
	return transmittance / (samples.x * samples.y);
	//*/
}

#endif
