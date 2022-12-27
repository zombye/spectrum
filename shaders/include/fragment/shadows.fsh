#if !defined INCLUDE_FRAGMENT_SHADOWS
#define INCLUDE_FRAGMENT_SHADOWS

#if SHADOW_FILTER == SHADOW_FILTER_BILINEAR || SHADOW_FILTER == SHADOW_FILTER_BICUBIC
void SampleShadowmapBilinear(
	vec3 positionShadowDistorted,
	float shadowDepthBias,
	#ifdef SHADOW_COLORED
	out float pcfShadow0,
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	out float mean0,
	out float meanSq0,
	#endif
	#endif
	out float pcfShadow1,
	out float mean1
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	,
	out float meanSq1
	#endif
	#ifdef SHADOW_COLORED
	,
	out vec3 color
	#endif
) {
	vec2 i = floor(positionShadowDistorted.xy);
	vec2 f = positionShadowDistorted.xy - i;
	
	positionShadowDistorted.xy = i / textureSize(shadowtex0, 0) + (1.0 / textureSize(shadowtex0, 0));

	#ifdef SHADOW_COLORED
		vec4 diffs0   = textureGather(shadowtex0, positionShadowDistorted.xy) - positionShadowDistorted.z;
		vec4 thresh0  = step(shadowDepthBias, diffs0);
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		vec4 diffsSq0 = diffs0 * diffs0;
		#endif

		pcfShadow0 = mix(mix(thresh0.w,  thresh0.z,  f.x), mix(thresh0.x,  thresh0.y,  f.x), f.y);
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		mean0      = mix(mix(diffs0.w,   diffs0.z,   f.x), mix(diffs0.x,   diffs0.y,   f.x), f.y);
		meanSq0    = mix(mix(diffsSq0.w, diffsSq0.z, f.x), mix(diffsSq0.x, diffsSq0.y, f.x), f.y);
		#endif
	#endif

	vec4 diffs1   = textureGather(shadowtex1, positionShadowDistorted.xy) - positionShadowDistorted.z;
	vec4 thresh1  = step(shadowDepthBias, diffs1);
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	vec4 diffsSq1 = diffs1 * diffs1;
	#endif

	pcfShadow1 = mix(mix(thresh1.w,  thresh1.z,  f.x), mix(thresh1.x,  thresh1.y,  f.x), f.y);
	mean1      = mix(mix(diffs1.w,   diffs1.z,   f.x), mix(diffs1.x,   diffs1.y,   f.x), f.y);
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	meanSq1    = mix(mix(diffsSq1.w, diffsSq1.z, f.x), mix(diffsSq1.x, diffsSq1.y, f.x), f.y);
	#endif

	#ifdef SHADOW_COLORED
		vec4[4] colors;
		for (int i = 0; i < 4; ++i) {
			if (diffs0[i] != diffs1[i]) {
				vec2 io = vec2(i == 1 || i == 2, i == 0 || i == 1);
				colors[i] = texture(shadowcolor1, positionShadowDistorted.xy + (io - 0.5) / textureSize(shadowcolor1, 0));
				colors[i].rgb = LinearFromSrgb(colors[i].rgb);
				#if defined USE_R2020
				colors[i].rgb *= R709ToRgb_unlit;
				#endif
				colors[i].rgb = colors[i].rgb * colors[i].a + 1.0 - colors[i].a;
			} else {
				colors[i].rgb = vec3(thresh1[i]);
			}
		}

		color = mix(mix(colors[3].rgb, colors[2].rgb, f.x), mix(colors[0].rgb, colors[1].rgb, f.x), f.y);
	#endif
}
#elif SHADOW_FILTER == SHADOW_FILTER_PCF
void SampleShadowmapPCF(
	vec3 positionShadowProjected,
	vec3 positionShadowDistorted,
	float shadowDepthBias,
	float dither,
	float ditherSize,

	out float waterFraction,
	out float waterDepth,

	#ifdef SHADOW_COLORED
	out float pcfShadow0,
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	out float mean0,
	out float meanSq0,
	#endif
	#endif
	out float pcfShadow1,
	out float mean1
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	,
	out float meanSq1
	#endif
	#ifdef SHADOW_COLORED
	,
	out vec3 color
	#endif
) {
	#ifdef SHADOW_COLORED
	pcfShadow0 = 0.0;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	mean0 = 0.0;
	meanSq0 = 0.0;
	#endif
	#endif
	pcfShadow1 = 0.0;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	mean1 = 0.0;
	meanSq1 = 0.0;
	#endif
	#ifdef SHADOW_COLORED
	color = vec3(0.0);
	#endif

	//--//

	const int filterSamples = SHADOW_FILTER_SAMPLES;

	float distortionFactor = CalculateDistortionFactor(positionShadowProjected.xy);
	float filterRadius = 4.0 / textureSize(shadowtex0, 0).x / distortionFactor;

	//--// PCF filter

	float waterPotential = 0.0;

	for (int i = 0; i < filterSamples; ++i) {
		vec2 offset = R2((i + dither) * ditherSize);
		     offset = vec2(cos(offset.x * tau), sin(offset.x * tau)) * sqrt(offset.y);
		vec2 sampleUv = positionShadowDistorted.xy + offset * filterRadius * distortionFactor * 0.5;

		float sampleDepthBias = shadowDepthBias * (2.0 * (filterRadius * distortionFactor * 0.5) * textureSize(shadowtex0, 0).x);

		float diff0 = texelFetch(shadowtex0, ivec2(textureSize(shadowtex0, 0) * sampleUv), 0).x - positionShadowDistorted.z;
		float thresh0 = step(sampleDepthBias, diff0);
		#ifdef SHADOW_COLORED
		pcfShadow0 += thresh0;
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		mean0 += diff0;
		meanSq0 += diff0 * diff0;
		#endif
		#endif

		float diff1 = texelFetch(shadowtex1, ivec2(textureSize(shadowtex1, 0) * sampleUv), 0).x - positionShadowDistorted.z;
		float thresh1 = step(sampleDepthBias, diff1);
		pcfShadow1 += thresh1;
		mean1 += diff1;
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		meanSq1 += diff1 * diff1;
		#endif

		// Water depth stuff, for caustics & sunlight absorption
		float waterPossible = thresh1 - thresh0;
		float isWater = waterPossible * step(0.5 / 255.0, texelFetch(shadowcolor0, ivec2(textureSize(shadowcolor0, 0) * sampleUv), 0).a);
		waterDepth += isWater * diff0;
		waterFraction += isWater;
		waterPotential += waterPossible;

		#ifdef SHADOW_COLORED
		if (diff0 != diff1) {
			vec4 scol = texelFetch(shadowcolor1, ivec2(textureSize(shadowcolor1, 0) * sampleUv), 0);
			scol.rgb = LinearFromSrgb(scol.rgb);
			#if defined USE_R2020
			scol.rgb *= R709ToRgb_unlit;
			#endif
			color += scol.rgb * scol.a + 1.0 - scol.a;
		} else {
			color += vec3(thresh0);
		}
		#endif
	}

	waterDepth /= waterFraction;
	waterFraction /= waterPotential;

	#ifdef SHADOW_COLORED
	pcfShadow0 /= filterSamples;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	mean0 /= filterSamples;
	meanSq0 /= filterSamples;
	#endif
	#endif
	pcfShadow1 /= filterSamples;
	mean1 /= filterSamples;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	meanSq1 /= filterSamples;
	#endif
	#ifdef SHADOW_COLORED
	color /= filterSamples;
	#endif
}
#elif SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS
// Searches the shadow map for potential blockers.
// Returns an estimate of the distance to blockers.
float BlockerSearch(
	sampler2D depthmap,     // Shadow depth map.
	vec3 referencePosition, // Reference point position.
	float referenceDepth,   // Reference point depth in `depthmap`.
	float searchRadius,     // Radius of the search region.
	float dither,
	float ditherSize,
	out float pLit          // Estimated probability that the reference point is lit.
) {
	/*\
	 * Efficiently estimates the distance to potential blockers at the reference
	 * position. Instead of introducing branching or additional weights to reject
	 * clearly invalid blockers, it esimates the mean and standard deviation of
	 * blocker distances within the search region. Adding these two together then
	 * produces a good estimate of the distance to the valid blockers, without
	 * having to test each blocker individually.
	 *
	 * This is essentially Variance Shadow Mapping, with a single operation added
	 * to perform the distance estimate.
	\*/

	const int nSamples = SHADOW_SEARCH_SAMPLES;

	float mean        = 0.0;
	float meanSquares = 0.0;
	for (int i = 0; i < nSamples; ++i) {
		vec2 offset = R2((i + dither) * ditherSize);
		offset = vec2(cos(offset.x * tau), sin(offset.x * tau)) * sqrt(offset.y);

		vec2 sampleUv = referencePosition.xy + searchRadius * offset;
		     sampleUv = DistortShadowSpace(sampleUv) * 0.5 + 0.5;
		float foundDepth = textureLod(depthmap, sampleUv, 0.0).x;
		float foundDistance = referenceDepth - foundDepth;

		// This is mainly to avoid issues caused by culling.
		foundDistance = max(foundDistance, 0.0);

		mean        += foundDistance;
		meanSquares += foundDistance * foundDistance;
	}
	mean        /= nSamples;
	meanSquares /= nSamples;

	float variance  = meanSquares - mean * mean;
	      variance *= nSamples / (nSamples - 1.0); // Remove bias from the variance estimate.
	float stdDev = sqrt(variance); // Note: This is not an unbiased estimate of standard deviation, despite the variance estimate itself being unbiased!

	// Upper bound from Chebyshev's inequality.
	float k = max(mean, 0.0) / stdDev;
	pLit = k >= 1.0 ? clamp(1.0 / (k * k), 0.0, 1.0) : 1.0;

	// Final blocker depth is mean + standard deviation.
	// Adding standard deviation reduces underestimation around edges.
	// It also does not introduce much overestimation.
	return mean + stdDev;
}

void SampleShadowmapPCSS(
	vec3 positionShadowProjected,
	vec3 positionShadowDistorted,
	float shadowDepthBias,
	float dither,
	float ditherSize,

	#ifdef SHADOW_PENUMBRA_SHARPENING
	out float filterRadiusRatio,
	#endif

	out float waterFraction,
	out float waterDepth,

	#ifdef SHADOW_COLORED
	out float pcfShadow0,
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	out float mean0,
	out float meanSq0,
	#endif
	#endif
	out float pcfShadow1,
	out float mean1
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	,
	out float meanSq1
	#endif
	#ifdef SHADOW_COLORED
	,
	out vec3 color
	#endif
) {
	waterFraction = 0.0;
	waterDepth = 0.0;

	#ifdef SHADOW_COLORED
	pcfShadow0 = 0.0;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	mean0 = 0.0;
	meanSq0 = 0.0;
	#endif
	#endif
	pcfShadow1 = 0.0;
	mean1 = 0.0;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	meanSq1 = 0.0;
	#endif
	#ifdef SHADOW_COLORED
	color = vec3(0.0);
	#endif

	//--//

	const float lightAngularRadius = radians(0.25);
	const int searchSamples = SHADOW_SEARCH_SAMPLES;
	const int filterSamples = SHADOW_FILTER_SAMPLES;

	float distortionFactor = CalculateDistortionFactor(positionShadowProjected.xy);

	float shadowDepthRange = 2.0 * SHADOW_DEPTH_SCALE * abs(shadowProjectionInverse[2].z); // distance in blocks between a value of 0 and 1 in shadowtexN
	float maxPenumbraRadius = shadowDepthRange * tan(lightAngularRadius) * shadowProjection[0].x;

	float searchRadius = min(0.5 * shadowProjection[0].x, maxPenumbraRadius);
	float minFilterRadius = 4.0 / textureSize(shadowtex0, 0).x / distortionFactor;
	float maxFilterRadius = max(searchRadius, minFilterRadius);

	//--// Blocker search

	#ifdef SHADOW_PENUMBRA_SHARPENING
	float minBlockerDistance = 0.0;
	#else
	float minBlockerDistance = minFilterRadius / maxPenumbraRadius;
	#endif
	float maxBlockerDistance = maxFilterRadius / maxPenumbraRadius;

	float pLit;
	float blockerDistance = BlockerSearch(shadowtex0, positionShadowProjected, positionShadowDistorted.z, searchRadius, dither, ditherSize, pLit);
	blockerDistance = clamp(blockerDistance, minBlockerDistance, maxBlockerDistance);

	// Compute filter radius
	float filterRadius = blockerDistance * maxPenumbraRadius;
	#ifdef SHADOW_PENUMBRA_SHARPENING
	float filterRadiusUnlcamped = filterRadius;
	filterRadius = max(filterRadius, minFilterRadius);
	filterRadiusRatio = filterRadiusUnlcamped / filterRadius;
	#endif

	//--// PCF filter

	float waterPotential = 0.0;

	for (int i = 0; i < filterSamples; ++i) {
		vec2 sxy = R2((i + dither) * ditherSize);
		vec2 offset = vec2(cos(sxy.x * tau), sin(sxy.x * tau)) * sqrt(sxy.y);
		vec2 sampleUv = positionShadowDistorted.xy + offset * filterRadius * distortionFactor * 0.5;

		float sampleDepthBias = shadowDepthBias * (2.0 * (filterRadius * sqrt(sxy.y) * distortionFactor * 0.5) * textureSize(shadowtex0, 0).x);


		float depth0 = texelFetch(shadowtex0, ivec2(textureSize(shadowtex0, 0) * sampleUv), 0).x;
		float diff0 = depth0 - positionShadowDistorted.z;
		float thresh0 = step(sampleDepthBias, diff0);
		#ifdef SHADOW_COLORED
		pcfShadow0 += thresh0;
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		mean0 += diff0;
		meanSq0 += diff0 * diff0;
		#endif
		#endif

		float depth1 = texelFetch(shadowtex1, ivec2(textureSize(shadowtex1, 0) * sampleUv), 0).x;
		float diff1 = depth1 - positionShadowDistorted.z;
		float thresh1 = step(sampleDepthBias, diff1);
		pcfShadow1 += thresh1;
		mean1 += diff1;
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		meanSq1 += diff1 * diff1;
		#endif

		// Water depth stuff, for caustics & sunlight absorption
		float waterPossible = thresh1 - thresh0;
		float isWater = waterPossible * step(0.5 / 255.0, texelFetch(shadowcolor0, ivec2(textureSize(shadowcolor0, 0) * sampleUv), 0).a);
		waterDepth += isWater * diff0;
		waterFraction += isWater;
		waterPotential += waterPossible;

		#ifdef SHADOW_COLORED
		if (depth0 != depth1) {
			vec4 scol = texelFetch(shadowcolor1, ivec2(textureSize(shadowcolor1, 0) * sampleUv), 0);
			scol.rgb = LinearFromSrgb(scol.rgb);
			#if defined USE_R2020
			scol.rgb *= R709ToRgb_unlit;
			#endif
			color += scol.rgb * scol.a + 1.0 - scol.a;
		} else {
			color += vec3(thresh0);
		}
		#endif
	}

	waterDepth /= waterFraction;
	waterFraction /= waterPotential;

	#ifdef SHADOW_COLORED
	pcfShadow0 /= filterSamples;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	mean0 /= filterSamples;
	meanSq0 /= filterSamples;
	#endif
	#endif
	pcfShadow1 /= filterSamples;
	mean1 /= filterSamples;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	meanSq1 /= filterSamples;
	#endif
	#ifdef SHADOW_COLORED
	color /= filterSamples;
	#endif
}
#endif

#if defined SHADOW_COLORED
vec3
#else
float
#endif
NearShadows(
	vec3 positionShadowProjected, vec3 positionShadowDistorted, float baseDepthBias,
	float dither, float ditherSize,
	out float sssDepth
	#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCF
	,
	out float waterDepth, out float waterFraction
	#endif
) {
	// Depth bias
	float shadowDepthBias = baseDepthBias / CalculateDistortionDerivative(positionShadowProjected.xy);
	#if SHADOW_FILTER == SHADOW_FILTER_BICUBIC
	shadowDepthBias *= 2.0;
	#endif

	//#if defined PROGRAMS_FORWARD
	positionShadowDistorted = positionShadowDistorted * 0.5 + 0.5;
	//#endif

	#if SHADOW_FILTER == SHADOW_FILTER_BILINEAR
	// Convert distorted shadow position to texel coords
	positionShadowDistorted.xy = positionShadowDistorted.xy * textureSize(shadowtex0, 0) - 0.5;
	#endif

	// Sample shadow maps
	#ifdef SHADOW_PENUMBRA_SHARPENING
	float filterRadiusRatio;
	#endif
	#ifdef SHADOW_COLORED
	float pcfShadow0;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	float mean0;
	float meanSq0;
	#endif
	#endif
	float pcfShadow1;
	float mean1;
	#ifdef SHADOW_CONTACT_IMPROVEMENT
	float meanSq1;
	#endif
	#ifdef SHADOW_COLORED
	vec3 color;
	#endif

	#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS
	SampleShadowmapPCSS
	#elif SHADOW_FILTER == SHADOW_FILTER_PCF
	SampleShadowmapPCF
	#else // SHADOW_FILTER == SHADOW_FILTER_BILINEAR
	SampleShadowmapBilinear
	#endif
	(
		#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCF
		positionShadowProjected,
		#endif
		positionShadowDistorted, shadowDepthBias,
		#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCF
		dither, ditherSize,
		#endif

		#ifdef SHADOW_PENUMBRA_SHARPENING
		filterRadiusRatio,
		#endif

		#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCF
		waterFraction,
		waterDepth,
		#endif

		#ifdef SHADOW_COLORED
		pcfShadow0,
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		mean0, meanSq0,
		#endif
		#endif

		pcfShadow1,
		mean1
		#ifdef SHADOW_CONTACT_IMPROVEMENT
		,
		meanSq1
		#endif

		#ifdef SHADOW_COLORED
		,
		color
		#endif
	);

	sssDepth = mean1;

	#ifdef SHADOW_CONTACT_IMPROVEMENT
		// Compute variance shadow
		#ifdef SHADOW_COLORED
		float variance0 = meanSq0 - mean0 * mean0;
		float varianceShadow0 = 0.0 > mean0 ? Clamp01(variance0 / (variance0 + mean0 * mean0)) : 1.0;
		#endif
		float variance1 = meanSq1 - mean1 * mean1;
		float varianceShadow1 = 0.0 > mean1 ? Clamp01(variance1 / (variance1 + mean1 * mean1)) : 1.0;

		#ifdef SHADOW_COLORED
			// Final shadow is minimum of pcf shadow & variance shadow
			float shadow0 = min(pcfShadow0, varianceShadow0);
			float shadow1 = min(pcfShadow1, varianceShadow1);
			#ifdef SHADOW_PENUMBRA_SHARPENING
			shadow0 = LinearStep(0.5 - filterRadiusRatio * 0.5, 0.5 + filterRadiusRatio * 0.5, shadow0);
			shadow1 = LinearStep(0.5 - filterRadiusRatio * 0.5, 0.5 + filterRadiusRatio * 0.5, shadow1);
			#endif

			vec3 shadow = (shadow1 - shadow0) * color + shadow0;
		#else
			// Final shadow is minimum of pcf shadow & variance shadow
			float shadow = min(pcfShadow1, varianceShadow1);
			#ifdef SHADOW_PENUMBRA_SHARPENING
			shadow = LinearStep(0.5 - filterRadiusRatio * 0.5, 0.5 + filterRadiusRatio * 0.5, shadow);
			#endif
		#endif
	#else
		#if defined SHADOW_COLORED
			#ifdef SHADOW_PENUMBRA_SHARPENING
			pcfShadow0 = LinearStep(0.5 - filterRadiusRatio * 0.5, 0.5 + filterRadiusRatio * 0.5, pcfShadow0);
			pcfShadow1 = LinearStep(0.5 - filterRadiusRatio * 0.5, 0.5 + filterRadiusRatio * 0.5, pcfShadow1);
			#endif
			vec3 shadow = (pcfShadow1 - pcfShadow0) * color + pcfShadow0;
		#else // Standard shadows
			float shadow = pcfShadow1;
			#ifdef SHADOW_PENUMBRA_SHARPENING
			shadow = LinearStep(0.5 - filterRadiusRatio * 0.5, 0.5 + filterRadiusRatio * 0.5, shadow);
			#endif
		#endif
	#endif

	return shadow;
}

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
		float ditherp = floor(stride * fract(Bayer8(gl_FragCoord.xy) + frameR1) + 3.0);
		for (uint i = 0u; i < maxLoops && !hit; ++i) {
			float pixelSteps = float(i * stride) + ditherp;
			position[0] = startPosition + pixelSteps * rayStep;

			// Z at current step & one step towards -Z
			float maxZ = position[0].z;
			float minZ = position[0].z - float(stride) * abs(rayStep.z);

			if (1.0 < minZ || maxZ < 0.0) { break; }

			// Requiring intersection from BOTH interpolated & noninterpolated depth prevents pretty much all false occlusion.
			//position[0].xy -= 0.5 * taaOffset;
			float depth = texelFetch(depthtex1, ivec2(position[0].xy), 0).r;
			float ascribedDepth = AscribeDepth(depth, 1e-2 * (i == 0u ? ditherp : float(stride)) * gbufferProjectionInverse[1].y);
			float depthInterp = ViewSpaceToScreenSpace(GetLinearDepth(depthtex1, position[0].xy * viewPixelSize), gbufferProjection);
			float ascribedDepthInterp = AscribeDepth(depthInterp, 1e-2 * (i == 0u ? ditherp : float(stride)) * gbufferProjectionInverse[1].y);
			//position[0].xy += 0.5 * taaOffset;

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
	vec3 positionShadowProjected = shadowClip;
	vec3 positionShadowDistorted = shadowCoord;
	positionShadowDistorted.z += biasAdd;
	shadowCoord     = shadowCoord * 0.5 + 0.5;

	float waterFraction, waterDepth;
	#if !(SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCF)
	waterFraction = step(0.5 / 255.0, texture(shadowcolor0, shadowCoord.xy).a);
	waterDepth = texture(shadowtex0, shadowCoord.xy).x - shadowCoord.z;
	#endif
	vec3 shadows = vec3(NearShadows(
		positionShadowProjected, positionShadowDistorted, biasMul / SHADOW_RESOLUTION, dither, ditherSize, sssDepth
		#if SHADOW_FILTER == SHADOW_FILTER_DUAL_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCSS || SHADOW_FILTER == SHADOW_FILTER_PCF
		,
		waterDepth, waterFraction
		#endif
	));

	sssDepth = -2.0 * SHADOW_DEPTH_RADIUS * sssDepth;
	waterDepth = -2.0 * SHADOW_DEPTH_RADIUS * waterDepth;

	if (waterFraction > 0 && waterDepth > 0.2) {
		#ifdef UNDERWATER_ADAPTATION
			float fogDensity = isEyeInWater == 1 ? fogDensity : 0.1;
		#else
			const float fogDensity = 0.1;
		#endif
		vec3 attenuationCoefficient = -log(LinearFromSrgb(vec3(WATER_TRANSMISSION_R, WATER_TRANSMISSION_G, WATER_TRANSMISSION_B) / 255.0)) / WATER_REFERENCE_DEPTH;
		vec3 waterShadow = exp(-attenuationCoefficient * fogDensity * waterDepth);

		#if   CAUSTICS == CAUSTICS_LOW
			waterShadow *= GetProjectedCaustics(shadowCoord.xy, clamp(waterDepth, 0.0, 2.0));
		#elif CAUSTICS == CAUSTICS_HIGH
			waterShadow *= CalculateCaustics(shadowView, waterDepth, vec2(dither, fract(dither * ditherSize * phi)));
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
