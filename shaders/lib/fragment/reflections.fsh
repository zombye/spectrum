#define REFLECTION_SAMPLES 1 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
#define REFLECTION_QUALITY 4.0
#define REFLECTION_REFINEMENTS 4 // The max number needed depends on your resolution and reflection quality setting.
#define VOLUMETRICCLOUDS_REFLECTED
#define FOG_REFLECTED

float calculateReflectionMipGGX(vec3 view, vec3 normal, vec3 light, float zDistance, float alpha2) {
	vec3 halfVector = normalize(view + light);

	float NoH = dot(normal, halfVector);

	float p = ((NoH * alpha2 - NoH) * NoH + 1.0) * viewHeight;
	return max0(0.25 * log2(4.0 * projection[1].y * zDistance * dot(view, halfVector) * p * p / (REFLECTION_SAMPLES * alpha2 * NoH)));
}

vec3 calculateReflections(mat2x3 position, vec3 viewDirection, vec3 normal, float eta, float roughness, vec2 lightmap, vec3 sunVisibility, float dither) {
	if (eta == 1.0) return vec3(0.0);

	float alpha2 = roughness * roughness;

	vec3 reflection = vec3(0.0);
	#if REFLECTION_SAMPLES > 0
	for (float i = 0.0; i < REFLECTION_SAMPLES; i++) {
		vec3 facetNormal = is_GGX(normal, hash42(vec2(i, dither)), alpha2);
		if (dot(viewDirection, facetNormal) > 0.0) facetNormal = -facetNormal;
		vec3 rayDir = reflect(viewDirection, facetNormal);

		vec3 hitPos;
		bool intersected = raytraceIntersection(position[0], rayDir, hitPos, dither, REFLECTION_QUALITY, REFLECTION_REFINEMENTS);
		vec3 hitPosView = screenSpaceToViewSpace(hitPos, projectionInverse);

		vec3 reflectionSample = vec3(0.0);

		if (intersected) {
			reflectionSample = texture2DLod(gaux1, hitPos.st, calculateReflectionMipGGX(-viewDirection, normal, rayDir, position[1].z - linearizeDepth(hitPos.z, projectionInverse), alpha2)).rgb;
		} else if (lightmap.y > 0.1 && isEyeInWater != 1) {
			reflectionSample = sky_atmosphere(vec3(0.0), rayDir);
			#ifdef FLATCLOUDS
			vec4 flatClouds = flatClouds_calculate(rayDir);
			reflectionSample = reflectionSample * flatClouds.a + flatClouds.rgb;
			#endif
			#ifdef VOLUMETRICCLOUDS_REFLECTED
			vec4 volumetricClouds = volumetricClouds_calculate(position[1], hitPosView, rayDir, !intersected, dither);
			reflectionSample = reflectionSample * volumetricClouds.a + volumetricClouds.rgb;
			#endif
		}

		#ifdef FOG_REFLECTED
		if (isEyeInWater == 1) {
			reflectionSample = waterFog(reflectionSample, position[1], intersected ? hitPosView : rayDir * 1e3, lightmap.y, dither);
		} else {
			reflectionSample = fog(reflectionSample, position[1], intersected ? hitPosView : rayDir * 1e3, lightmap, dither);
		}
		#endif

		reflectionSample *= smoothstep(0.1, 0.9, lightmap.y + float(intersected));
		reflectionSample *= f_dielectric(clamp01(dot(facetNormal, -viewDirection)), eta);

		reflection += reflectionSample;
	} reflection /= REFLECTION_SAMPLES;
	#else
	vec3 rayDir = reflect(viewDirection, normal);
	if (lightmap.y > 0.1) {
		reflection = sky_atmosphere(vec3(0.0), rayDir);

		#ifdef FLATCLOUDS
		vec4 flatClouds = flatClouds_calculate(rayDir);
		reflection = reflection * flatClouds.a + flatClouds.rgb;
		#endif
		#ifdef VOLUMETRICCLOUDS_REFLECTED
		vec4 clouds = volumetricClouds_calculate(position[1], position[1] + rayDir, rayDir, true, dither);
		reflection = reflection * clouds.a + clouds.rgb;
		#endif

		reflection *= smoothstep(0.1, 0.9, lightmap.y);
		reflection *= f_dielectric(clamp01(dot(normal, -viewDirection)), eta);
	}
	#endif

	vec3 slmrp = mrp_sphere(reflect(normalize(position[1]), normal), shadowLightVector, sunAngularRadius);
	reflection += sunVisibility * shadowLightColor * specularBRDF(-normalize(position[1]), normal, slmrp, eta, alpha2);

	return reflection;
}
