#if !defined INCLUDE_FRAGMENT_CLOUDS2D
#define INCLUDE_FRAGMENT_CLOUDS2D

#define CLOUDS2D_SELFSHADOW_QUALITY 3 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]

#define CLOUDS2D_COVERAGE 0.63 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1]

#define CLOUDS2D_USE_WORLD_TIME

#define CLOUDS2D_ALTITUDE 4000
#define CLOUDS2D_THICKNESS 500

#define CLOUDS2D_ATTENUATION_COEFFICIENT 0.002
#define CLOUDS2D_SCATTERING_ALBEDO 0.99

//--// Shape //---------------------------------------------------------------//

vec2 Clouds2DNoise(vec2 coord) {
	return TextureCubic(noisetex, coord / 256.0).xy;
}

/*
Gives the Jacobian matrix for the above function
n in, m out -> m*n matrix
in glsl, you would lay your partial derivatives out like this:
matmxn(
	do1/di1, ... dom/di1,
	...
	d01/din, ... dom/din, 
);
in glsl, note that what looks like rows in code is actually the columns
*/
mat2 Clouds2DNoiseJacobian(vec2 coord) {
	ivec2 res = textureSize(noisetex, 0);
	return mat2(TextureCubicJacobian(noisetex, coord / res)) * mat2(1.0 / res.x, 0.0, 0.0, 1.0 / res.y);
}
vec2 Clouds2DDistortion(vec2 position, float cloudsTime) {
	vec2 distortionPosition = position;
	const int distortionOctaves = 5;
	const float alpha = 1.6;
	const float distortionFreqGain = 3.0;

	vec2 distortionNoise = Clouds2DNoise(distortionPosition - 0.5 * cloudsTime) * 2.0 - 1.0;
	for (int i = 0; i < distortionOctaves; ++i) {
		float f = pow(distortionFreqGain, i);
		vec2 noisePosition = f * (distortionPosition - 0.5 * cloudsTime * sqrt(i + 1.0));
		float weight = 1.0 / pow(f, alpha);
		distortionNoise += weight * (Clouds2DNoise(noisePosition) * 2.0 - 1.0);
	}

	return distortionNoise;
}
mat2 Clouds2DDistortionJacobian(vec2 position, float cloudsTime) {
	vec2 distortionPosition = position;
	const int distortionOctaves = 5;
	const float alpha = 1.6;
	const float distortionFreqGain = 3.0;

	mat2 distortionNoise = Clouds2DNoiseJacobian(distortionPosition - 0.5 * cloudsTime) * 2.0;
	for (int i = 0; i < distortionOctaves; ++i) {
		float f = pow(distortionFreqGain, i);
		vec2 noisePosition = f * (distortionPosition - 0.5 * cloudsTime * sqrt(i + 1.0));
		float weight = 1.0 / pow(f, alpha);
		distortionNoise += weight * (f * Clouds2DNoiseJacobian(noisePosition) * 2.0);
	}

	return distortionNoise;
}

float Get2DCloudsDensity(vec2 position, float cloudsTime) {
	vec2 distortionNoise = Clouds2DDistortion(position * 1e-4, cloudsTime);

	const float distortionAmt = 0.5;

	mat2 matrix = mat2(1.0) + distortionAmt * Clouds2DDistortionJacobian(position * 1e-4, cloudsTime);
	float distortionArea = abs(determinant(matrix));

	const int octaves = 6;
	const float alpha = 0.7;
	const float freqGain = 3.0;

	vec2 noisePosition = position * 1e-4 + distortionNoise * distortionAmt + 97.0;
	float noise = GetNoise(noisetex, noisePosition - cloudsTime).x;
	float weightSum = 1.0;
	mat2 rot = freqGain * rotateGoldenAngle;
	for (int i = 1; i < octaves; ++i) {
		float f = pow(freqGain, i);
		vec2 noisePosition = rot * (noisePosition - cloudsTime * sqrt(i + 1.0));
		float weight = 1.0 / pow(f, alpha);
		noise += GetNoise(noisetex, noisePosition).x * weight;
		weightSum += weight;
		rot *= freqGain * rotateGoldenAngle;
	} noise /= weightSum;

	float density = Clamp01(noise + CLOUDS2D_COVERAGE - 1.0);
	density = 2.0 * density * density;
	density *= distortionArea;
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

vec3 Calculate2DCloudsScattering(vec3 position, vec3 lowerPosition, vec3 viewVector, float viewRayLength, float density, float cloudsTime, float dither) {
	const float upperAltitude = CLOUDS2D_ALTITUDE + CLOUDS2D_THICKNESS / 2.0;
	const float lowerAltitude = CLOUDS2D_ALTITUDE - CLOUDS2D_THICKNESS / 2.0;

	position.y += atmosphere_planetRadius;

	float rayLength3D = RaySphereIntersection(lowerPosition, shadowLightVector, atmosphere_planetRadius + upperAltitude).y;
	vec3 rayVector  = lowerPosition;
	     rayVector += shadowLightVector * rayLength3D;
	     rayVector += viewVector * RaySphereIntersection(rayVector, viewVector, atmosphere_planetRadius + lowerAltitude).y;
	     rayVector  = rayVector - lowerPosition;

	float stepSizeShadowing = rayLength3D / CLOUDS2D_SELFSHADOW_QUALITY;

	float stepSize          = viewRayLength / CLOUDS2D_SELFSHADOW_QUALITY;
	float stepCoefficient   = CLOUDS2D_ATTENUATION_COEFFICIENT * density;
	float stepOpticalDepth  = stepCoefficient * stepSize;

	float VdotL = dot(viewVector, shadowLightVector);

	float stepTransmittance = exp(-stepOpticalDepth);
	float stepScattering    = CLOUDS2D_SCATTERING_ALBEDO * (1.0 - stepTransmittance);
	float densityMult       = CLOUDS2D_ATTENUATION_COEFFICIENT * stepSizeShadowing;

	vec2 rayStep     = rayVector.xz / CLOUDS2D_SELFSHADOW_QUALITY;
	vec2 rayPosition = rayStep * dither + position.xz;

	float scattering = 0.0, lightOpticalDepth = 0.0;
	for (int i = 0; i < CLOUDS2D_SELFSHADOW_QUALITY; ++i) {
		scattering *= stepTransmittance;

		lightOpticalDepth += densityMult * Get2DCloudsDensity(rayPosition, cloudsTime);

		const float scatterStrength = 1.0, slope = 1.0;
		scattering += stepScattering * pow(1.0 + slope * scatterStrength * lightOpticalDepth, -1.0 / scatterStrength);

		rayPosition += rayStep;
	}

	vec3 lightColor  = sunAngle < 0.5 ? sunIlluminance : moonIlluminance;
	     lightColor *= AtmosphereTransmittance(transmittanceLut, position, shadowLightVector);
	     lightColor *= 0.25/pi * (0.5 * exp(-10.0 * stepCoefficient)) + CloudsPhase2(VdotL, vec3(-0.1, 0.3, 0.9), vec3(0.3, 0.6, 0.1));

	return scattering * lightColor;
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
	vec3 lowerPosition = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0) + viewVector * startDistance;

	#ifdef CLOUDS2D_USE_WORLD_TIME
		float cloudsTime = (worldDay % 128 + worldTime / 24000.0);
	#else
		float cloudsTime = (1.0 / 1200.0) * frameTimeCounter;
	#endif
	cloudsTime *= 0.2 * TIME_SCALE;
	cloudsTime *= 72.0;

	float density = Get2DCloudsDensity(centerPosition.xz, cloudsTime);
	if (density <= 0.0) { return vec4(vec3(0.0), 1.0); }

	float viewRayLength = endDistance - startDistance;

	vec3 scattering = Calculate2DCloudsScattering(centerPosition, lowerPosition, viewVector, viewRayLength, density, cloudsTime, dither);
	float transmittance = exp(-CLOUDS2D_ATTENUATION_COEFFICIENT * density * viewRayLength);

	return vec4(scattering, transmittance);
}

#endif
