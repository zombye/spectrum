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
		// Bias
		float pixelRadiusBase = 0.5 / SHADOW_RESOLUTION;
		shadowCoord.z += 2.0 * biasMul * (pixelRadiusBase / Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE)) + biasAdd;

		// Separate integer & fractional coordinates
		shadowCoord.xy = shadowCoord.xy * SHADOW_RESOLUTION + 0.5;

		ivec2 i = ivec2(shadowCoord.xy);
		vec2  f = shadowCoord.xy - i;

		//
		vec2 samplePos = vec2(i) / SHADOW_RESOLUTION;

		vec4 samples0 = textureGather(shadowtex0, samplePos);

		vec4 visible0 = step(shadowCoord.z, samples0);
		vec4 visible1 = step(shadowCoord.z, textureGather(shadowtex1, samplePos));
		vec4 valid    = visible1 - visible0 * visible1;
		vec4 isWater  = textureGather(shadowcolor0, samplePos, 3) * valid;

		waterFraction  = SumOf(isWater);
		waterDepth     = SumOf(samples0 * isWater) / waterFraction;
		waterFraction /= SumOf(valid);

		#ifdef SHADOW_COLORED
			vec3 c0 = BlendColoredShadow(visible0.x, visible1.x, texelFetch(shadowcolor1, i - ivec2(1, 0), 0));
			vec3 c1 = BlendColoredShadow(visible0.y, visible1.y, texelFetch(shadowcolor1, i - ivec2(0, 0), 0));
			vec3 c2 = BlendColoredShadow(visible0.z, visible1.z, texelFetch(shadowcolor1, i - ivec2(0, 1), 0));
			vec3 c3 = BlendColoredShadow(visible0.w, visible1.w, texelFetch(shadowcolor1, i - ivec2(1, 1), 0));

			return mix(mix(c3, c2, f.x), mix(c0, c1, f.x), f.y);
		#else
			return vec3(mix(mix(visible1.w, visible1.z, f.x), mix(visible1.x, visible1.y, f.x), f.y));
		#endif
	}
#elif SHADOW_FILTER == SHADOW_FILTER_PCF
	vec3 PercentageCloserFilter(vec3 position, float biasMul, float biasAdd, float dither, const float ditherSize, out float waterFraction, out float waterDepth) {
		const int filterSamples = SHADOW_FILTER_SAMPLES;

		dither = dither * ditherSize + 0.5;
		float dither2 = dither / ditherSize;

		float pixelRadiusBase = 1.0 / SHADOW_RESOLUTION;
		float filterRadius = 4.0 * pixelRadiusBase * SHADOW_DISTORTION_AMOUNT_INVERSE;

		float refZ = position.z * 0.5 + 0.5 + biasAdd;

		vec3 result = vec3(0.0);
		waterFraction = 0.0, waterDepth = 0.0; float validSamples = 0.0;
		vec2 dir = SinCos(dither * goldenAngle);
		for (int i = 0; i < filterSamples; ++i) {
			vec2 sampleOffset = dir * sqrt((i + dither2) / filterSamples) * filterRadius;
			dir *= rotateGoldenAngle;

			vec3 sampleCoord;
			     sampleCoord.xy = sampleOffset + position.xy;

			float distortionFactor = CalculateDistortionFactor(sampleCoord.xy);
			sampleCoord.xy = (sampleCoord.xy * distortionFactor) * 0.5 + 0.5;

			float bias = pixelRadiusBase / Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE) + filterRadius;

			sampleCoord.z = biasMul * bias + refZ;

			//--//

			// Separate integer & fractional coordinates
			sampleCoord.xy = sampleCoord.xy * SHADOW_RESOLUTION + 0.5;

			ivec2 ip = ivec2(sampleCoord.xy);
			vec2  fp = sampleCoord.xy - ip;

			//
			vec2 samplePos = vec2(ip) / SHADOW_RESOLUTION;

			vec4 samples0 = textureGather(shadowtex0, samplePos);

			vec4 visible0 = step(sampleCoord.z, samples0);
			vec4 visible1 = step(sampleCoord.z, textureGather(shadowtex1, samplePos));
			vec4 valid = visible1 - visible0 * visible1;
			vec4 isWater = textureGather(shadowcolor0, samplePos, 3) * valid;

			waterFraction += SumOf(isWater);
			waterDepth    += SumOf(samples0 * isWater);
			validSamples  += SumOf(valid);

			#ifdef SHADOW_COLORED
				vec3 c0 = BlendColoredShadow(visible0.x, visible1.x, texelFetch(shadowcolor1, ip - ivec2(1, 0), 0));
				vec3 c1 = BlendColoredShadow(visible0.y, visible1.y, texelFetch(shadowcolor1, ip - ivec2(0, 0), 0));
				vec3 c2 = BlendColoredShadow(visible0.z, visible1.z, texelFetch(shadowcolor1, ip - ivec2(0, 1), 0));
				vec3 c3 = BlendColoredShadow(visible0.w, visible1.w, texelFetch(shadowcolor1, ip - ivec2(1, 1), 0));

				return mix(mix(c3, c2, fp.x), mix(c0, c1, fp.x), fp.y);
			#else
				result += mix(mix(visible1.w, visible1.z, fp.x), mix(visible1.x, visible1.y, fp.x), fp.y);
			#endif
		} result /= filterSamples;

		waterDepth    /= waterFraction;
		waterFraction /= validSamples;

		return result;
	}
#elif SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
	vec3 PercentageCloserSoftShadows(vec3 position, vec3 shadowCoord, float distortionFactor, float biasMul, float biasAdd, float dither, const float ditherSize, out float waterFraction, out float waterDepth) {
		const int filterSamples = SHADOW_FILTER_SAMPLES;
		const int searchSamples = SHADOW_SEARCH_SAMPLES;

		float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

		dither = dither * ditherSize + 0.5;
		float dither2 = dither / ditherSize;

		vec2 initialDir = SinCos(dither * goldenAngle);

		float refZ = position.z * 0.5 + 0.5;

		//--// Blocker search

		//const float searchScale  = 0.01; float searchRadius = spread * searchScale; // search radius as multiple of max possible radius
		float searchRadius = SHADOW_FILTER_MAX_RADIUS * shadowProjection[0].x; // search radius as number of blocks
		float searchLod    = log2(2.0 * SHADOW_RESOLUTION * searchRadius * inversesqrt(searchSamples));
		float searchCmpMul = searchRadius / (tan(lightAngularRadius) * SHADOW_DEPTH_RADIUS);

		#if defined SHADOW_COLORED && SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
			vec2 averageBlockerDepth = vec2(0.0), validSamples = vec2(0.0);
		#else
			float averageBlockerDepth = 0.0, validSamples = 0.0;
		#endif
		vec2 dir = initialDir;
		for (int i = 0; i < searchSamples; ++i) {
			vec2 sampleOffset = dir * sqrt((i + dither2) / searchSamples);
			dir *= rotateGoldenAngle;

			vec2 sampleCoord = DistortShadowSpace(sampleOffset * searchRadius + position.xy);
			sampleCoord = sampleCoord * 0.5 + 0.5;

			#if defined SHADOW_COLORED && SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
				vec2 sampleDepth = refZ - vec2(textureLod(shadowtex0, sampleCoord, searchLod).r, textureLod(shadowtex1, sampleCoord, searchLod).r);
				vec2 validSample = step(length(sampleOffset) * searchCmpMul, sampleDepth);
				averageBlockerDepth += sampleDepth * validSample;
				validSamples += validSample;
			#else
				float sampleDepth = refZ - textureLod(shadowtex1, sampleCoord, searchLod).r;
				float validSample = step(length(sampleOffset) * searchCmpMul, sampleDepth);
				averageBlockerDepth += sampleDepth * validSample;
				validSamples += validSample;
			#endif
		}

		averageBlockerDepth /= Clamp01(1.0 - validSamples) + validSamples;

		//--// Filter

		float spread = tan(lightAngularRadius) * SHADOW_DEPTH_RADIUS * shadowProjection[0].x; // this could be moved to be part of the filter section

		float pixelRadiusBase = 1.0 / SHADOW_RESOLUTION;
		#ifdef SHADOW_COLORED
			#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
				vec2 filterRadius = averageBlockerDepth * spread * 2.0;
			#else
				float filterRadius = averageBlockerDepth * spread * 2.0;
			#endif

			#if defined SHADOW_FILTER_MIN_RADIUS_LIMITED
				filterRadius = clamp(filterRadius, 4.0 * pixelRadiusBase * SHADOW_DISTORTION_AMOUNT_INVERSE, 0.5 * searchRadius);
			#else
				filterRadius = min(filterRadius, 0.5 * searchRadius);
			#endif
		#else
			float penumbraSize = averageBlockerDepth * spread * 2.0;
			float filterRadius = clamp(penumbraSize, 4.0 * pixelRadiusBase * SHADOW_DISTORTION_AMOUNT_INVERSE, 0.5 * searchRadius);
		#endif

		refZ += biasAdd;

		vec3 result = vec3(0.0);
		#if !defined SHADOW_COLORED || SHADOW_FILTER != SHADOW_FILTER_DUAL_PCSS
			waterFraction = 0.0, waterDepth = 0.0, validSamples = 0.0;
		#endif
		dir = initialDir;
		for (int i = 0; i < filterSamples; ++i) {
			vec2 sampleOffset = dir * sqrt((i + dither2) / filterSamples);
			dir *= rotateGoldenAngle;

			#if defined SHADOW_COLORED && SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
				vec2 sampleCoordTransp = sampleOffset * filterRadius.x + position.xy;
				vec2 sampleCoordOpaque = sampleOffset * filterRadius.y + position.xy;

				float distortionFactorTransp = CalculateDistortionFactor(sampleCoordTransp);
				float distortionFactorOpaque = CalculateDistortionFactor(sampleCoordOpaque);
				sampleCoordTransp = (sampleCoordTransp * distortionFactorTransp) * 0.5 + 0.5;
				sampleCoordOpaque = (sampleCoordOpaque * distortionFactorOpaque) * 0.5 + 0.5;

				float biasTransp = pixelRadiusBase / Pow2(distortionFactorTransp * SHADOW_DISTORTION_AMOUNT_INVERSE) + filterRadius.x;
				float biasOpaque = pixelRadiusBase / Pow2(distortionFactorOpaque * SHADOW_DISTORTION_AMOUNT_INVERSE) + filterRadius.y;

				float shadow0 = step(biasMul * biasTransp + refZ, textureLod(shadowtex0, sampleCoordTransp, 0.0).r);
				float shadow1 = step(biasMul * biasOpaque + refZ, textureLod(shadowtex1, sampleCoordOpaque, 0.0).r);
				vec4  shadowC = textureLod(shadowcolor1, sampleCoordTransp, 0.0);
				      shadowC.rgb = SrgbToLinear(shadowC.rgb);

				result += (shadowC.rgb * shadowC.a - shadowC.a) * (-shadow1 * shadow0 + shadow1) + shadow1;
			#else
				vec3 sampleCoord;
				     sampleCoord.xy = sampleOffset * filterRadius + position.xy;

				float distortionFactor = CalculateDistortionFactor(sampleCoord.xy);
				sampleCoord.xy = (sampleCoord.xy * distortionFactor) * 0.5 + 0.5;

				float bias = pixelRadiusBase / Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE) + filterRadius;

				sampleCoord.z = biasMul * bias + refZ;

				//--//

				// Separate integer & fractional coordinates
				sampleCoord.xy = sampleCoord.xy * SHADOW_RESOLUTION + 0.5;

				ivec2 ip = ivec2(sampleCoord.xy);
				vec2  fp = sampleCoord.xy - ip;

				//
				vec2 samplePos = vec2(ip) / SHADOW_RESOLUTION;

				vec4 samples0 = textureGather(shadowtex0, samplePos);

				vec4 visible0 = step(sampleCoord.z, samples0);
				vec4 visible1 = step(sampleCoord.z, textureGather(shadowtex1, samplePos));
				vec4 valid = visible1 - visible0 * visible1;
				vec4 isWater = textureGather(shadowcolor0, samplePos, 3) * valid;

				waterFraction += SumOf(isWater);
				waterDepth    += SumOf(samples0 * isWater);
				validSamples  += SumOf(valid);

				#ifdef SHADOW_COLORED
					vec3 c0 = BlendColoredShadow(visible0.x, visible1.x, texelFetch(shadowcolor1, ip - ivec2(1, 0), 0));
					vec3 c1 = BlendColoredShadow(visible0.y, visible1.y, texelFetch(shadowcolor1, ip - ivec2(0, 0), 0));
					vec3 c2 = BlendColoredShadow(visible0.z, visible1.z, texelFetch(shadowcolor1, ip - ivec2(0, 1), 0));
					vec3 c3 = BlendColoredShadow(visible0.w, visible1.w, texelFetch(shadowcolor1, ip - ivec2(1, 1), 0));

					result += mix(mix(c3, c2, fp.x), mix(c0, c1, fp.x), fp.y);
				#else
					result += mix(mix(visible1.w, visible1.z, fp.x), mix(visible1.x, visible1.y, fp.x), fp.y);
				#endif
			#endif
		} result /= filterSamples;

		#if !defined SHADOW_COLORED || SHADOW_FILTER != SHADOW_FILTER_DUAL_PCSS
			waterDepth    /= waterFraction;
			waterFraction /= validSamples;
		#else
			shadowCoord.z += biasMul * (0.5 * pixelRadiusBase / Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE)) + biasAdd;

			waterFraction = texture(shadowcolor0, shadowCoord.xy).a;

			float sample0 = texture(shadowtex0, shadowCoord.xy).r;
			waterDepth = sample0;

			float visible0 = step(shadowCoord.z, sample0);
			float visible1 = step(shadowCoord.z, texture(shadowtex1, shadowCoord.xy).r);

			waterFraction *= (visible1 - visible0 * visible1);
		#endif

		#ifndef SHADOW_COLORED
			float penumbraFraction = Clamp01(penumbraSize / filterRadius);
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

		position = Diagonal(shadowProjectionInverse).xyz * position * vec3(1.0,1.0,SHADOW_DEPTH_SCALE) + shadowProjectionInverse[3].xyz;
		vec3 coneCheckPos = vec3(clamp(position.xy, p0, p1), depthLin);

		if (normalize(coneCheckPos - position).z < cos(sunAngularRadius)) { return 0.0; }

		return RectangleSolidAngle(p0 - position.xy, p1 - position.xy, abs(depthLin - position.z));
	}

	vec3 ExperimentalVPS(vec3 position, float biasMul, float biasAdd, float dither, const float ditherSize, out float waterFraction) {
		const int samples = 128;

		float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;
		const float maxRadius    = 0.1;
		float weight             = pow(maxRadius / tan(lightAngularRadius), 2.0) / samples;

		dither = dither * ditherSize + 0.5;

		float pixelRadiusBase = 1.0 / SHADOW_RESOLUTION;
		float radius          = maxRadius * shadowProjection[0].x;

		//*
		float lightSolidAngle = ConeAngleToSolidAngle(lightAngularRadius);

		ivec2 maxRadiusPixels = ivec2(abs(SHADOW_RESOLUTION * radius)) + 1;
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
		//*/

		/*
		float sunVisibility = 1.0;
		for (int i = 0; i < samples; ++i) {
			vec2 sampleOffset = CircleMap(i * ditherSize + dither, samples * ditherSize);

			vec3 occluderPos; occluderPos.xy = sampleOffset * radius + position.xy;
			float distortionFactor = CalculateDistortionFactor(occluderPos.xy);
			     occluderPos.z = texelFetch(shadowtex1, ivec2(((occluderPos.xy * distortionFactor) * 0.5 + 0.5) * SHADOW_RESOLUTION), 0).r * 2.0 - 1.0;

			vec3  occluderVec             = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, -SHADOW_DEPTH_RADIUS) * (occluderPos - position);
			float occluderDistanceSquared = dot(occluderVec, occluderVec);

			if (occluderVec.z * inversesqrt(occluderDistanceSquared) < cos(lightAngularRadius)) { continue; }

			float bias = biasMul * ((pixelRadiusBase / (distortionFactor * distortionFactor)) + length(sampleOffset) * radius) + biasAdd;

			if (occluderPos.z - position.z > bias) { continue; }

			sunVisibility -= max(weight / occluderDistanceSquared, 1.0 / samples);
		} sunVisibility = max(sunVisibility, 0.0);
		//*/

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

	float biasMul  = SHADOW_DISTORTION_AMOUNT_INVERSE / -SHADOW_DEPTH_RADIUS;
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
		float waterFraction = texture(shadowcolor0, shadowCoord.xy).a, waterDepth;
		vec3 shadows; {
			float pixelRadiusBase = 0.5 / SHADOW_RESOLUTION;

			shadowCoord.z += biasMul * (pixelRadiusBase / Pow2(distortionFactor * SHADOW_DISTORTION_AMOUNT_INVERSE)) + biasAdd;

			float sample0 = texture(shadowtex0, shadowCoord.xy).r;
			waterDepth = sample0;

			float visible0 = step(shadowCoord.z, sample0);
			float visible1 = step(shadowCoord.z, texture(shadowtex1, shadowCoord.xy).r);
			waterFraction *= visible1 - visible0 * visible1;

			#ifdef SHADOW_COLORED
				shadows = BlendColoredShadow(visible0, visible1, textureLod(shadowcolor1, shadowCoord.xy, 0.0));
			#else
				shadows = vec3(visible1);
			#endif
		}
	#elif SHADOW_FILTER == SHADOW_FILTER_BILINEAR
		float waterFraction, waterDepth;
		vec3 shadows = BilinearFilter(shadowCoord, distortionFactor, biasMul, biasAdd, waterFraction, waterDepth);
	#elif SHADOW_FILTER == SHADOW_FILTER_PCF
		float waterFraction, waterDepth;
		vec3 shadows = PercentageCloserFilter(shadowClip, biasMul, biasAdd, dither, ditherSize, waterFraction, waterDepth);
	#elif SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
		float waterFraction, waterDepth;
		vec3 shadows = PercentageCloserSoftShadows(shadowClip, shadowCoord, distortionFactor, biasMul, biasAdd, dither, ditherSize, waterFraction, waterDepth);
	#elif SHADOW_FILTER == SHADOW_FILTER_EXPERIMENTAL || SHADOW_FILTER == SHADOW_FILTER_EXPERIMENTAL_PCSSASSISTED
		float waterFraction = 0.0;
		vec3 shadows = ExperimentalVPS(shadowClip, biasMul, biasAdd, dither, ditherSize, waterFraction, waterDepth);
	#endif

	waterDepth = SHADOW_DEPTH_RADIUS * (shadowCoord.z - waterDepth);
	if (waterFraction > 0) {
		#ifdef UNDERWATER_ADAPTATION
			float fogDensity = isEyeInWater == 1 ? fogDensity : 0.1;
		#else
			const float fogDensity = 0.1;
		#endif
		vec3 waterShadow = exp(-vec3(WATER_ATTENUATION_R, WATER_ATTENUATION_G, WATER_ATTENUATION_B) * fogDensity * waterDepth);

		#ifdef CAUSTICS
			waterShadow *= CalculateCaustics(position[2], waterDepth, dither, ditherSize) * waterFraction + (1.0 - waterFraction);
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
