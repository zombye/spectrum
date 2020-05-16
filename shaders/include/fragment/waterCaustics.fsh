#if !defined INCLUDE_FRAGMENT_WATERCAUSTICS
#define INCLUDE_FRAGMENT_WATERCAUSTICS

float GetProjectedCaustics(float shadowcolor0Alpha, float depth) {
	depth = Clamp01(depth);

	float caustics = shadowcolor0Alpha * (255.0 / 254.0) - (1.0 / 254.0);
	      caustics = pow(2.0 * caustics * caustics, CAUSTICS_POWER);

	return caustics * depth + 1.0 - depth;
}
float GetProjectedCaustics(vec2 uv, float depth) {
	return GetProjectedCaustics(texture(shadowcolor0, uv).a, depth);
}

#if CAUSTICS == CAUSTICS_HIGH
#define CAUSTICS_GRID_TRIANGULAR
vec2 HexPoint(vec2 xy) {
	vec2 a = vec2(0.0, sin(pi/3.0));
	vec2 b = vec2(xy.x * 2.0 - 1.0, 0.0);
	if (xy.y < 0.5) {
		return mix( a, b, sqrt(xy.y * 1.5 + 0.25));
	} else {
		return mix(-a, b, sqrt(xy.y * 1.5 - 0.5));
	}
}
float CalculateCaustics(vec3 position, float waterDepth, float dither, const float ditherSize) {
	if (waterDepth <= 0.0) { return 1.0; }

	// pretty much this entire function can be optimized

	const int quality = CAUSTICS_QUALITY;
	const int sideVertices = quality + 1;
	const int vertices = sideVertices * sideVertices;

	float radius = CAUSTICS_RADIUS * waterDepth;

	vec3 flatRefractVector = mat3(shadowModelView) * refract(-shadowLightVector, vec3(0.0, 1.0, 0.0), 0.75);
	vec3 flatRefraction = flatRefractVector * waterDepth / -flatRefractVector.z;

	#ifdef CAUSTICS_DITHERED
	vec2 offs = vec2(dither, fract(dither * ditherSize * phi));
	#if defined CAUSTICS_GRID_TRIANGULAR
	offs = HexPoint(offs) / quality;
	#else
	offs = offs * (2.0 / quality) - (1.0 / quality);
	#endif
	#endif

	// Calculate area of each polygon at surface
	#if defined CAUSTICS_GRID_TRIANGULAR
	float surfArea = (2.0 * sin(pi/3.0) / (quality * quality)) * radius * radius;
	#else
	float surfArea = (4.0 / (quality * quality)) * radius * radius;
	#endif

	vec2[vertices] surfPositions;
	vec2[vertices] refrPositions;
	for (int y = 0; y <= quality; ++y) {
		for (int x = 0; x <= quality; ++x) {
			int idx = x + sideVertices * y;

			// surface position
			vec2 offset = vec2(x, y) * (2.0 / quality) - 1.0;
			#if defined CAUSTICS_GRID_TRIANGULAR
			offset = vec2(offset.x - offset.y * 0.5, offset.y * sin(pi/3.0));
			#endif
			#ifdef CAUSTICS_DITHERED
			offset += offs;
			#endif

			surfPositions[idx] = position.xy + offset * radius;

			// get surface normal
			vec2 sampleUv = vec2(shadowProjection[0].x, shadowProjection[1].y) * surfPositions[idx] + shadowProjection[3].xy;
			     sampleUv = DistortShadowSpace(sampleUv) * 0.5 + 0.5;

			vec4 normalSample = texture(shadowcolor0, sampleUv);
			vec3 normal = normalSample.a < (0.5/255.0) ? vec3(0.0, 1.0, 0.0) : DecodeNormal(normalSample.xy * 2.0 - 1.0);

			// refract
			vec3 refractVec = refract(vec3(0.0, 0.0, -1.0), mat3(shadowModelView) * normal, 0.75);
			float dist = waterDepth / -refractVec.z;

			refrPositions[idx]  = surfPositions[idx];
			refrPositions[idx] -= flatRefraction.xy;
			refrPositions[idx] += refractVec.xy * dist;
		}
	}

	#if !defined CAUSTICS_GRID_TRIANGULAR
	float result = 0.0;
	for (int y = 0; y < quality; ++y) {
		for (int x = 0; x < quality; ++x) {
			// x -- y
			// |    |
			// z -- w
			ivec4 idx = ivec2(x, x + 1).xyxy + sideVertices * ivec2(y, y + 1).xxyy;

			// Check if currently shaded point is in this quad
			if (PointInQuad(position.xy, refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.z], refrPositions[idx.w])) {
				// Compute area of quad at shaded point
				float refrArea = QuadArea(refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.z], refrPositions[idx.w]);

				// Add ratio of areas to result
				result += 1.0 / max(refrArea, 1e-2 * abs(surfArea));
			}
		}
	}
	result *= surfArea;
	#else
	float result = 0.0;
	for (int y = 0; y < quality; ++y) {
		for (int x = 0; x < quality; ++x) {
			// x -- y
			// |    |
			// z -- w
			ivec4 idx = ivec2(x, x + 1).xyxy + sideVertices * ivec2(y, y + 1).xxyy;

			// Check if currently shaded point is in the first half
			if (PointInTriangle(position.xy, refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.w])) {
				// Compute area of this half at shaded point
				float refrArea = TriangleArea(refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.w]);

				// Add ratio of areas to result
				result += 1.0 / max(refrArea, 1e-2 * abs(surfArea));
			}

			// Check if currently shaded point is in the second half
			if (PointInTriangle(position.xy, refrPositions[idx.x], refrPositions[idx.z], refrPositions[idx.w])) {
				// Compute area of this half at shaded point
				float refrArea = TriangleArea(refrPositions[idx.x], refrPositions[idx.z], refrPositions[idx.w]);

				// Add ratio of areas to result
				result += 1.0 / max(refrArea, 1e-2 * abs(surfArea));
			}
		}
	}
	result *= surfArea;
	#endif

	return pow(result, CAUSTICS_POWER);
}
#endif

#endif
