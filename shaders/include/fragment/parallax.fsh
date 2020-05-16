#if !defined INCLUDE_FRAGMENT_PARALLAX
#define INCLUDE_FRAGMENT_PARALLAX

#ifdef SMART_PARALLAX
#endif

#ifdef SMOOTH_PARALLAX
	float ReadHeight(vec2 tileCoordinates, ivec2 textureResolution, float lod) {
		ivec2 tileResolution = ivec2(atlasTileResolution);
		ivec2 tileOffset     = ivec2(atlasTileOffset * textureResolution);

		tileCoordinates = tileCoordinates * atlasTileResolution - 0.5;
		ivec2 i = ivec2(tileCoordinates);
		vec2  f = fract(tileCoordinates);

		vec4 s = vec4(
			texelFetch(normals, ((i + ivec2(0, 1)) % tileResolution) + tileOffset, 0).a,
			texelFetch(normals, ((i + ivec2(1, 1)) % tileResolution) + tileOffset, 0).a,
			texelFetch(normals, ((i + ivec2(1, 0)) % tileResolution) + tileOffset, 0).a,
			texelFetch(normals, ((i + ivec2(0, 0)) % tileResolution) + tileOffset, 0).a
		);

		s.xy = mix(s.wx, s.zy, f.x);
		return mix(s.x,  s.y,  f.y);
	}
#else
	float ReadHeight(vec2 tileCoordinates, ivec2 textureResolution, float lod) {
		return textureLod(normals, tileCoordinates * atlasTileSize + atlasTileOffset, lod).a;
	}

	float ReadHeight(vec2 tileCoordinates, mat2 textureCoordinateDerivatives) {
		return textureGrad(normals, tileCoordinates * atlasTileSize + atlasTileOffset, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1]).a;
	}
#endif

#if defined SMOOTH_PARALLAX || !defined SMART_PARALLAX
	vec2 CalculateParallaxedCoordinate(vec2 textureCoordinates, float mipLevel, vec3 tangentViewVector, out vec3 position, out ivec2 index) {
		// Skip parallax for cases where it doesn't work
		if(tangentViewVector.z >= 0.0                           // This should never be true for anything visible, but in some cases it is anyway.
		|| abs(blockId - 9.5) < 1.6                             // Water & Lava, they could probably be fixed but I just haven't bothered trying to do so.
		|| atlasTileResolution.x * atlasTileResolution.y == 0.0 // This is true on the side faces on held items, which shouldn't have parallax anyway.
		) return textureCoordinates;

		ivec2 textureResolution = textureSize(tex, 0);

		// Init
		position = vec3((textureCoordinates - atlasTileOffset) / atlasTileSize, 1.0);

		vec3 increment    = vec3(tangentViewVector.xy, tangentViewVector.z / PARALLAX_DEPTH) * (inversesqrt(dot(tangentViewVector, tangentViewVector)) * gbufferProjectionInverse[1].y * -viewPosition.z * 0.1 / PARALLAX_QUALITY);
		     increment.y *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes some warping

		// Loop to find approximate intersection location
		for (int i = 0; i < 256 && position.z > ReadHeight(fract(position.xy), textureResolution, mipLevel); ++i, position += increment);

		// Refine intersection location
		for (int i = 0; i < 8; ++i, increment *= 0.5, position += increment * sign(position.z - ReadHeight(fract(position.xy), textureResolution, mipLevel)));

		#if defined PROGRAM_HAND || defined PROGRAM_ENTITIES
			// For entities and held blocks, discard when off the edge
			if (clamp(position.xy, 0.0, 1.0) != position.xy) discard;
		#endif

		// End
		position.xy = fract(position.xy) * atlasTileSize + atlasTileOffset;

		return position.xy;
	}
#else
	vec2 CalculateParallaxedCoordinate(vec2 textureCoordinates, float mipLevel, vec3 tangentViewVector, out vec3 endPosition, out ivec2 endIndex) {
		// Skip parallax for cases where it doesn't work
		if(tangentViewVector.z >= 0.0                           // This should never be true for anything visible, but in some cases it is anyway.
		|| abs(blockId - 9.5) < 1.6                             // Water & Lava, they could probably be fixed but I just haven't bothered trying to do so.
		|| atlasTileResolution.x * atlasTileResolution.y == 0.0 // This is true on the side faces on held items, which shouldn't have parallax anyway.
		) { return textureCoordinates; }

		// Preparation stuff
		vec2 tileResolution = round(atlasTileResolution * exp2(-floor(mipLevel)));

		vec2 position  = (textureCoordinates - atlasTileOffset) / atlasTileSize;
		vec3 direction = tangentViewVector; direction.z /= PARALLAX_DEPTH;

		position *= tileResolution;
		direction.xy *= tileResolution;
		ivec2 index = ivec2(floor(position));

		vec2 next;
		vec2 deltaDist;
		ivec2 deltaSign;
		for (int axis = 0; axis < 2; ++axis) {
			deltaDist[axis] = abs(1.0 / direction[axis]);
			if (direction[axis] < 0.0) {
				deltaSign[axis] = -1;
				next[axis] = (position[axis] - index[axis]) * deltaDist[axis];
			} else {
				deltaSign[axis] = 1;
				next[axis] = (1.0 + index[axis] - position[axis]) * deltaDist[axis];
			}
		}

		// First step
		float tPrev = 0.0;
		float height = textureLod(normals, fract((index + 0.5) / tileResolution) * atlasTileSize + atlasTileOffset, mipLevel).a;

		endIndex = index;

		float tNext;
		if (next.x < next.y) {
			tNext    = next.x;
			next.x  += deltaDist.x;
			index.x += deltaSign.x;
		} else {
			tNext    = next.y;
			next.y  += deltaDist.y;
			index.y += deltaSign.y;
		}

		// Loop for remaining steps
		for (int i = 0; i < 4096 && 1.0 + direction.z * tNext > height; ++i) {
			height = textureLod(normals, fract((index + 0.5) / tileResolution) * atlasTileSize + atlasTileOffset, mipLevel).a;

			endIndex = index;

			tPrev = tNext;
			if (next.x < next.y) {
				tNext    = next.x;
				next.x  += deltaDist.x;
				index.x += deltaSign.x;
			} else {
				tNext    = next.y;
				next.y  += deltaDist.y;
				index.y += deltaSign.y;
			}
		}

		// Final intersection
		#if defined PARALLAX_SHADOWS || defined PARALLAX_DEPTH_WRITE
		float tIntersectionExact = 1.0 + direction.z * tPrev <= height ? tPrev : (height - 1.0) / direction.z;
		endPosition = vec3(position, 1.0) + direction * tIntersectionExact;
		endPosition.xy = (endPosition.xy / tileResolution) * atlasTileSize + atlasTileOffset;
		#endif

		float tIntersection = (tPrev + tNext) / 2.0;
		position += direction.xy * tIntersection;
		position /= tileResolution;

		#if defined PROGRAM_HAND || defined PROGRAM_ENTITIES
		if (Clamp01(position) != position) { discard; }
		#endif

		return fract(position) * atlasTileSize + atlasTileOffset;
	}
#endif

#ifdef PARALLAX_SHADOWS
	#if defined SMOOTH_PARALLAX || !defined SMART_PARALLAX
		float CalculateParallaxSelfShadow(vec3 coord, ivec2 index, float mipLevel, vec3 tangentLightVector) {
			if(tangentLightVector.z <= 0.0
			|| abs(blockId - 9.5) < 1.6
			) { return 1.0; }

			coord.xy = (coord.xy - atlasTileOffset) / atlasTileSize;

			vec3 increment    = vec3(tangentLightVector.xy, tangentLightVector.z / PARALLAX_DEPTH) * (gbufferProjectionInverse[1].y * -viewPosition.z * 0.1 / PARALLAX_QUALITY);
			     increment.y *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes some warping
			vec3 offset = vec3(0.0, 0.0, coord.z);

			for (int i = 0; i < 256 && offset.z < 1.0; i++) {
				offset += increment;

				float foundHeight = ReadHeight(fract(coord.xy + offset.xy), textureSize(tex, 0), mipLevel);
				if (offset.z < foundHeight) { return 0.0; }
			}

			return 1.0;
		}
	#else
		float CalculateParallaxSelfShadow(vec3 position, ivec2 index, float mipLevel, vec3 tangentLightVector) {
			if(tangentLightVector.z <= 0.0
			|| abs(blockId - 9.5) < 1.6) { return 1.0; }

			// Preparation stuff
			vec2 tileResolution = round(atlasTileResolution * exp2(-floor(mipLevel)));

			position.xy = (position.xy - atlasTileOffset) / atlasTileSize;
			vec3 direction = tangentLightVector;
			direction.z /= PARALLAX_DEPTH;

			position.xy *= tileResolution;
			direction.xy *= tileResolution;

			#ifdef PARALLAX_SHADOWS_DYNAMIC_BIAS
			float bias = (abs(direction.z) / MaxOf(abs(direction.xy))) + PARALLAX_SHADOWS_BIAS;
			#else
			const float bias = PARALLAX_SHADOWS_BIAS;
			#endif

			// Self-occlusion for initial texel
			float height = textureLod(normals, fract((index + 0.5) / tileResolution) * atlasTileSize + atlasTileOffset, mipLevel).a - bias;

			if (position.z + 1e-5 < height) {
				vec2 v = position.xy - index - 0.5;
				if (abs(v.x) > abs(v.y)) {
					if ((direction.x > 0.0) != (v.x > 0.0)) { return 0.0; }
				} else {
					if ((direction.y > 0.0) != (v.y > 0.0)) { return 0.0; }
				}
			}

			// More preparation stuff
			vec2 next;
			vec2 deltaDist;
			ivec2 deltaSign;
			for (int axis = 0; axis < 2; ++axis) {
				deltaDist[axis] = abs(1.0 / direction[axis]);
				if (direction[axis] < 0.0) {
					deltaSign[axis] = -1;
					next[axis] = (position[axis] - index[axis]) * deltaDist[axis];
				} else {
					deltaSign[axis] = 1;
					next[axis] = (1.0 + index[axis] - position[axis]) * deltaDist[axis];
				}
			}

			// Loop
			float tPrev = 0.0;
			float tNext = 0.0;
			for (int i = 0; i < 4096 && position.z + direction.z * tPrev < 1.0; ++i) {
				tPrev = tNext;
				if (next.x < next.y) {
					tNext    = next.x;
					next.x  += deltaDist.x;
					index.x += deltaSign.x;
				} else {
					tNext    = next.y;
					next.y  += deltaDist.y;
					index.y += deltaSign.y;
				}

				height = textureLod(normals, fract((index + 0.5) / tileResolution) * atlasTileSize + atlasTileOffset, mipLevel).a - bias;

				if (tNext * direction.z + position.z < height) { return 0.0; }
			}

			return 1.0;
		}
	#endif
#endif

#endif
