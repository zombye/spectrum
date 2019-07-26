#if !defined INCLUDE_FRAGMENT_SHADOWS
#define INCLUDE_FRAGMENT_SHADOWS

#ifdef SHADOW_COLORED
	vec3 BlendColoredShadow(float shadow0, float shadow1, vec4 shadowC) {
		// Linearization is done here for convenience.
		shadowC.rgb = SrgbToLinear(shadowC.rgb);

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
	vec3 BilinearFilter(vec3 shadowCoord, float distortionFactor, float biasMul, float biasAdd, out float waterFraction, out float waterDepth) {
		// Separate integer & fractional coordinates
		vec2 sampleUv = shadowCoord.xy;
		vec2 iUv, fUv = modf(sampleUv * SHADOW_RESOLUTION + 0.5, iUv);
		sampleUv = iUv / SHADOW_RESOLUTION; // Fixes some small artifacting

		// Bias
		float cmpDepth = shadowCoord.z;
		float bias = 2.0 / (SHADOW_RESOLUTION * Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE));
		cmpDepth += biasMul * bias + biasAdd;

		//--//

		vec4 depth0 = textureGather(shadowtex0, sampleUv);
		vec4 depth1 = textureGather(shadowtex1, sampleUv);

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

		float maxPenumbraRadius = 2.0 * SHADOW_DEPTH_RADIUS * shadowProjection[0].x * tan(lightAngularRadius);
		float searchRadius = SHADOW_FILTER_MAX_RADIUS * shadowProjection[0].x;
		float searchLod = log2(SHADOW_RESOLUTION * 2.0 * searchRadius * inversesqrt(samples));

		float searchCmpMul = 1.0 / maxPenumbraRadius;

		vec2 dir = SinCos(dither * goldenAngle);
		vec2 averageBlockerDistances = vec2(0.0), weightSums = vec2(0.0);
		for (int i = 0; i < samples; ++i, dir *= rotateGoldenAngle) {
			float sampleDist = inversesqrt(samples) * searchRadius * sqrt(i + dither2);

			vec2 sampleUv = sampleDist * dir + position.xy;
			     sampleUv = DistortShadowSpace(sampleUv);
			     sampleUv = sampleUv * 0.5 + 0.5;

			vec2 blockerDistances = referenceDepth - vec2(textureLod(shadowtex0, sampleUv, searchLod).x, textureLod(shadowtex1, sampleUv, searchLod).x);
			vec2 weights = step(0.0, blockerDistances);
			//vec2 weights = vec2(lessThanEqual(vec2(searchCmpMul * sampleDist), blockerDistances));
			//vec2 weights = LinearStep(0.25 * searchCmpMul * sampleDist, searchCmpMul * sampleDist, blockerDistances);

			averageBlockerDistances += blockerDistances * weights;
			weightSums              += weights;
		}

		averageBlockerDistances.x /= weightSums.x > 0.0 ? weightSums.x : 1.0;
		averageBlockerDistances.y /= weightSums.y > 0.0 ? weightSums.y : 1.0;

		vec2 penumbraRadii = maxPenumbraRadius * averageBlockerDistances;
		     penumbraRadii = min(penumbraRadii, searchRadius);

		return penumbraRadii;
	}
	#elif SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
	float FindPenumbraRadius(vec3 position, float dither, float dither2) {
		float referenceDepth = position.z * 0.5 + 0.5;
		float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

		const int samples = SHADOW_SEARCH_SAMPLES;

		float maxPenumbraRadius = abs(2.0 * SHADOW_DEPTH_RADIUS * shadowProjection[0].x * tan(lightAngularRadius));
		float searchRadius = SHADOW_FILTER_MAX_RADIUS * shadowProjection[0].x;
		float searchLod = log2(SHADOW_RESOLUTION * 2.0 * searchRadius * inversesqrt(samples));

		float searchCmpMul = 1.0 / maxPenumbraRadius;

		vec2 dir = SinCos(dither * goldenAngle);
		float averageBlockerDistance = 0.0, weightSum = 0.0;
		for (int i = 0; i < samples; ++i, dir *= rotateGoldenAngle) {
			float sampleDist = searchRadius * inversesqrt(samples) * sqrt(i + dither2);

			vec2 sampleUv = sampleDist * dir + position.xy;
			     sampleUv = DistortShadowSpace(sampleUv);
			     sampleUv = sampleUv * 0.5 + 0.5;

			float blockerDistance = referenceDepth - textureLod(shadowtex1, sampleUv, searchLod).x;
			float weight = step(0.0, blockerDistance);
			//float weight = float(searchCmpMul * sampleDist <= blockerDistance);
			//float weight = LinearStep(0.25 * searchCmpMul * sampleDist, searchCmpMul * sampleDist, blockerDistance);

			averageBlockerDistance += weight * blockerDistance;
			weightSum              += weight;
		}

		if (weightSum <= 0.0) { return 0.0; }

		averageBlockerDistance /= weightSum;

		float penumbraRadius = maxPenumbraRadius * averageBlockerDistance;
		      penumbraRadius = min(penumbraRadius, searchRadius);

		return penumbraRadius;
	}
	#endif

	vec3 PercentageCloserFilter(vec3 position, float biasMul, float biasAdd, float dither, const float ditherSize, out float waterFraction, out float waterDepth) {
		waterFraction = 0.0;
		waterDepth = 0.0;

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

				float distortionFactor0 = CalculateDistortionFactor(sampleUv0);
				float distortionFactor1 = CalculateDistortionFactor(sampleUv1);
				sampleUv0 = sampleUv0 * distortionFactor0 * 0.5 + 0.5;
				sampleUv1 = sampleUv1 * distortionFactor1 * 0.5 + 0.5;

				float bias0 = 1.0 / (SHADOW_RESOLUTION * Pow2(distortionFactor0 * SHADOW_DISTORTION_AMOUNT_INVERSE)) + sampleDist.x;
				float bias1 = 1.0 / (SHADOW_RESOLUTION * Pow2(distortionFactor1 * SHADOW_DISTORTION_AMOUNT_INVERSE)) + sampleDist.y;

				float cmpDepth0 = biasMul * bias0 + referenceDepth;
				float cmpDepth1 = biasMul * bias1 + referenceDepth;

				//--//

				float depth0 = textureLod(shadowtex0, sampleUv0, 0.0).x;
				float depth1 = textureLod(shadowtex1, sampleUv1, 0.0).x;

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
				float distortionFactor = CalculateDistortionFactor(sampleUv);
				sampleUv = sampleUv * distortionFactor * 0.5 + 0.5;

				float bias = 2.0 / (SHADOW_RESOLUTION * Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE)) + sampleDist;

				float cmpDepth = biasMul * bias + referenceDepth;

				//--//

				vec4 depth0 = textureGather(shadowtex0, sampleUv);
				vec4 depth1 = textureGather(shadowtex1, sampleUv);

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

		#if !defined SHADOW_COLORED && (SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS)
			float penumbraFraction = Clamp01(unclampedFilterRadius / filterRadius);
			result = LinearStep(0.5 - 0.5 * penumbraFraction, 0.5 + 0.5 * penumbraFraction, result);
		#endif

		return result;
	}
#elif SHADOW_FILTER == SHADOW_FILTER_EXPERIMENTAL || SHADOW_FILTER == SHADOW_FILTER_EXPERIMENTAL_PCSSASSISTED
	// http://www.mpia.de/~mathar/public/mathar20051002.pdf
	float RectangleSolidAngle(vec2 ab, float d) {
		float aSq = Pow2(ab.x / (2.0 * d));
		float bSq = Pow2(ab.y / (2.0 * d));

		#extension GL_ARB_gpu_shader_fp64 : enable
		double numerator   = 1.0lf + double(aSq + bSq);
		double denominator = (1.0lf + double(aSq)) * (1.0lf + double(bSq));

		return 4.0 * asin(sqrt(Clamp01(float(1.0lf - numerator / denominator))));
	}
	float RectangleSolidAngleOffAxis1(vec2 ab, vec2 AB, float d) {
		// Doesn't cross middle
		float r1 = RectangleSolidAngle(2.0 * vec2(AB.x + ab.x, AB.y + ab.y), d);
		float r2 = RectangleSolidAngle(2.0 * vec2(AB.x + ab.x, AB.y       ), d);
		float r3 = RectangleSolidAngle(2.0 * vec2(AB.x       , AB.y + ab.y), d);
		float r4 = RectangleSolidAngle(2.0 * vec2(AB.x       , AB.y       ), d);
		return (r1 - r2 - r3 + r4) / 4.0;
	}
	float RectangleSolidAngleOffAxis2(vec2 ab, vec2 AB, float d) {
		// Crosses middle on one axis (B)
		float r1 = RectangleSolidAngle(2.0 * vec2(AB.x + ab.x, ab.y - AB.y), d);
		float r2 = RectangleSolidAngle(2.0 * vec2(AB.x       , ab.y - AB.y), d);
		float r3 = RectangleSolidAngle(2.0 * vec2(AB.x + ab.x, AB.y       ), d);
		float r4 = RectangleSolidAngle(2.0 * vec2(AB.x       , AB.y       ), d);
		return (r1 - r2 + r3 - r4) / 4.0;
	}
	float RectangleSolidAngleOffAxis3(vec2 ab, vec2 AB, float d) {
		// Crosses middle on both axis
		float r1 = RectangleSolidAngle(2.0 * vec2(ab.x - AB.x, ab.y - AB.y), d);
		float r2 = RectangleSolidAngle(2.0 * vec2(AB.x       , ab.y - AB.y), d);
		float r3 = RectangleSolidAngle(2.0 * vec2(ab.x - AB.x, AB.y       ), d);
		float r4 = RectangleSolidAngle(2.0 * vec2(AB.x       , AB.y       ), d);
		return (r1 + r2 + r3 + r4) / 4.0;
	}
	float RectangleSolidAngle(vec2 mins, vec2 maxs, float d) {
		bool crossesCenterX = (mins.x >= 0.0) != (maxs.x >= 0.0);
		bool crossesCenterY = (mins.y >= 0.0) != (maxs.y >= 0.0);

		mins = abs(mins);
		maxs = abs(maxs);

		if (mins.x > maxs.x) { float tmp = mins.x; mins.x = maxs.x; maxs.x = tmp; }
		if (mins.y > maxs.y) { float tmp = mins.y; mins.y = maxs.y; maxs.y = tmp; }

		if (crossesCenterX && crossesCenterY) {
			return RectangleSolidAngleOffAxis3(maxs + mins, mins, d);
		} else if (crossesCenterX && !crossesCenterY) {
			return RectangleSolidAngleOffAxis2(vec2(maxs.y - mins.y, maxs.x + mins.x), mins.yx, d);
		} else if (!crossesCenterX && crossesCenterY) {
			return RectangleSolidAngleOffAxis2(vec2(maxs.x - mins.x, maxs.y + mins.y), mins, d);
		} else {
			return RectangleSolidAngleOffAxis1(maxs - mins, mins, d);
		}
	}

	float CalculateTexelSolidAngle(vec3 position, ivec2 texel, float depth, float bias) {
		float depthLin = shadowProjectionInverse[2].z * (depth * SHADOW_DEPTH_SCALE) + shadowProjectionInverse[3].z;

		vec2 p0 = (vec2(texel    ) / float(SHADOW_RESOLUTION)) * 2.0 - 1.0;
		     p0 = Diagonal(shadowProjectionInverse).xy * p0 + shadowProjectionInverse[3].xy;
		vec2 p1 = (vec2(texel + 1) / float(SHADOW_RESOLUTION)) * 2.0 - 1.0;
		     p1 = Diagonal(shadowProjectionInverse).xy * p1 + shadowProjectionInverse[3].xy;

		// approximate
		if (depth - position.z > bias * 2.0) { return 0.0; }

		// check if within cone
		position = Diagonal(shadowProjectionInverse).xyz * position * vec3(1.0,1.0,SHADOW_DEPTH_SCALE) + shadowProjectionInverse[3].xyz;
		vec3 coneCheckPos = vec3(clamp(position.xy, p0, p1), depthLin);

		if (normalize(coneCheckPos - position).z < cos(sunAngularRadius)) { return 0.0; }

		// check if _entirely_ within cone
		if (normalize(vec3(p0, depthLin) - position).z > cos(sunAngularRadius) && normalize(vec3(p1, depthLin) - position).z > cos(sunAngularRadius)) {
			return RectangleSolidAngle(p0 - position.xy, p1 - position.xy, abs(depthLin - position.z));
		}

		// only partially within cone, just using numerical integration (at least for now)
		int q = 5;
		vec2 s = abs(p1 - p0) / q;

		float res = 0.0;
		for (float x = p0.x + s.x / 2.0; x < p1.x; x += s.x) {
			for (float y = p0.y + s.y / 2.0; y < p1.y; y += s.y) {
				vec3 sp = vec3(x, y, depthLin);
				vec3 sv = sp - position;
				float dSq = dot(sv, sv);

				if (abs(sv.z * inversesqrt(dSq)) < cos(sunAngularRadius)) { continue; }

				res += s.x * s.y / dSq;
			}
		}

		return res;
	}

	vec3 ExperimentalVPS(vec3 position, float biasMul, float biasAdd, float dither, const float ditherSize, inout float waterFraction, inout float waterDepth) {
		float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

		float pixelRadiusBase = 1.0 / SHADOW_RESOLUTION;
		float radius          = tan(lightAngularRadius) * /*SHADOW_DEPTH_RADIUS*/16.0 * shadowProjection[0].x;

		ivec2 maxRadiusPixels = ivec2(abs(SHADOW_RESOLUTION * radius)) + 1;

		float lightSolidAngle = ConeAngleToSolidAngle(lightAngularRadius);
		float occluderSolidAngle = 0.0;
		for (int x = -maxRadiusPixels.x; x <= maxRadiusPixels.x; ++x) {
			for (int y = -maxRadiusPixels.y; y <= maxRadiusPixels.y; ++y) {
				ivec2 sampleTexel = ivec2(x, y) + ivec2(floor(SHADOW_RESOLUTION * (position.xy * 0.5 + 0.5)));
				if (sampleTexel.x < 0 || sampleTexel.x > SHADOW_RESOLUTION || sampleTexel.y < 0 || sampleTexel.y > SHADOW_RESOLUTION) { continue; }

				float sampleDepth = texelFetch(shadowtex1, sampleTexel, 0).r;

				float bias = biasMul * pixelRadiusBase + biasAdd;

				occluderSolidAngle += CalculateTexelSolidAngle(position, sampleTexel, sampleDepth * 2.0 - 1.0, bias);
			}
		}
		if (occluderSolidAngle < 0.0) { return vec3(1.0, 0.0, 1.0); }
		float sunVisibility = 1.0 - Clamp01(occluderSolidAngle / lightSolidAngle);

		return vec3(sunVisibility);
	}
#endif

#ifdef SSCS
	float ScreenSpaceContactShadow(mat3 position, float dither) {
		dither = floor(dither * 4.0) * 0.25 + 0.25;

		vec3 direction = ViewSpaceToScreenSpace(shadowLightVectorView * -position[1].z + position[1], gbufferProjection) - position[0];
		#if SSCS_MODE == 1
		     direction = direction * SSCS_STRIDE / MaxOf(abs(direction.xy * viewResolution));
		#else
		     direction = direction * gbufferProjection[1].y * SSCS_STRIDE / MaxOf(abs(direction.xy * viewResolution));
		#endif

		vec3 rayPosition = position[0];

		for (int iteration = 0; iteration < SSCS_SAMPLES; ++iteration) {
			rayPosition   += direction * (iteration == 0 ? dither : 1.0);
			if (clamp(rayPosition, 0.0, 1.0) != rayPosition) break;
			float linDepth = GetLinearDepth(depthtex1, rayPosition.xy);
			float linZPos  = ScreenSpaceToViewSpace(rayPosition.z, gbufferProjectionInverse);

			if (linZPos < linDepth) { // linZPos and linDepth are negative
				float difference  = abs((linDepth - linZPos) / linZPos);
				#if SSCS_MODE == 1
				      difference *= gbufferProjection[1].y;
				#endif

				if (difference < 0.02) { return smoothstep(0.75, 1.0, (iteration + dither) / SSCS_SAMPLES); }
			}
		}

		return 1.0;
	}
#endif

vec3 CalculateShadows(mat3 position, vec3 normal, bool translucent, float dither, const float ditherSize) {
	normal = mat3(shadowModelView) * normal;

	if (normal.z < 0.0 && !translucent) { return vec3(0.0); } // Early-exit

	vec3 shadowView    = mat3(shadowModelView) * position[2] + shadowModelView[3].xyz;
	vec3 shadowClip    = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowView + shadowProjection[3].xyz;
	     shadowClip.z /= SHADOW_DEPTH_SCALE;

	#ifndef SHADOW_INFINITE_RENDER_DISTANCE
		float distanceFade = LinearStep(0.9, 1.0, dot(shadowClip.xy, shadowClip.xy));
		if (distanceFade >= 1.0) { return vec3(1.0); } // Early-exit
	#endif

	float biasMul  = SHADOW_DISTORTION_AMOUNT_INVERSE / (-2.0 * SHADOW_DEPTH_RADIUS);
	      biasMul *= SumOf(abs(normalize(normal.xy)) * vec2(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y));
	      biasMul *= sqrt(Clamp01(1.0 - normal.z * normal.z)) / abs(normal.z);

	// This exists to fix some issues caused by distortion only being per-vertex in the shadow map. If there is no distortion, or distortion properly affected depth, this would just be 0.
	float biasAdd = 0.5 / (-SHADOW_DEPTH_RADIUS * SHADOW_DISTANCE_EFFECTIVE);
	      biasAdd = biasAdd - biasAdd * SHADOW_DISTORTION_AMOUNT_INVERSE;

	vec3 shadowCoord = shadowClip;
	float distortionFactor = CalculateDistortionFactor(shadowClip.xy);
	shadowCoord.xy *= distortionFactor;
	shadowCoord     = shadowCoord * 0.5 + 0.5;

	#if   SHADOW_FILTER == SHADOW_FILTER_NONE
		float waterFraction = step(0.5/255.0, texture(shadowcolor0, shadowCoord.xy).a), waterDepth;
		vec3 shadows; {
			shadowCoord.z += biasMul * (1.0 / (SHADOW_RESOLUTION * Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE))) + biasAdd;

			float depth0 = textureLod(shadowtex0, shadowCoord.xy, 0.0).r;
			float depth1 = textureLod(shadowtex1, shadowCoord.xy, 0.0).r;

			float shadow0 = step(shadowCoord.z, depth0);
			float shadow1 = step(shadowCoord.z, depth1);

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
		vec3 shadows = BilinearFilter(shadowCoord, distortionFactor, biasMul, biasAdd, waterFraction, waterDepth);
	#elif SHADOW_FILTER == SHADOW_FILTER_PCF || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
		float waterFraction, waterDepth;
		vec3 shadows = PercentageCloserFilter(shadowClip, biasMul, biasAdd, dither, ditherSize, waterFraction, waterDepth);
	#elif SHADOW_FILTER == SHADOW_FILTER_EXPERIMENTAL || SHADOW_FILTER == SHADOW_FILTER_EXPERIMENTAL_PCSSASSISTED
		float waterFraction = 0.0, waterDepth = 0.0;
		vec3 shadows = ExperimentalVPS(shadowClip, biasMul, biasAdd, dither, ditherSize, waterFraction, waterDepth);
	#endif

	waterDepth = SHADOW_DEPTH_RADIUS * (shadowCoord.z - waterDepth);
	if (waterFraction > 0) {
		#ifdef UNDERWATER_ADAPTATION
			float fogDensity = isEyeInWater == 1 ? fogDensity : 0.1;
		#else
			const float fogDensity = 0.1;
		#endif
		vec3 attenuationCoefficient = -log(SrgbToLinear(vec3(WATER_TRANSMISSION_R, WATER_TRANSMISSION_G, WATER_TRANSMISSION_B) / 255.0)) / WATER_REFERENCE_DEPTH;
		vec3 waterShadow = exp(-attenuationCoefficient * fogDensity * waterDepth);

		#if   CAUSTICS == CAUSTICS_LOW
			waterShadow *= GetProjectedCaustics(shadowCoord.xy, waterDepth);
		#elif CAUSTICS == CAUSTICS_HIGH
			waterShadow *= CalculateCaustics(shadowView, waterDepth, dither, ditherSize);
		#endif

		shadows *= waterShadow * waterFraction + (1.0 - waterFraction);
	}

	#ifdef SSCS
		if (shadows.r + shadows.g + shadows.b > 0.0 && !translucent) {
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
