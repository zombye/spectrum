#if !defined INCLUDE_SHARED_ATMOSPHERE_DENSITY
#define INCLUDE_SHARED_ATMOSPHERE_DENSITY

vec3 AtmosphereDensity(float centerDistance) {
	vec2 rayleighMie = exp(centerDistance * -atmosphere_inverseScaleHeights + atmosphere_scaledPlanetRadius);

	// Ozone distribution curve by Sergean Sarcasm - https://www.desmos.com/calculator/j0wozszdwa
	float ozone = exp(-max(0.0, (35000.0 - centerDistance) - atmosphere_planetRadius) /  5000.0)
	            * exp(-max(0.0, (centerDistance - 35000.0) - atmosphere_planetRadius) / 15000.0);
	return vec3(rayleighMie, ozone);
}

#endif
