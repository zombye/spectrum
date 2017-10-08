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

	const float radius     = 0.3;
	const float distThresh = (sqrt(CAUSTICS_SAMPLES) - 1.0) / (radius * CAUSTICS_DEFOCUS);

	vec3  lightVector = mat3(modelViewInverse) * -shadowLightVector;
	float surfDistUp  = water_causticsSurfDist(pos.y, lightmap);
	float dither      = bayer8(gl_FragCoord.st) * 16.0;

	vec3 flatRefractVec = refract(lightVector, vec3(0.0, 1.0, 0.0), 0.75);
	vec3 surfPos        = pos - flatRefractVec * (surfDistUp / flatRefractVec.y);

	float result = 0.0;
	for (float i = 0.0; i < CAUSTICS_SAMPLES; i++) {
		vec3 samplePos     = surfPos;
		     samplePos.xz += spiralPoint(i * 16.0 + dither, CAUSTICS_SAMPLES * 16.0) * radius;
		vec3 refractVec    = refract(lightVector, water_calculateNormal(samplePos), 0.75);
		     samplePos     = refractVec * (surfDistUp / refractVec.y) + samplePos;

		result += 1.0 - clamp01(distance(pos, samplePos) * distThresh);
	}
	result /= CAUSTICS_DEFOCUS * CAUSTICS_DEFOCUS;

	return result;
}
