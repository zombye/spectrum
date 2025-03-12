#if !defined INCLUDE_FRAGMENT_WATERCAUSTICS
#define INCLUDE_FRAGMENT_WATERCAUSTICS

float GetProjectedCaustics(float depth, vec2 coeffs) {
	if (coeffs.x == 0.0 || coeffs.y == 0.0) {
		return 1.0;
	}
	coeffs = coeffs * (255.0 / 254.0) - (1.0 / 254.0);
	coeffs = log2(1.0 / coeffs - 1.0);

	float area = abs(1.0 + depth * (coeffs.x + depth * coeffs.y));
	float caustics = pow(1.0 / (area + 1e-2), CAUSTICS_POWER);

	return caustics;
}
float GetProjectedCaustics(vec2 uv, float depth) {
	return GetProjectedCaustics(depth, texture(shadowcolor0, uv).zw);
}

#if CAUSTICS == CAUSTICS_MEDIUM || (CAUSTICS == CAUSTICS_HIGH && CAUSTICS_HIGH_SUBSEARCH_ITERATIONS >= 1)
float DoCausticSearch(vec2 targetPos, vec2 initialGuess, float waterDepth, int iterations) {
	vec2 searchPos = initialGuess;
	for (int i = 0; i < iterations; ++i) {
		// Sample normal
		vec2 sampleUv = Diagonal(shadowProjection).xy * searchPos + shadowProjection[3].xy;
		     sampleUv = DistortShadowSpace(sampleUv) * 0.5 + 0.5;

		vec4 normalSample = texture(shadowcolor0, sampleUv);
		vec3 normal = normalSample.a < (0.5/255.0) ? vec3(0.0, 1.0, 0.0) : DecodeNormal(normalSample.xy * 2.0 - 1.0);

		vec3 refractionDirection = mat3(shadowModelView) * refract(-shadowLightVector, normal, 0.75);
		vec3 refraction = refractionDirection * abs(waterDepth / refractionDirection.z);
		vec2 refractsTo = searchPos + refraction.xy;
		searchPos += (targetPos - refractsTo) / (iterations - i);
	}

	vec2 finalUv = Diagonal(shadowProjection).xy * searchPos + shadowProjection[3].xy;
	     finalUv = DistortShadowSpace(finalUv) * 0.5 + 0.5;

	return GetProjectedCaustics(finalUv, waterDepth);
}
#endif

#if CAUSTICS == CAUSTICS_MEDIUM
float CalculateCaustics(vec3 position, float waterDepth) {
	if (waterDepth <= 0.0) { return 1.0; }

	waterDepth = min(waterDepth, CAUSTICS_MEDIUM_MAX_DEPTH);

	vec3 flatRefractVector = refract(vec3(0.0, 0.0, -1.0), mat3(shadowModelView) * vec3(0.0, 1.0, 0.0), 0.75);
	vec3 flatRefraction = flatRefractVector * waterDepth / -flatRefractVector.z;

	float result = DoCausticSearch(position.xy + flatRefraction.xy, position.xy, waterDepth, CAUSTICS_MEDIUM_SEARCH_ITERATIONS);
	return pow(result, CAUSTICS_POWER);
}
#elif CAUSTICS == CAUSTICS_HIGH
float DensityCaustics(vec3 position, float waterDepth, vec2 offs) {
	if (waterDepth <= 0.0) { return 1.0; }

	const int samples = (CAUSTICS_QUALITY + 1) * (CAUSTICS_QUALITY + 1);
	const float focus = 0.7;

	float radius = CAUSTICS_RADIUS * waterDepth;
	float inverseDistanceThreshold = sqrt(samples / pi) * focus / radius;

	vec3 flatRefractionDirection = mat3(shadowModelView) * refract(-shadowLightVector, vec3(0.0, 1.0, 0.0), 0.75);
	vec3 flatRefraction = flatRefractionDirection * abs(waterDepth / flatRefractionDirection.z);
	vec3 surfacePosition = position - flatRefraction;

	float caustics = 0.0;
	for (int i = 0; i < samples; ++i) {
		vec2 xy = fract(R2(i) + offs);
		vec2 offset = vec2(cos(tau * xy.x), sin(tau * xy.x)) * sqrt(xy.y);

		vec3 samplePosition = surfacePosition;
		samplePosition.xy += offset * radius;

		// Sample normal
		vec2 sampleUv = Diagonal(shadowProjection).xy * (samplePosition.xy + flatRefraction.xy) + shadowProjection[3].xy;
		     sampleUv = DistortShadowSpace(sampleUv) * 0.5 + 0.5;

		vec4 normalSample = texture(shadowcolor0, sampleUv);
		vec3 normal = normalSample.a < (0.5/255.0) ? vec3(0.0, 1.0, 0.0) : DecodeNormal(normalSample.xy * 2.0 - 1.0);

		// Refract
		vec3 refractionDirection = mat3(shadowModelView) * refract(-shadowLightVector, normal, 0.75);
		vec3 refraction = refractionDirection * abs(waterDepth / refractionDirection.z);
		vec3 refractedPosition = samplePosition + refraction;

		// Add to density estimate
		caustics += Clamp01(1.0 - distance(position, refractedPosition) * inverseDistanceThreshold);
		//caustics += 2.0 * exp(-2.0 * pow(distance(position, refractedPosition) * inverseDistanceThreshold, 2.0)) / pi;
	} caustics *= focus * focus;

	return pow(caustics, CAUSTICS_POWER);
}


vec2 HexPoint(vec2 xy) {
	vec2 a = vec2(0.0, sin(pi/3.0));
	vec2 b = vec2(xy.x * 2.0 - 1.0, 0.0);
	if (xy.y < 0.5) {
		return mix( a, b, sqrt(xy.y * 1.5 + 0.25));
	} else {
		return mix(-a, b, sqrt(xy.y * 1.5 - 0.5));
	}
}

float CalculateCaustics(vec3 position, float waterDepth, vec2 offs) {
	//return DensityCaustics(position, waterDepth, offs);

	if (waterDepth <= 0.0) { return 1.0; }

	waterDepth = min(waterDepth, CAUSTICS_HIGH_MAX_DEPTH);

	// pretty much this entire function can be optimized

	const int quality = CAUSTICS_QUALITY;
	const int sideVertices = quality + 1;
	const int vertices = sideVertices * sideVertices;

	float radius = CAUSTICS_RADIUS * waterDepth;

	vec3 flatRefractVector = refract(vec3(0.0, 0.0, -1.0), mat3(shadowModelView) * vec3(0.0, 1.0, 0.0), 0.75);
	vec3 flatRefraction = flatRefractVector * waterDepth / -flatRefractVector.z;

	#ifdef CAUSTICS_DITHERED
	offs = HexPoint(offs) / quality;
	#endif

	// Calculate area of each polygon at surface
	float surfArea = (2.0 * sin(pi/3.0) / (quality * quality)) * radius * radius;

	vec2[sideVertices][2] surfPositions;
	vec2[sideVertices][2] refrPositions;
	float result = 0.0;
	for (int y = 0; y <= quality; ++y) {
		int odd = y % 2;
		for (int x = 0; x <= quality; ++x) {
			// surface position
			vec2 offset = vec2(x, y) * (2.0 / quality) - 1.0;
			offset = vec2(offset.x - offset.y * 0.5, offset.y * sin(pi/3.0));
			#ifdef CAUSTICS_DITHERED
			offset += offs;
			#endif

			surfPositions[x][odd] = position.xy + offset * radius;

			// get surface normal
			vec2 sampleUv = vec2(shadowProjection[0].x, shadowProjection[1].y) * surfPositions[x][odd] + shadowProjection[3].xy;
			     sampleUv = DistortShadowSpace(sampleUv) * 0.5 + 0.5;

			vec4 normalSample = texture(shadowcolor0, sampleUv);
			vec3 normal = normalSample.a < (0.5/255.0) ? vec3(0.0, 1.0, 0.0) : DecodeNormal(normalSample.xy * 2.0 - 1.0);

			// refract
			vec3 refractVec = refract(vec3(0.0, 0.0, -1.0), mat3(shadowModelView) * normal, 0.75);
			float dist = waterDepth / -refractVec.z;

			refrPositions[x][odd]  = surfPositions[x][odd];
			refrPositions[x][odd] -= flatRefraction.xy;
			refrPositions[x][odd] += refractVec.xy * dist;
		}

		if (y == 0) { continue; }

		for (int x = 0; x < quality; ++x) {
			// x -- y
			// |    |
			// z -- w
			ivec4 idx_x = ivec4(x, x + 1, x, x + 1);
			ivec4 idx_y = ivec4(1 - odd, 1 - odd, odd, odd);

			vec2 rp0 = refrPositions[idx_x.x][idx_y.x], sp0 = surfPositions[idx_x.x][idx_y.x];
			vec2 rp1 = refrPositions[idx_x.y][idx_y.y], sp1 = surfPositions[idx_x.y][idx_y.y];
			vec2 rp2 = refrPositions[idx_x.w][idx_y.w], sp2 = surfPositions[idx_x.w][idx_y.w];

			// Check if currently shaded point is in the first half
			if (PointInTriangle(position.xy, rp0, rp1, rp2)) {
				mat2 T = mat2(rp0 - rp2, rp1 - rp2);
				vec2 barycentric = inverse(T) * (position.xy - rp2);
				vec2 sourcePos = barycentric.x * sp0 + barycentric.y * sp1 + (1.0 - barycentric.x - barycentric.y) * sp2;

				#if CAUSTICS_HIGH_SUBSEARCH_ITERATIONS >= 1
				result += DoCausticSearch(position.xy + flatRefraction.xy, sourcePos, waterDepth, CAUSTICS_HIGH_SUBSEARCH_ITERATIONS);
				#else
				vec2 sourceUv = vec2(shadowProjection[0].x, shadowProjection[1].y) * sourcePos + shadowProjection[3].xy;
				     sourceUv = DistortShadowSpace(sourceUv) * 0.5 + 0.5;
				result += GetProjectedCaustics(sourceUv, waterDepth);
				#endif
			}

			rp1 = refrPositions[idx_x.z][idx_y.z], sp1 = surfPositions[idx_x.z][idx_y.z];

			// Check if currently shaded point is in the second half
			if (PointInTriangle(position.xy, rp0, rp1, rp2)) {
				mat2 T = mat2(rp0 - rp2, rp1 - rp2);
				vec2 barycentric = inverse(T) * (position.xy - rp2);
				vec2 sourcePos = barycentric.x * sp0 + barycentric.y * sp1 + (1.0 - barycentric.x - barycentric.y) * sp2;

				#if CAUSTICS_HIGH_SUBSEARCH_ITERATIONS >= 1
				result += DoCausticSearch(position.xy + flatRefraction.xy, sourcePos, waterDepth, CAUSTICS_HIGH_SUBSEARCH_ITERATIONS);
				#else
				vec2 sourceUv = vec2(shadowProjection[0].x, shadowProjection[1].y) * sourcePos + shadowProjection[3].xy;
				     sourceUv = DistortShadowSpace(sourceUv) * 0.5 + 0.5;
				result += GetProjectedCaustics(sourceUv, waterDepth);
				#endif
			}
		}
	}

	return pow(result, CAUSTICS_POWER);
}
#endif

#endif
