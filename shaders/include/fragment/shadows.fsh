#if !defined INCLUDE_FRAGMENT_SHADOWS
#define INCLUDE_FRAGMENT_SHADOWS

#ifdef SHADOW_COLORED
	vec3 BlendColoredShadow(float shadow0, float shadow1, vec4 shadowC) {
		// Linearization is done here for convenience.
		shadowC.rgb = LinearFromSrgb(shadowC.rgb);

		// Best looking method I've found so far.
		return (shadowC.rgb * shadowC.a - shadowC.a) * (-shadow1 * shadow0 + shadow1) + shadow1;
	}

	vec3 ReadShadowMaps(vec3 shadowCoord) {
		float shadow0 = step(shadowCoord.z, textureLod(shadowtex0, shadowCoord.st, 0.0).r);
		float shadow1 = step(shadowCoord.z, textureLod(shadowtex1, shadowCoord.st, 0.0).r);
		vec4  shadowC = textureLod(shadowcolor1, shadowCoord.st, 0.0);

		return BlendColoredShadow(shadow0, shadow1, shadowC);
	}

	vec3 ReadShadowMapsBilinear(vec3 shadowCoord) {
		shadowCoord.xy = shadowCoord.xy * SHADOW_RESOLUTION - 0.5;
		ivec2 i = ivec2(floor(shadowCoord.xy));
		vec2 f = shadowCoord.xy - i;

		vec4 samples0 = step(shadowCoord.z, textureGather(shadowtex0, vec2(i) / SHADOW_RESOLUTION + (1.0 / SHADOW_RESOLUTION)));
		vec4 samples1 = step(shadowCoord.z, textureGather(shadowtex1, vec2(i) / SHADOW_RESOLUTION + (1.0 / SHADOW_RESOLUTION)));

		vec3 c0 = BlendColoredShadow(samples0.x, samples1.x, texelFetch(shadowcolor1, i + ivec2(0, 1), 0));
		vec3 c1 = BlendColoredShadow(samples0.y, samples1.y, texelFetch(shadowcolor1, i + ivec2(1, 1), 0));
		vec3 c2 = BlendColoredShadow(samples0.z, samples1.z, texelFetch(shadowcolor1, i + ivec2(1, 0), 0));
		vec3 c3 = BlendColoredShadow(samples0.w, samples1.w, texelFetch(shadowcolor1, i + ivec2(0, 0), 0));

		return mix(mix(c3, c2, f.x), mix(c0, c1, f.x), f.y);
	}
#else
	float ReadShadowMaps(vec3 shadowCoord) {
		return step(shadowCoord.z, textureLod(shadowtex1, shadowCoord.st, 0.0).r);
	}

	float ReadShadowMapsBilinear(vec3 shadowCoord) {
		shadowCoord.xy = shadowCoord.xy * SHADOW_RESOLUTION - 0.5;
		ivec2 i = ivec2(floor(shadowCoord.xy));
		vec2 f = shadowCoord.xy - i;

		vec4 samples = step(shadowCoord.z, textureGather(shadowtex1, vec2(i) / SHADOW_RESOLUTION + (1.0 / SHADOW_RESOLUTION)));

		return mix(mix(samples.w, samples.z, f.x), mix(samples.x, samples.y, f.x), f.y);
	}
#endif

#if   SHADOW_FILTER == SHADOW_FILTER_BILINEAR
	vec3 BilinearFilter(vec3 shadowCoord, float distortionFactor, float distortionDerivative, float biasMul, float biasAdd, out float waterFraction, out float waterDepth, out float avgDepth) {
		// Separate integer & fractional coordinates
		vec2 sampleUv = shadowCoord.xy;
		vec2 iUv, fUv = modf(sampleUv * SHADOW_RESOLUTION + 0.5, iUv);
		sampleUv = iUv / SHADOW_RESOLUTION; // Fixes some small artifacting

		// Bias
		float cmpDepth = shadowCoord.z;
		float bias = 2.0 / (SHADOW_RESOLUTION * distortionDerivative);
		cmpDepth += biasMul * bias + biasAdd;

		//--//

		vec4 depth0 = textureGather(shadowtex0, sampleUv);
		vec4 depth1 = textureGather(shadowtex1, sampleUv);
		avgDepth = SumOf(depth1);

		vec4 shadow0 = step(cmpDepth, depth0);
		vec4 shadow1 = step(cmpDepth, depth1);
		vec4 valid   = shadow1 - shadow0 * shadow1;
		vec4 isWater = step(0.5/255.0, textureGather(shadowcolor0, sampleUv, 3)) * valid;

		waterFraction  = SumOf(isWater);
		waterDepth     = SumOf(isWater * depth0) / waterFraction;
		waterFraction /= max(SumOf(valid), 1);


		#ifdef SHADOW_COLORED
			vec3 c0 = BlendColoredShadow(shadow0.x, shadow1.x, texelFetch(shadowcolor1, ivec2(iUv - vec2(1, 0)), 0));
			vec3 c1 = BlendColoredShadow(shadow0.y, shadow1.y, texelFetch(shadowcolor1, ivec2(iUv - vec2(0, 0)), 0));
			vec3 c2 = BlendColoredShadow(shadow0.z, shadow1.z, texelFetch(shadowcolor1, ivec2(iUv - vec2(0, 1)), 0));
			vec3 c3 = BlendColoredShadow(shadow0.w, shadow1.w, texelFetch(shadowcolor1, ivec2(iUv - vec2(1, 1)), 0));

			return mix(mix(c3, c2, fUv.x), mix(c0, c1, fUv.x), fUv.y);
		#else
			return vec3(mix(mix(shadow1.w, shadow1.z, fUv.x), mix(shadow1.x, shadow1.y, fUv.x), fUv.y));
		#endif
	}
#elif SHADOW_FILTER == SHADOW_FILTER_PCF || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
	#if defined SHADOW_COLORED && SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
	vec2 FindPenumbraRadius(vec3 position, float dither, float dither2) {
		float referenceDepth = position.z * 0.5 + 0.5;
		float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

		const int samples = SHADOW_SEARCH_SAMPLES;

		float maxPenumbraRadius = abs(2.0 * SHADOW_DEPTH_RADIUS * shadowProjection[0].x * tan(lightAngularRadius));
		float searchRadius = min(maxPenumbraRadius * referenceDepth, SHADOW_FILTER_MAX_RADIUS * shadowProjection[0].x);
		float searchLod = log2(SHADOW_RESOLUTION * 2.0 * searchRadius * inversesqrt(samples));

		const float overestimationPrevention = 0.125; // 0 to 1
		float searchCmpMul = overestimationPrevention / maxPenumbraRadius;
		float searchCmpClamp = searchRadius * inversesqrt(samples);

		vec2 blockerDepths = vec2(referenceDepth);
		vec2 dir = SinCos(dither * goldenAngle);
		for (int i = 0; i < samples; ++i, dir *= rotateGoldenAngle) {
			float sampleDist = inversesqrt(samples) * searchRadius * sqrt(i + dither2);

			vec2 sampleUv = sampleDist * dir + position.xy;
			     sampleUv = DistortShadowSpace(sampleUv);
			     sampleUv = sampleUv * 0.5 + 0.5;

			vec2 depths = vec2(textureLod(shadowtex0, sampleUv, searchLod).x, textureLod(shadowtex1, sampleUv, searchLod).x);

			bvec2 validBlocker = lessThanEqual(depths, vec2(referenceDepth - searchCmpMul * max(sampleDist, searchCmpClamp)));
			blockerDepths = mix(blockerDepths, min(blockerDepths, depths), validBlocker);
		}

		vec2 blockerDistances = referenceDepth - blockerDepths;

		vec2 penumbraRadii = maxPenumbraRadius * blockerDistances;
		     penumbraRadii = min(penumbraRadii, searchRadius);

		return penumbraRadii;
	}
	#elif SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
	float FindPenumbraRadius(vec3 position, float dither, float dither2) {
		float referenceDepth = position.z * 0.5 + 0.5;
		float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

		const int samples = SHADOW_SEARCH_SAMPLES;

		float maxPenumbraRadius = abs(2.0 * SHADOW_DEPTH_RADIUS * shadowProjection[0].x * tan(lightAngularRadius));
		float searchRadius = min(maxPenumbraRadius * referenceDepth, SHADOW_FILTER_MAX_RADIUS * shadowProjection[0].x);
		float searchLod = log2(SHADOW_RESOLUTION * 2.0 * searchRadius * inversesqrt(samples));

		const float overestimationPrevention = 0.125; // 0 to 1
		float searchCmpMul = overestimationPrevention / maxPenumbraRadius;
		float searchCmpClamp = searchRadius * inversesqrt(samples);

		float blockerDepth = referenceDepth;
		vec2 dir = SinCos(dither * goldenAngle);
		for (int i = 0; i < samples; ++i, dir *= rotateGoldenAngle) {
			float sampleDist = searchRadius * inversesqrt(samples) * sqrt(i + dither2);

			vec2 sampleUv = sampleDist * dir + position.xy;
			     sampleUv = DistortShadowSpace(sampleUv);
			     sampleUv = sampleUv * 0.5 + 0.5;

			float depth = textureLod(shadowtex1, sampleUv, searchLod).x;

			bool validBlocker = depth <= referenceDepth - searchCmpMul * max(sampleDist, searchCmpClamp);
			blockerDepth = validBlocker ? min(blockerDepth, depth) : blockerDepth;
		}

		float blockerDistance = referenceDepth - blockerDepth;

		float penumbraRadius = maxPenumbraRadius * blockerDistance;
		      penumbraRadius = min(penumbraRadius, searchRadius);

		return penumbraRadius;
	}
	#endif

	vec3 PercentageCloserFilter(vec3 position, float biasMul, float biasAdd, float dither, const float ditherSize, out float waterFraction, out float waterDepth, out float avgDepth) {
		waterFraction = 0.0;
		waterDepth = 0.0;
		avgDepth = 0.0;

		//--//

		const int samples = SHADOW_FILTER_SAMPLES;

		dither = dither * ditherSize + 0.5;
		float dither2 = dither / ditherSize;

		#if   defined SHADOW_COLORED && SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
			vec2 filterRadius = FindPenumbraRadius(position, dither, dither2);
			filterRadius = max(filterRadius, 4.0 / SHADOW_RESOLUTION / SHADOW_DISTANCE_EFFECTIVE);
		#elif SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
			float filterRadius = FindPenumbraRadius(position, dither, dither2);
			#if !defined SHADOW_COLORED
			float unclampedFilterRadius = filterRadius;
			#endif
			filterRadius = max(filterRadius, 4.0 / SHADOW_RESOLUTION / SHADOW_DISTANCE_EFFECTIVE);
		#else
			float filterRadius = 4.0 / SHADOW_RESOLUTION / SHADOW_DISTANCE_EFFECTIVE;
		#endif

		float referenceDepth = position.z * 0.5 + 0.5 + biasAdd;

		vec3 result = vec3(0.0);
		float validSamples = 0.0;
		vec2 dir = SinCos(dither * goldenAngle);
		for (int i = 0; i < samples; ++i, dir *= rotateGoldenAngle) {
			#if defined SHADOW_COLORED && SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
				vec2 sampleDist = filterRadius * inversesqrt(samples) * sqrt(i + dither2);

				vec2 sampleUv0 = sampleDist.x * dir + position.xy;
				vec2 sampleUv1 = sampleDist.y * dir + position.xy;

				float distortionDerivative0 = CalculateDistortionDerivative(sampleUv0);
				float distortionDerivative1 = CalculateDistortionDerivative(sampleUv1);
				float distortionFactor0 = CalculateDistortionFactor(sampleUv0);
				float distortionFactor1 = CalculateDistortionFactor(sampleUv1);
				sampleUv0 = sampleUv0 * distortionFactor0 * 0.5 + 0.5;
				sampleUv1 = sampleUv1 * distortionFactor1 * 0.5 + 0.5;

				float bias0 = 1.0 / (SHADOW_RESOLUTION * distortionDerivative0) + sampleDist.x;
				float bias1 = 1.0 / (SHADOW_RESOLUTION * distortionDerivative1) + sampleDist.y;

				float cmpDepth0 = biasMul * bias0 + referenceDepth;
				float cmpDepth1 = biasMul * bias1 + referenceDepth;

				//--//

				float depth0 = textureLod(shadowtex0, sampleUv0, 0.0).x;
				float depth1 = textureLod(shadowtex1, sampleUv1, 0.0).x;
				avgDepth += depth1;

				float shadow0 = step(cmpDepth0, depth0);
				float shadow1 = step(cmpDepth1, depth1);

				float valid    = shadow1 - shadow0 * shadow1;
				float isWater  = valid * step(0.5/255.0, textureLod(shadowcolor0, sampleUv0, 0.0).a);
				waterDepth    += isWater * depth0;
				waterFraction += isWater;
				validSamples  += valid;

				vec4 shadowC = textureLod(shadowcolor1, sampleUv0, 0.0);
				result += BlendColoredShadow(shadow0, shadow1, shadowC);
			#else
				float sampleDist = filterRadius * inversesqrt(samples) * sqrt(i + dither2);

				vec2 sampleUv = sampleDist * dir + position.xy;
				float distortionDerivative = CalculateDistortionDerivative(sampleUv);
				float distortionFactor = CalculateDistortionFactor(sampleUv);
				sampleUv = sampleUv * distortionFactor * 0.5 + 0.5;

				float bias = 2.0 / (SHADOW_RESOLUTION * distortionDerivative) + sampleDist;

				float cmpDepth = biasMul * bias + referenceDepth;

				//--//

				vec4 depth0 = textureGather(shadowtex0, sampleUv);
				vec4 depth1 = textureGather(shadowtex1, sampleUv);
				avgDepth += SumOf(depth1) / 4.0;

				vec4 shadow0 = step(cmpDepth, depth0);
				vec4 shadow1 = step(cmpDepth, depth1);

				vec4 valid     = shadow1 - shadow0 * shadow1;
				vec4 isWater   = valid * step(0.5/255.0, textureGather(shadowcolor0, sampleUv, 3));
				waterDepth    += SumOf(isWater * depth0);
				waterFraction += SumOf(isWater);
				validSamples  += SumOf(valid);

				vec2 iUv, fUv = modf(sampleUv * SHADOW_RESOLUTION + 0.5, iUv);

				#ifdef SHADOW_COLORED
					vec3 s0 = BlendColoredShadow(shadow0.x, shadow1.x, texelFetch(shadowcolor1, ivec2(iUv - vec2(1, 0)), 0));
					vec3 s1 = BlendColoredShadow(shadow0.y, shadow1.y, texelFetch(shadowcolor1, ivec2(iUv - vec2(0, 0)), 0));
					vec3 s2 = BlendColoredShadow(shadow0.z, shadow1.z, texelFetch(shadowcolor1, ivec2(iUv - vec2(0, 1)), 0));
					vec3 s3 = BlendColoredShadow(shadow0.w, shadow1.w, texelFetch(shadowcolor1, ivec2(iUv - vec2(1, 1)), 0));
					result += mix(mix(s3, s2, fUv.x), mix(s0, s1, fUv.x), fUv.y);
				#else
					result += mix(mix(shadow1.w, shadow1.z, fUv.x), mix(shadow1.x, shadow1.y, fUv.x), fUv.y);
				#endif
			#endif
		}
		waterDepth /= waterFraction;
		waterFraction /= validSamples;

		result /= samples;
		avgDepth /= samples;

		#if !defined SHADOW_COLORED && (SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS)
			float penumbraFraction = Clamp01(unclampedFilterRadius / filterRadius);
			result = LinearStep(0.5 - 0.5 * penumbraFraction, 0.5 + 0.5 * penumbraFraction, result);
		#endif

		return result;
	}
#endif

#ifdef SSCS
	float ScreenSpaceContactShadow(mat3 position, float dither) {
		const uint stride = SSCS_STRIDE;
		const uint maxSteps = SSCS_SAMPLES;

		vec3 rayStep  = position[1] + abs(position[1].z) * shadowLightVectorView;
		     rayStep  = ViewSpaceToScreenSpace(rayStep, gbufferProjection) - position[0];
		     rayStep *= MinOf((step(0.0, rayStep) - position[0]) / rayStep);

		position[0].xy *= viewResolution;
		rayStep.xy *= viewResolution;

		rayStep /= abs(abs(rayStep.x) < abs(rayStep.y) ? rayStep.y : rayStep.x);

		vec2 stepsToEnd = (step(0.0, rayStep.xy) * viewResolution - position[0].xy) / rayStep.xy;
		uint maxLoops = min(uint(ceil(min(min(stepsToEnd.x, stepsToEnd.y), MaxOf(viewResolution)) / float(stride))), maxSteps);

		vec3 startPosition = position[0];

		bool hit = false;
		float ditherp = floor(stride * fract(Bayer8(gl_FragCoord.xy) + frameR1) + 1.0);
		for (uint i = 0u; i < maxLoops && !hit; ++i) {
			float pixelSteps = float(i * stride) + ditherp;
			position[0] = startPosition + pixelSteps * rayStep;

			// Z at current step & one step towards -Z
			float maxZ = position[0].z;
			float minZ = rayStep.z > 0.0 && i == 0u ? startPosition.z : position[0].z - float(stride) * abs(rayStep.z);

			if (1.0 < minZ || maxZ < 0.0) { break; }

			// Requiring intersection from BOTH interpolated & noninterpolated depth prevents pretty much all false occlusion.
			float depth = texelFetch(depthtex1, ivec2(position[0].xy), 0).r;
			float ascribedDepth = AscribeDepth(depth, 1e-2 * (i == 0u ? ditherp : float(stride)) * gbufferProjectionInverse[1].y);
			float depthInterp = ViewSpaceToScreenSpace(GetLinearDepth(depthtex1, position[0].xy * viewPixelSize), gbufferProjection);
			float ascribedDepthInterp = AscribeDepth(depthInterp, 1e-2 * (i == 0u ? ditherp : float(stride)) * gbufferProjectionInverse[1].y);

			hit = maxZ >= depth && minZ <= ascribedDepth
			&& maxZ >= depthInterp && minZ <= ascribedDepthInterp
			&& depth > 0.65 && depth < 1.0; // don't count hand and sky (todo: allow hits on hand when ray starts on hand)
		}

		return float(!hit);
	}
#endif

vec3 CalculateShadows(mat3 position, vec3 normal, bool translucent, float dither, const float ditherSize, out float sssDepth) {
	normal = mat3(shadowModelView) * normal;

	if (normal.z < 0.0 && !translucent) { return vec3(0.0); } // Early-exit

	vec3 shadowView    = mat3(shadowModelView) * position[2] + shadowModelView[3].xyz;
	vec3 shadowClip    = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowView + shadowProjection[3].xyz;
	     shadowClip.z /= SHADOW_DEPTH_SCALE;

	#ifndef SHADOW_INFINITE_RENDER_DISTANCE
		float distanceFade = LinearStep(0.9, 1.0, dot(shadowClip.xy, shadowClip.xy));
		if (distanceFade >= 1.0) { return vec3(1.0); } // Early-exit
	#endif

	float biasMul  = 1.0 / (-2.0 * SHADOW_DEPTH_RADIUS);
	      biasMul *= SumOf(abs(normalize(normal.xy)) * vec2(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y));
	      biasMul *= sqrt(Clamp01(1.0 - normal.z * normal.z)) / abs(normal.z);

	// This exists to fix some issues caused by distortion only being per-vertex in the shadow map. If there is no distortion, or distortion properly affected depth, this would just be 0.
	float biasAdd = 0.5 / (-SHADOW_DEPTH_RADIUS * SHADOW_DISTANCE_EFFECTIVE);
	      biasAdd = biasAdd - biasAdd * SHADOW_DISTORTION_AMOUNT_INVERSE;

	vec3 shadowCoord = shadowClip;
	float distortionDerivative = CalculateDistortionDerivative(shadowClip.xy);
	float distortionFactor = CalculateDistortionFactor(shadowClip.xy);
	shadowCoord.xy *= distortionFactor;
	shadowCoord     = shadowCoord * 0.5 + 0.5;

	#if   SHADOW_FILTER == SHADOW_FILTER_NONE
		float waterFraction = step(0.5/255.0, texture(shadowcolor0, shadowCoord.xy).a), waterDepth;
		vec3 shadows; {
			shadowCoord.z += biasMul * (1.0 / (SHADOW_RESOLUTION * distortionDerivative)) + biasAdd;

			float depth0 = textureLod(shadowtex0, shadowCoord.xy, 0.0).r;
			float depth1 = textureLod(shadowtex1, shadowCoord.xy, 0.0).r;

			float shadow0 = step(shadowCoord.z, depth0);
			float shadow1 = step(shadowCoord.z, depth1);

			sssDepth = depth1;

			waterDepth = depth0;
			waterFraction *= shadow1 - shadow0 * shadow1;

			#ifdef SHADOW_COLORED
				shadows = BlendColoredShadow(shadow0, shadow1, textureLod(shadowcolor1, shadowCoord.xy, 0.0));
			#else
				shadows = vec3(shadow1);
			#endif
		}
	#elif SHADOW_FILTER == SHADOW_FILTER_BILINEAR
		float waterFraction, waterDepth;
		vec3 shadows = BilinearFilter(shadowCoord, distortionFactor, distortionDerivative, biasMul, biasAdd, waterFraction, waterDepth, sssDepth);
	#elif SHADOW_FILTER == SHADOW_FILTER_PCF || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
		float waterFraction, waterDepth;
		vec3 shadows = PercentageCloserFilter(shadowClip, biasMul, biasAdd, dither, ditherSize, waterFraction, waterDepth, sssDepth);
	#endif

	sssDepth = 2.0 * SHADOW_DEPTH_RADIUS * (shadowCoord.z - sssDepth);

	waterDepth = 2.0 * SHADOW_DEPTH_RADIUS * (shadowCoord.z - waterDepth);
	if (waterFraction > 0) {
		#ifdef UNDERWATER_ADAPTATION
			float fogDensity = isEyeInWater == 1 ? fogDensity : 0.1;
		#else
			const float fogDensity = 0.1;
		#endif
		vec3 attenuationCoefficient = -log(LinearFromSrgb(vec3(WATER_TRANSMISSION_R, WATER_TRANSMISSION_G, WATER_TRANSMISSION_B) / 255.0)) / WATER_REFERENCE_DEPTH;
		vec3 waterShadow = exp(-attenuationCoefficient * fogDensity * waterDepth);

		#if   CAUSTICS == CAUSTICS_LOW
			waterShadow *= GetProjectedCaustics(shadowCoord.xy, waterDepth);
		#elif CAUSTICS == CAUSTICS_HIGH
			waterShadow *= CalculateCaustics(shadowView, waterDepth, dither, ditherSize);
		#endif

		shadows *= waterShadow * waterFraction + (1.0 - waterFraction);
	}

	#ifdef SSCS
		if (shadows.r + shadows.g + shadows.b > 0.0) {
			shadows *= ScreenSpaceContactShadow(position, dither);
		}
	#endif

	#ifdef SHADOW_INFINITE_RENDER_DISTANCE
		return shadows;
	#else
		return mix(shadows, vec3(1.0), distanceFade);
	#endif
}

#endif
