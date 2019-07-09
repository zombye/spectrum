#if !defined INCLUDE_FRAGMENT_SPECULARLIGHTING
#define INCLUDE_FRAGMENT_SPECULARLIGHTING

//#define SPECULAR_EXACT_FRESNEL

vec3 CalculateSpecularHighlight(float NdotL, float NdotV, float VdotL, float VdotH, float roughness, vec3 n, vec3 k, float angularRadius) {
	float alpha2 = roughness * roughness;

	vec3 brdf = CalculateSpecularBRDFSphere(NdotL, NdotV, VdotL, VdotH, alpha2, n, k, angularRadius);

	/* NdotL modified to fade to 0 only when the light is fully occluded (rather than when light is only halfway occluded)
	float sinLightRadius = sin(angularRadius);
	return brdf * Clamp01((NdotL + sinLightRadius) / (1.0 + sinLightRadius));
	//*/ return brdf * NdotL;
}

//--//

#if defined PROGRAM_COMPOSITE || defined PROGRAM_WATER || defined PROGRAM_HAND_WATER
	float CalculateReflectionMip(vec3 position, vec3 hitPosition, float roughness) {
		// Simple mip level calculation for SSR.
		float positionalScale = distance(position, hitPosition) / -hitPosition.z; // ray length and perspective divide
		float projectionScale = gbufferProjection[1].y;                           // field of view
		float sampleScale     = viewResolution.y * inversesqrt(SSR_RAY_COUNT);    // resolution and sample count

		// This part should really be specific to the distribution, but just "roughness" works well enough most of the time.
		// If it's gonna be accurate it needs to be a little more complicated though.
		float roughnessScale = roughness;

		return log2(positionalScale * projectionScale * sampleScale * roughnessScale);
	}

	vec3 TraceSsrRay(sampler2D sampler, mat3 position, vec3 rayDirection, float NdotL, float roughness, float skyFade, float dither) {
		vec3 hitPosition       = position[0];
		vec3 hitPositionView   = position[1];
		vec3 hitPositionScene  = position[2];
		vec3 rayDirectionWorld = mat3(gbufferModelViewInverse) * rayDirection;
		bool intersected       = true;

		if (NdotL > 0.0) { // Raytrace if not self-intersecting
			intersected      = RaytraceIntersection(hitPosition, position[1], rayDirection, SSR_RAY_STEPS, SSR_RAY_REFINEMENTS);
			hitPositionView  = intersected ? ScreenSpaceToViewSpace(hitPosition, gbufferProjectionInverse) : rayDirection * 100.0;
			hitPositionScene = mat3(gbufferModelViewInverse) * hitPositionView + gbufferModelViewInverse[3].xyz;
		}

		vec3 result = vec3(0.0);
		if (intersected) {
			//float lod = CalculateReflectionMip(position[1], hitPositionView, roughness);
			result = DecodeRGBE8(textureLod(sampler, hitPosition.xy, 0.0));
		} else if (isEyeInWater == 0) {
			result = texture(colortex6, ProjectSky(rayDirectionWorld)).rgb * skyFade;
		}

		float VdotL = dot(rayDirectionWorld, shadowLightVector);
		if (isEyeInWater == 1) {
			result = CalculateWaterFog(result, position[2], hitPositionScene, rayDirectionWorld, VdotL, skyFade, dither, !intersected);
		} else {
			result = CalculateAirFog(result, position[2], hitPositionScene, rayDirectionWorld, VdotL, skyFade, skyFade, dither, !intersected);
		}

		return result;
	}

	vec3 CalculateEnvironmentReflections(sampler2D sampler, mat3 position, vec3 normal, float NdotV, float roughness, vec3 n, vec3 k, float skyFade, bool isWater, float dither, const float ditherSize) {
		float roughnessSquared = roughness * roughness;
		vec3 viewDirection = normalize(position[1]);
		normal = mat3(gbufferModelView) * normal;

		mat3 rot = GetRotationMatrix(vec3(0, 0, 1), normal);
		vec3 tangentView = viewDirection * rot;

		vec3 reflection = vec3(0.0);
		for (int i = 0; i < SSR_RAY_COUNT; ++i) {
			vec2 xy = vec2(fract((i + dither) * ditherSize * phi) * (1.0 - SSR_TAIL_CLAMP), (i + dither) / SSR_RAY_COUNT);
			vec3 facetNormal = rot * GetFacetGGX(-tangentView, vec2(roughness), xy);

			float MdotV = dot(facetNormal, -viewDirection);
			vec3 rayDirection = viewDirection + 2.0 * MdotV * facetNormal;//reflect(viewDirection, facetNormal);
			float NdotL = abs(dot(normal, rayDirection));

			vec3 reflectionSample = TraceSsrRay(sampler, position, rayDirection, NdotL, roughness, skyFade, dither);

			reflectionSample *= FresnelNonpolarized(MdotV, isEyeInWater == 1 && isWater ? ComplexVec3(vec3(1.333), vec3(0.0)) : ComplexVec3(airMaterial.n, airMaterial.k), ComplexVec3(n, k));
			reflectionSample *= G2OverG1SmithGGX(NdotV, NdotL, roughnessSquared);

			reflection += reflectionSample;
		} reflection /= SSR_RAY_COUNT;

		return reflection;
	}
#endif

#endif
