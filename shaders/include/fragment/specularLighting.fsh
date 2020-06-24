#if !defined INCLUDE_FRAGMENT_SPECULARLIGHTING
#define INCLUDE_FRAGMENT_SPECULARLIGHTING

vec3 CalculateSpecularHighlight(float NdotL, float NdotV, float VdotL, float VdotH, Material material, float angularRadius) {
	float alpha2 = material.roughness * material.roughness;

	vec3 brdf = CalculateSpecularBRDFSphere(NdotL, NdotV, VdotL, VdotH, alpha2, material.n, material.k, angularRadius);

	/* NdotL modified to fade to 0 only when the light is fully occluded (rather than when light is only halfway occluded)
	float sinLightRadius = sin(angularRadius);
	vec3 highlight = brdf * Clamp01((NdotL + sinLightRadius) / (1.0 + sinLightRadius));
	//*/ vec3 highlight = brdf * Clamp01(NdotL);

	if (material.albedoTintsMetalReflections) {
		highlight *= 1.0 - material.metalness + material.metalness * material.albedo;
	}

	return highlight;
}

//--//

#if defined PROGRAM_COMPOSITE || defined PROGRAM_WATER || defined PROGRAM_HAND_WATER
	float EstimateMipLevel(vec3 position, vec3 hitPosition, float sampleDensity /* pdf*sampleCount */) {
		// Approximate solid angle represented by this sample & pixel
		// We only care about the ratio of these so units might be weird
		float sampleSolidAngle = 1.0 / sampleDensity;
		float pixelArea        = 4.0 * Pow2(abs(hitPosition.z) * gbufferProjectionInverse[1].y * viewPixelSize.y);
		float pixelSolidAngle  = pixelArea / dot(hitPosition - position, hitPosition - position);

		//return log2(sqrt(sampleSolidAngle / pixelSolidAngle));
		return 0.5 * log2(sampleSolidAngle / pixelSolidAngle);
	}
	float EstimateMipLevel(vec3 position, vec3 hitPosition, float pdf, int sampleCount) {
		return EstimateMipLevel(position, hitPosition, pdf * sampleCount);
	}

	vec3 TraceSsrRay(sampler2D sampler, mat3 position, vec3 rayDirection, float NdotL, float roughness, float skyFade, float dither) {
		vec3 hitPosition       = position[0];
		vec3 hitPositionView   = position[1];
		vec3 hitPositionScene  = position[2];
		vec3 rayDirectionWorld = mat3(gbufferModelViewInverse) * rayDirection;
		bool intersected       = true;

		if (NdotL > 0.0) { // Raytrace if not self-intersecting
			intersected      = IntersectSSRay(hitPosition, position[1], rayDirection, SSR_RAY_STRIDE);
			hitPositionView  = intersected ? ScreenSpaceToViewSpace(hitPosition, gbufferProjectionInverse) : rayDirection * 100.0;
			hitPositionScene = mat3(gbufferModelViewInverse) * hitPositionView + gbufferModelViewInverse[3].xyz;
		}

		vec3 result = vec3(0.0);
		if (intersected) {
			//float lod = EstimateMipLevel(position[1], hitPositionView, roughness);
			result = DecodeRGBE8(textureLod(sampler, hitPosition.xy, 0.0));
		} else if (isEyeInWater == 0) {
			result = texture(colortex6, ProjectSky(rayDirectionWorld)).rgb * skyFade;
		}

		float VdotL = dot(rayDirectionWorld, shadowLightVector);
		if (isEyeInWater == 1) {
			#if defined VL_WATER && defined SSR_ALLOW_VL_WATER
			result = CalculateWaterFogVL(result, position[2], hitPositionScene, rayDirectionWorld, VdotL, skyFade, dither, !intersected);
			#else
			result = CalculateWaterFog(result, position[2], hitPositionScene, rayDirectionWorld, VdotL, skyFade, dither, !intersected);
			#endif
		} else {
			#if defined VL_AIR && defined SSR_ALLOW_VL_AIR
			result = CalculateAirFogVL(result, position[2], hitPositionScene, rayDirectionWorld, VdotL, skyFade, skyFade, dither, !intersected);
			#else
			result = CalculateAirFog(result, position[2], hitPositionScene, rayDirectionWorld, VdotL, skyFade, skyFade, dither, !intersected);
			#endif
		}

		return result;
	}

	vec3 CalculateEnvironmentReflections(sampler2D sampler, mat3 position, vec3 normal, float NdotV, Material material, float skyFade, bool isWater, float dither, const float ditherSize) {
		float roughnessSquared = material.roughness * material.roughness;
		vec3 viewDirection = normalize(position[1]);
		normal = mat3(gbufferModelView) * normal;

		mat3 rot = GetRotationMatrix(vec3(0, 0, 1), normal);
		vec3 tangentView = viewDirection * rot;

		vec3 reflection = vec3(0.0);
		for (int i = 0; i < SSR_RAY_COUNT; ++i) {
			vec2 xy = R2((i + dither) * ditherSize);
			xy.x *= 1.0 - SSR_TAIL_CLAMP;
			vec3 facetNormal = rot * GetFacetGGX(-tangentView, vec2(material.roughness), xy);

			float MdotV = dot(facetNormal, -viewDirection);
			vec3 rayDirection = viewDirection + 2.0 * MdotV * facetNormal;//reflect(viewDirection, facetNormal);
			float NdotL = abs(dot(normal, rayDirection));

			vec3 reflectionSample = TraceSsrRay(sampler, position, rayDirection, NdotL, material.roughness, skyFade, dither);

			#ifdef TOTAL_INTERNAL_REFLECTION
			reflectionSample *= FresnelNonpolarized(MdotV, isEyeInWater == 1 && isWater ? ComplexVec3(vec3(1.333), vec3(0.0)) : ComplexVec3(airMaterial.n, airMaterial.k), ComplexVec3(material.n, material.k));
			#else
			reflectionSample *= FresnelNonpolarized(MdotV, ComplexVec3(airMaterial.n, airMaterial.k), ComplexVec3(material.n, material.k));
			#endif
			reflectionSample *= G2OverG1SmithGGX(NdotV, NdotL, roughnessSquared);

			reflection += reflectionSample;
		} reflection /= SSR_RAY_COUNT;

		if (material.albedoTintsMetalReflections) {
			reflection *= 1.0 - material.metalness + material.metalness * material.albedo;
		}

		return reflection;
	}
#endif

#endif
