#define REFLECTION_SAMPLES 1 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
#define REFLECTION_QUALITY 8.0
#define REFLECTION_REFINEMENTS 4 // The max number needed depends on your resolution and reflection quality setting.
#define VOLUMETRICCLOUDS_REFLECTED // Can have a very high performance impact!

float calculateReflectionMipGGX(vec3 view, vec3 normal, vec3 light, float zDistance, float alpha2) {
	float NoH = dot(normal, normalize(view + light));

	float p = (NoH * alpha2 - NoH) * NoH + 1.0;
	return max0(0.25 * log2(4.0 * projection[1].y * viewHeight * viewHeight * zDistance * dot(view, normalize(view + light)) * p * p / (REFLECTION_SAMPLES * alpha2 * NoH)));
}

vec3 calculateReflections(mat3 position, vec3 viewDirection, vec3 normal, float reflectance, float roughness, float skyLight, vec3 sunVisibility) {
	if (reflectance == 0.0) return vec3(0.0);

	float dither = bayer8(gl_FragCoord.st);

	float ior    = f0ToIOR(reflectance);
	float alpha2 = roughness * roughness;

	vec3 reflection = vec3(0.0);
	for (float i = 0.0; i < REFLECTION_SAMPLES; i++) {
		vec3 facetNormal = is_GGX(normal, hash42(vec2(i, dither)), alpha2);
		if (dot(viewDirection, facetNormal) > 0.0) facetNormal = -facetNormal;
		vec3 rayDir = reflect(viewDirection, facetNormal);

		vec3 hitPos;
		bool intersected = raytraceIntersection(position[0], rayDir, hitPos, dither, REFLECTION_QUALITY, REFLECTION_REFINEMENTS);

		vec3 reflectionSample = vec3(0.0);

		if (intersected) {
			reflectionSample = texture2DLod(colortex2, hitPos.st, calculateReflectionMipGGX(-viewDirection, normal, rayDir, linearizeDepth(hitPos.z, projectionInverse) - position[1].z, alpha2)).rgb;
		} else if (skyLight > 0.1) {
			reflectionSample = sky_atmosphere(vec3(0.0), rayDir);
			#ifdef FLATCLOUDS
			vec4 clouds = flatClouds_calculate(rayDir);
			reflectionSample = reflectionSample * clouds.a + clouds.rgb;
			#endif
			reflectionSample *= smoothstep(0.1, 0.9, skyLight);
		}

		#ifdef VOLUMETRICCLOUDS_REFLECTED
		if (skyLight > 0.1) {
			vec4 clouds = volumetricClouds_calculate(position[1], screenSpaceToViewSpace(hitPos, projectionInverse), rayDir, !intersected);
			clouds = mix(vec4(0.0, 0.0, 0.0, 1.0), clouds, smoothstep(0.1, 0.9, skyLight));
			reflectionSample = reflectionSample * clouds.a + clouds.rgb;
		}
		#endif

		reflectionSample *= f_dielectric(max0(dot(facetNormal, -viewDirection)), 1.0, ior);

		reflection += reflectionSample;
	} reflection /= REFLECTION_SAMPLES;

	vec3 slmrp = mrp_sphere(reflect(normalize(position[1]), normal), shadowLightVector, sunAngularRadius);
	reflection += sunVisibility * shadowLightColor * specularBRDF(-normalize(position[1]), normal, slmrp, reflectance, alpha2);

	return reflection;
}
