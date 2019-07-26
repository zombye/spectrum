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
bool PointInTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 n0 = vec2(p0.y - p1.y, p1.x - p0.x);
	vec2 n1 = vec2(p1.y - p2.y, p2.x - p1.x);
	vec2 n2 = vec2(p2.y - p0.y, p0.x - p2.x);

	float d0 = dot(p - p0, n0) * dot(p2 - p0, n0);
	float d1 = dot(p - p1, n1) * dot(p0 - p1, n1);
	float d2 = dot(p - p2, n2) * dot(p1 - p2, n2);

	return (d0 >= 0.0) && (d1 >= 0.0) && (d2 >= 0.0);
}
float TriangleArea(vec2 p0, vec2 p1, vec2 p2) {
	vec2 x = p1 - p0, y = p2 - p0;
	return 0.5 * abs(x.x * y.y - y.x * x.y);
}

bool PointInQuad(
	vec2 p,
	vec2 v00, vec2 v10,
	vec2 v01, vec2 v11
) {
	// this is simple and works but probably inefficient
	return PointInTriangle(p, v00, v10, v01) != PointInTriangle(p, v11, v10, v01);
}
float QuadArea(
	vec2 v00, vec2 v10,
	vec2 v01, vec2 v11
) {
	// v00--v10
	//  |    |
	// v01--v11

	// x edge pair is crossing
	float xdiv = (v00.x - v10.x) * (v01.y - v11.y) - (v00.y - v10.y) * (v01.x - v11.x);
	float xt =  ((v00.x - v01.x) * (v01.y - v11.y) - (v00.y - v01.y) * (v01.x - v11.x)) / xdiv;
	float xu = -((v00.x - v10.x) * (v00.y - v01.y) - (v00.y - v10.y) * (v00.x - v01.x)) / xdiv;
	if (Clamp01(xt) == xt && Clamp01(xu) == xu) {
		vec2 vc = v00 + xt * (v10 - v00);
		return TriangleArea(vc, v00, v01) + TriangleArea(vc, v10, v11);
	}

	// y edge pair is crossing
	float ydiv = (v00.x - v01.x) * (v10.y - v11.y) - (v00.y - v01.y) * (v10.x - v11.x);
	float yt =  ((v00.x - v10.x) * (v10.y - v11.y) - (v00.y - v10.y) * (v10.x - v11.x)) / ydiv;
	float yu = -((v00.x - v01.x) * (v00.y - v10.y) - (v00.y - v01.y) * (v00.x - v10.x)) / ydiv;
	if (Clamp01(yt) == yt && Clamp01(yu) == yu) {
		vec2 vc = v00 + yt * (v01 - v00);
		return TriangleArea(vc, v00, v10) + TriangleArea(vc, v01, v11);
	}

	// neither edge pair is crossing
	vec2 x = v11 - v00, y = v10 - v01;
	return 0.5 * abs(x.x * y.y - y.x * x.y);
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

	vec2 offs = vec2(dither, fract(dither * ditherSize * phi));

	vec2[vertices] surfPositions;
	vec2[vertices] refrPositions;
	for (int y = 0; y <= quality; ++y) {
		for (int x = 0; x <= quality; ++x) {
			int idx = x + sideVertices * y;

			// surface position
			surfPositions[idx] = position.xy;
			#ifdef CAUSTICS_DITHERED
			surfPositions[idx] += (vec2(x, y) + offs) * 2.0 * radius / sideVertices - radius;
			#else
			surfPositions[idx] += (vec2(x, y) + 0.5) * 2.0 * radius / sideVertices - radius;
			#endif

			// get surface normal
			vec2 sampleUv = vec2(shadowProjection[0].x, shadowProjection[1].y) * surfPositions[idx] + shadowProjection[3].xy;
			     sampleUv = DistortShadowSpace(sampleUv) * 0.5 + 0.5;

			vec4 normalSample = texture(shadowcolor0, sampleUv);
			normalSample.xyz = DecodeNormal(normalSample.xy * 2.0 - 1.0);
			vec3 normal = normalSample.a < (0.5/255.0) ? vec3(0.0, 1.0, 0.0) : normalSample.xyz;

			// refract
			vec3 refractVec = mat3(shadowModelView) * refract(-shadowLightVector, normal, 0.75);
			float dist = waterDepth / -refractVec.z; // should maybe dot() refractVec with the normal of the shaded point, rather than the light? would be more accurate but probably not needed

			refrPositions[idx]  = surfPositions[idx];
			refrPositions[idx] -= flatRefraction.xy;
			refrPositions[idx] += refractVec.xy * dist;
		}
	}

	float result = 0.0;
	for (int y = 0; y < quality; ++y) {
		for (int x = 0; x < quality; ++x) {
			// x -- y
			// |    |
			// z -- w
			ivec4 idx = ivec2(x, x + 1).xyxy + sideVertices * ivec2(y, y + 1).xxyy;

			// Check if currently shaded point is in this quad
			if (PointInQuad(position.xy, refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.z], refrPositions[idx.w])) {
				// Compute area of quad at surface
				float surfArea = QuadArea(surfPositions[idx.x], surfPositions[idx.y], surfPositions[idx.z], surfPositions[idx.w]);
				// Compute area of quad at shaded point
				float refrArea = QuadArea(refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.z], refrPositions[idx.w]);

				// Add ratio of areas to result
				result += min(abs(surfArea / refrArea), 1e2);
			}

			/* variation: split quad into two triangles and handle them separately - simpler but noisier
			// Check if currently shaded point is in the first half
			if (PointInTriangle(position.xy, refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.z])) {
				// Compute area of this half at surface
				float surfArea = TriangleArea(surfPositions[idx.x], surfPositions[idx.y], surfPositions[idx.z]);
				// Compute area of this half at shaded point
				float refrArea = TriangleArea(refrPositions[idx.x], refrPositions[idx.y], refrPositions[idx.z]);

				// Add ratio of areas to result
				result += min(abs(surfArea / refrArea), 1e2);
			}

			// Check if currently shaded point is in the second half
			if (PointInTriangle(position.xy, refrPositions[idx.w], refrPositions[idx.y], refrPositions[idx.z])) {
				// Compute area of this half at surface
				float surfArea = TriangleArea(surfPositions[idx.w], surfPositions[idx.y], surfPositions[idx.z]);
				// Compute area of this half at shaded point
				float refrArea = TriangleArea(refrPositions[idx.w], refrPositions[idx.y], refrPositions[idx.z]);

				// Add ratio of areas to result
				result += min(abs(surfArea / refrArea), 1e2);
			}
			//*/
		}
	}

	return pow(result, CAUSTICS_POWER);
}

/*
vec3 GetWaterNormal(vec3 position) {
	position    = mat3(shadowModelView) * position + shadowModelView[3].xyz;
	position.xy = vec2(shadowProjection[0].x, shadowProjection[1].y) * position.xy + shadowProjection[3].xy;

	vec4 normalSample = texture(shadowcolor0, DistortShadowSpace(position.xy) * 0.5 + 0.5);
	normalSample.xyz = DecodeNormal(normalSample.xy * 2.0 - 1.0);

	return normalSample.a < (0.5 / 255.0) ? vec3(0.0, 1.0, 0.0) : normalSample.xyz;
}

#ifdef CAUSTICS_DISPERSION
#define CausticsReturnType vec3
#else
#define CausticsReturnType float
#endif

CausticsReturnType CalculateCaustics(vec3 position, float waterDepth, float dither, const float ditherSize) {
	if (waterDepth <= 0.0) { return CausticsReturnType(1.0); }

	float radius               = CAUSTICS_RADIUS * waterDepth;
	float invDistanceThreshold = sqrt(CAUSTICS_SAMPLES / pi) * CAUSTICS_FOCUS / radius;

	dither = dither * ditherSize + 0.5;

	vec3  flatRefractVector = refract(-shadowLightVector, vec3(0.0, 1.0, 0.0), 0.75);
	float surfDistUp        = waterDepth * abs(shadowLightVector.y);

	vec3 flatRefraction = flatRefractVector * surfDistUp / abs(flatRefractVector.y);
	vec3 surfacePosition = position - flatRefraction;

	CausticsReturnType result = CausticsReturnType(0.0);
	for (int i = 0; i < CAUSTICS_SAMPLES; ++i) {
		vec3 samplePos     = surfacePosition;
		#ifdef CAUSTICS_DITHERED
		     samplePos.xz += CircleMap(i * ditherSize + dither, CAUSTICS_SAMPLES * ditherSize) * radius;
		#else
		     samplePos.xz += CircleMap(i + 0.5, CAUSTICS_SAMPLES) * radius;
		#endif

		vec3 waterNormal = GetWaterNormal(samplePos + flatRefraction);

		#ifdef CAUSTICS_DISPERSION
			vec3 refractVectorR = refract(-shadowLightVector, waterNormal, 0.75 - CAUSTICS_DISPERSION_AMOUNT);
			vec3 refractVectorG = refract(-shadowLightVector, waterNormal, 0.75);
			vec3 refractVectorB = refract(-shadowLightVector, waterNormal, 0.75 + CAUSTICS_DISPERSION_AMOUNT);
			//vec3 refractVectorR = refract(-shadowLightVector, waterNormal, 1 / 1.331);
			//vec3 refractVectorG = refract(-shadowLightVector, waterNormal, 1 / 1.334);
			//vec3 refractVectorB = refract(-shadowLightVector, waterNormal, 1 / 1.338);
			vec3 samplePosR = refractVectorR * (surfDistUp / abs(refractVectorR.y)) + samplePos;
			vec3 samplePosG = refractVectorG * (surfDistUp / abs(refractVectorG.y)) + samplePos;
			vec3 samplePosB = refractVectorB * (surfDistUp / abs(refractVectorB.y)) + samplePos;

			vec3 distances = vec3(
				distance(position, samplePosR),
				distance(position, samplePosG),
				distance(position, samplePosB)
			);

			result += Clamp01(1.0 - distances * invDistanceThreshold);
		#else
			vec3 refractVector = refract(-shadowLightVector, waterNormal, 0.75);
			samplePos = refractVector * (surfDistUp / abs(refractVector.y)) + samplePos;

			result += Clamp01(1.0 - distance(position, samplePos) * invDistanceThreshold);
		#endif
	}

	result *= CAUSTICS_FOCUS * CAUSTICS_FOCUS;
	return pow(result, CausticsReturnType(CAUSTICS_POWER));
}

#undef CausticsReturnType
*/

#endif

#endif
