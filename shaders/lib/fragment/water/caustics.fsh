float remapRange(float x, float to0, float to1) {
	return (x - to0) / (to1 - to0);
}

float water_causticsSurfDist(float posy, float lm) {
	#ifdef CAUSTICS_ALTERNATE_DEPTH_CALCULATION
	return clamp01(remapRange(lm, 13.0 / 16.0, 2.0 / 16.0)) * -4.0;
	#else
	return posy - 62.9;
	#endif
}

float water_calculateCaustics(vec3 pos, float lightmap) {
	#ifndef CAUSTICS
	return 1.0;
	#endif

	if (lightmap <= 0.0) return 1.0;

	const float radius      = 0.3;
	const float kernel      = 0.5 * (sqrt(CAUSTICS_SAMPLES) - 1.0);
	const float sampleRange = radius / kernel;
	const float distThresh  = kernel / (radius * CAUSTICS_DEFOCUS);

	vec2  noise       = texture2D(noisetex, gl_FragCoord.st / 64.0).rg - 0.5;
	vec3  lightVector = mat3(modelViewInverse) * -shadowLightVector;
	float surfDistUp  = water_causticsSurfDist(pos.y, lightmap);

	vec3 flatRefractVec = refract(lightVector, vec3(0.0, 1.0, 0.0), 0.75);
	vec3 surfPos        = pos - flatRefractVec * (surfDistUp / flatRefractVec.y);

	float result = 0.0;
	for (float i = -kernel; i <= kernel; i += 1.0) {
		for (float j = -kernel; j <= kernel; j += 1.0) {
			vec3 samplePos     = surfPos;
			     samplePos.xz += (vec2(i, j) + noise) * sampleRange;
			vec3 refractVec    = refract(lightVector, water_calculateNormal(samplePos), 0.75);
			     samplePos     = refractVec * (surfDistUp / refractVec.y) + samplePos;

			result += 1.0 - clamp01(distance(pos, samplePos) * distThresh);
		}
	}
	result /= CAUSTICS_DEFOCUS * CAUSTICS_DEFOCUS;

	return result;
}
