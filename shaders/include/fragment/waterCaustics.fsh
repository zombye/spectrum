#if !defined INCLUDE_FRAGMENT_WATERCAUSTICS
#define INCLUDE_FRAGMENT_WATERCAUSTICS

vec3 GetWaterNormal(vec3 position) {
	position    = mat3(shadowModelView) * position + shadowModelView[3].xyz;
	position.xy = vec2(shadowProjection[0].x, shadowProjection[1].y) * position.xy + shadowProjection[3].xy;

	vec4 normalSample = texture(shadowcolor0, DistortShadowSpace(position.xy) * 0.5 + 0.5);
	normalSample.xyz = DecodeNormal(normalSample.xy * 2.0 - 1.0);

	return normalSample.a < 1.0 ? vec3(0.0, 1.0, 0.0) : normalSample.xyz;
}

#ifdef CAUSTICS_DISPERSION
#define CausticsReturnType vec3
#else
#define CausticsReturnType float
#endif

CausticsReturnType CalculateCaustics(vec3 position, float waterDepth, float dither, const float ditherSize) {
	if (waterDepth <= 0.0) { return CausticsReturnType(1.0); }

	float radius               = CAUSTICS_RADIUS * waterDepth;
	float invDistanceThreshold = sqrt(CAUSTICS_SAMPLES / pi) * CAUSTICS_FOCUS / radius;

	dither = dither * ditherSize + 0.5;

	vec3  flatRefractVector = refract(-shadowLightVector, vec3(0.0, 1.0, 0.0), 0.75);
	float surfDistUp        = waterDepth * abs(shadowLightVector.y);

	vec3 flatRefraction = flatRefractVector * surfDistUp / abs(flatRefractVector.y);
	vec3 surfacePosition = position - flatRefraction;

	CausticsReturnType result = CausticsReturnType(0.0);
	for (int i = 0; i < CAUSTICS_SAMPLES; ++i) {
		vec3 samplePos     = surfacePosition;
		#ifdef CAUSTICS_DITHERED
		     samplePos.xz += CircleMap(i * ditherSize + dither, CAUSTICS_SAMPLES * ditherSize) * radius;
		#else
		     samplePos.xz += CircleMap(i + 0.5, CAUSTICS_SAMPLES) * radius;
		#endif

		vec3 waterNormal = GetWaterNormal(samplePos + flatRefraction);

		#ifdef CAUSTICS_DISPERSION
			vec3 refractVectorR = refract(-shadowLightVector, waterNormal, 0.75 - CAUSTICS_DISPERSION_AMOUNT);
			vec3 refractVectorG = refract(-shadowLightVector, waterNormal, 0.75);
			vec3 refractVectorB = refract(-shadowLightVector, waterNormal, 0.75 + CAUSTICS_DISPERSION_AMOUNT);
			//vec3 refractVectorR = refract(-shadowLightVector, waterNormal, 1 / 1.331);
			//vec3 refractVectorG = refract(-shadowLightVector, waterNormal, 1 / 1.334);
			//vec3 refractVectorB = refract(-shadowLightVector, waterNormal, 1 / 1.338);
			vec3 samplePosR = refractVectorR * (surfDistUp / abs(refractVectorR.y)) + samplePos;
			vec3 samplePosG = refractVectorG * (surfDistUp / abs(refractVectorG.y)) + samplePos;
			vec3 samplePosB = refractVectorB * (surfDistUp / abs(refractVectorB.y)) + samplePos;

			vec3 distances = vec3(
				distance(position, samplePosR),
				distance(position, samplePosG),
				distance(position, samplePosB)
			);

			result += Clamp01(1.0 - distances * invDistanceThreshold);
		#else
			vec3 refractVector = refract(-shadowLightVector, waterNormal, 0.75);
			samplePos = refractVector * (surfDistUp / abs(refractVector.y)) + samplePos;

			result += Clamp01(1.0 - distance(position, samplePos) * invDistanceThreshold);
		#endif
	}

	result *= CAUSTICS_FOCUS * CAUSTICS_FOCUS;
	return pow(result, CausticsReturnType(CAUSTICS_POWER));
}

#undef CausticsReturnType

#endif
