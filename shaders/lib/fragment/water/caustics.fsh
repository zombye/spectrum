float waterCaustics(vec3 position, float waterDepth) {
	const int   samples           = CAUSTICS_SAMPLES;
	const float radius            = CAUSTICS_RADIUS;
	const float defocus           = CAUSTICS_DEFOCUS;
	const float distanceThreshold = (sqrt(samples) - 1.0) / (radius * defocus);
	const float resultPower       = CAUSTICS_RESULT_POWER;

	vec3  lightVector       = mat3(gbufferModelViewInverse) * -shadowLightVector;
	vec3  flatRefractVector = refract(lightVector, vec3(0.0, 1.0, 0.0), 0.75);
	float surfDistUp        = waterDepth * abs(lightVector.y);
	float dither            = bayer4(gl_FragCoord.st) * 16.0;

	position += cameraPosition;

	vec3 surfacePosition = position - flatRefractVector * (surfDistUp / flatRefractVector.y);

	float result = 0.0;
	for (float i = 0.0; i < samples; i++) {
		vec3 samplePos     = surfacePosition;
		     samplePos.xz += spiralPoint(i * 16.0 + dither, samples * 16.0) * radius;
		vec3 refractVector = refract(lightVector, water_calculateNormal(samplePos), 0.75);
		     samplePos     = refractVector * (surfDistUp / refractVector.y) + samplePos;

		result += 1.0 - clamp01(distance(position, samplePos) * distanceThreshold);
	}

	return pow(result / (defocus * defocus), resultPower);
}

float waterCaustics(vec3 position, vec3 shadowPosition, vec3 shadowCoord) {
	// Checks if there's water on the shadow map at this location
	if (texture2D(shadowcolor1, shadowCoord.st).b > 0.5) return 1.0;

	float waterDepth = texture2D(shadowtex0, shadowCoord.st).r * 2.0 - 1.0;
	      waterDepth = waterDepth * projectionShadowInverse[2].z + projectionShadowInverse[3].z;
	      waterDepth = shadowPosition.z - waterDepth;

	// Make sure we're not in front of the water
	if (waterDepth >= 0.0) return 1.0;

	return waterCaustics(position, waterDepth);
}

float waterCaustics(vec3 position) {
	vec3 shadowPosition = transformPosition(position, shadowModelView);
	vec3 shadowCoord    = transformPosition(shadowPosition, projectionShadow);
	     shadowCoord    = shadows_distortShadowSpace(shadowCoord) * 0.5 + 0.5;

	return waterCaustics(position, shadowPosition, shadowCoord);
}
