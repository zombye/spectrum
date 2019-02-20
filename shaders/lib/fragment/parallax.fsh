#if !defined INCLUDE_FRAGMENT_PARALLAX
#define INCLUDE_FRAGMENT_PARALLAX

#ifdef SMART_PARALLAX
#endif

#ifdef SMOOTH_PARALLAX
	float ReadHeight(vec2 tileCoordinates, ivec2 textureResolution, int lod) {
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
	float ReadHeight(vec2 tileCoordinates, ivec2 textureResolution, int lod) {
		return textureLod(normals, tileCoordinates * atlasTileSize + atlasTileOffset, lod).a;
	}

	float ReadHeight(vec2 tileCoordinates, mat2 textureCoordinateDerivatives) {
		return textureGrad(normals, tileCoordinates * atlasTileSize + atlasTileOffset, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1]).a;
	}
#endif

#if defined SMOOTH_PARALLAX || !defined SMART_PARALLAX
	vec2 CalculateParallaxedCoordinate(vec2 textureCoordinates, mat2 textureCoordinateDerivatives, vec3 tangentViewVector, out vec3 position) {
		// Skip parallax for cases where it doesn't work
		if(tangentViewVector.z >= 0.0                           // This should never be true for anything visible, but in some cases it is anyway.
		|| abs(blockId - 9.5) < 1.6                             // Water & Lava, they could probably be fixed but I just haven't bothered trying to do so.
		|| atlasTileResolution.x * atlasTileResolution.y == 0.0 // This is true on the side faces on held items, which shouldn't have parallax anyway.
		) return textureCoordinates;

		// Calculate LOD
		ivec2 textureResolution = textureSize(tex, 0);

		mat2 derivatives     = textureCoordinateDerivatives;
		     derivatives[0] *= textureResolution;
		     derivatives[1] *= textureResolution;

		int lod = int(ceil(-0.5 * log2(max(max(dot(derivatives[0], derivatives[0]), dot(derivatives[1], derivatives[1])), 1.0))));

		// Init
		position = vec3((textureCoordinates - atlasTileOffset) / atlasTileSize, 1.0);

		vec3 increment    = vec3(tangentViewVector.xy, tangentViewVector.z / PARALLAX_DEPTH) * (inversesqrt(dot(tangentViewVector, tangentViewVector)) * gbufferProjectionInverse[1].y * -viewPosition.z * 0.1 / PARALLAX_QUALITY);
		     increment.y *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes some warping

		// Loop to find approximate intersection location
		for (int i = 0; i < 256 && position.z > ReadHeight(fract(position.xy), textureResolution, lod); ++i, position += increment);

		// Refine intersection location
		for (int i = 0; i < 8; ++i, increment *= 0.5, position += increment * sign(position.z - ReadHeight(fract(position.xy), textureResolution, lod)));

		#if defined PROGRAM_HAND || defined PROGRAM_ENTITIES
			// For entities and held blocks, discard when off the edge
			if (clamp(position.xy, 0.0, 1.0) != position.xy) discard;
		#endif

		// End
		position.xy = fract(position.xy) * atlasTileSize + atlasTileOffset;

		return position.xy;
	}
#else
	vec2 CalculateParallaxedCoordinate(vec2 textureCoordinates, mat2 textureCoordinateDerivatives, vec3 tangentViewVector, out vec3 endPosition) {
		// Skip parallax for cases where it doesn't work
		if(tangentViewVector.z >= 0.0                           // This should never be true for anything visible, but in some cases it is anyway.
		|| abs(blockId - 9.5) < 1.6                          // Water & Lava, they could probably be fixed but I just haven't bothered trying to do so.
		|| atlasTileResolution.x * atlasTileResolution.y == 0.0 // This is true on the side faces on held items, which shouldn't have parallax anyway.
		) { return textureCoordinates; }

		// Calculate lod
		ivec2 textureResolution = textureSize(tex, 0);

		mat2 derivatives = textureCoordinateDerivatives; derivatives[0] *= textureResolution; derivatives[1] *= textureResolution;
		vec2 atlasTileResolutionLod = atlasTileResolution * exp2(ceil(-0.5 * log2(max(max(dot(derivatives[0], derivatives[0]), dot(derivatives[1], derivatives[1])), 1.0))));

		// Init
		tangentViewVector.xy *= PARALLAX_DEPTH;
		tangentViewVector.y  *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes some warping
		vec2 texelDelta = tangentViewVector.xy * atlasTileResolutionLod;
		vec2 tds = step(0.0, texelDelta);

		vec3 position = vec3((textureCoordinates - atlasTileOffset) / atlasTileSize, 1.0);

		// Loop until intersection
		for (int i = 0; i < 4096; ++i) {
			// Calculate distance to the next texel
			// xy = closest, zw = second closest
			vec2 texelCoordinates = fract(position.xy * atlasTileResolutionLod);

			vec2  distanceToNextTexelDirectional = (tds - texelCoordinates) / texelDelta;
			float distanceToNextTexel            = min(distanceToNextTexelDirectional.x, distanceToNextTexelDirectional.y);

			// Check for intersection
			if (tangentViewVector.z * distanceToNextTexel + position.z < ReadHeight(fract(position.xy), textureCoordinateDerivatives)) { break; }

			// Distance to second closest texel
			float distanceToNextTexel2 = max(distanceToNextTexelDirectional.x, distanceToNextTexelDirectional.y);
			distanceToNextTexel2 = min(MinOf(((3.0 * tds - 1.0) - texelCoordinates) / (3.0 * texelDelta)), distanceToNextTexel2);

			// Move to halfway trough next texel
			position += 0.5 * (distanceToNextTexel + distanceToNextTexel2) * tangentViewVector;
		}

		#if defined PROGRAM_HAND || defined PROGRAM_ENTITIES
			// For entities and held blocks, discard when off the edge
			if (Clamp01(position.xy) != position.xy) discard;
		#endif

		// Find exact intersection location, for self-shadows or when writing depth. Need to make sure this is actually correct
		#if defined PARALLAX_SHADOWS || defined PARALLAX_DEPTH_WRITE
			endPosition = position;

			float height = textureGrad(normals, fract(endPosition.xy) * atlasTileSize + atlasTileOffset, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1]).a;
			float distanceToPlaneIntersect = (height - endPosition.z) / tangentViewVector.z;

			if (endPosition.z < height) {
				// May need to hit texel edge if below the heightmap value
				vec2 texelCoordinates = fract(endPosition.xy * atlasTileResolutionLod);

				vec2  distanceToPreviousTexelDirectional = ((1.0 - tds) - texelCoordinates) / -texelDelta;
				float distanceToPreviousTexel            = min(distanceToPreviousTexelDirectional.x, distanceToPreviousTexelDirectional.y);

				endPosition += tangentViewVector * max(-distanceToPreviousTexel, distanceToPlaneIntersect);
			} else {
				endPosition += tangentViewVector * distanceToPlaneIntersect;
			}

			#if !defined PROGRAM_HAND && !defined PROGRAM_ENTITIES
				endPosition.xy = fract(endPosition.xy);
			#endif

			endPosition.xy = endPosition.xy * atlasTileSize + atlasTileOffset;
		#endif

		#if !defined PROGRAM_HAND && !defined PROGRAM_ENTITIES
			position.xy = fract(position.xy);
		#endif

		position.xy = position.xy * atlasTileSize + atlasTileOffset;

		return position.xy;
	}
#endif

#ifdef PARALLAX_SHADOWS
	#if defined SMOOTH_PARALLAX || !defined SMART_PARALLAX
		float CalculateParallaxSelfShadow(vec2 hitTextureCoordinates, vec3 coord, mat2 textureCoordinateDerivatives, vec3 tangentLightVector) {
			if(tangentLightVector.z <= 0.0
			|| abs(blockId - 9.5) < 1.6
			) { return 1.0; }

			coord.xy = (coord.xy - atlasTileOffset) / atlasTileSize;

			vec3 increment    = vec3(tangentLightVector.xy, tangentLightVector.z / PARALLAX_DEPTH) * (gbufferProjectionInverse[1].y * -viewPosition.z * 0.1 / PARALLAX_QUALITY);
			     increment.y *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes some warping
			vec3 offset = vec3(0.0, 0.0, coord.z);

			for (int i = 0; i < 256 && offset.z < 1.0; i++) {
				offset += increment;

				float foundHeight = ReadHeight(fract(coord.xy + offset.xy), textureSize(tex, 0), 0);
				if (offset.z < foundHeight) { return 0.0; }
			}

			return 1.0;
		}
	#else
		float CalculateParallaxSelfShadow(vec2 hitTextureCoordinates, vec3 textureCoordinates, mat2 textureCoordinateDerivatives, vec3 tangentLightVector) {
			if(tangentLightVector.z <= 0.0
			|| abs(blockId - 9.5) < 1.6
			) { return 1.0; }

			// Calculate lod
			ivec2 textureResolution = textureSize(tex, 0);

			mat2 derivatives = textureCoordinateDerivatives; derivatives[0] *= textureResolution; derivatives[1] *= textureResolution;
			vec2 atlasTileResolutionLod = atlasTileResolution * exp2(ceil(-0.5 * log2(max(max(dot(derivatives[0], derivatives[0]), dot(derivatives[1], derivatives[1])), 1.0))));

			// Init
			tangentLightVector.z /= PARALLAX_DEPTH;
			tangentLightVector.y *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes some warping
			vec2 texelDelta = tangentLightVector.xy * atlasTileResolutionLod;
			vec2 tds = step(0.0, texelDelta);

			vec3 position = vec3((textureCoordinates.xy - atlasTileOffset) / atlasTileSize, textureCoordinates.z);
			vec2 hitPosition = (hitTextureCoordinates - atlasTileOffset) / atlasTileSize;

			// small margin to avoid issues cause by rounding errors
			if (position.z + exp2(-17.0) < ReadHeight(fract(hitPosition), textureCoordinateDerivatives)) {
				vec2 hitTexel = (floor(hitPosition * atlasTileResolutionLod) + 0.5) / atlasTileResolutionLod;

				vec2 texelCenterVec = hitTexel - position.xy;
				if (abs(texelCenterVec.x) > abs(texelCenterVec.y)) {
					if (tds.x == step(0.0, texelCenterVec.x)) { return 0.0; }
				} else {
					if (tds.y == step(0.0, texelCenterVec.y)) { return 0.0; }
				}
			}

			// Loop until intersection
			for (int i = 0; i < 4096; ++i) {
				vec2 texelCoordinates = fract(position.xy * atlasTileResolutionLod);

				// Distance to closest texel along ray, check if leaving heightfield
				vec2  distanceToNextTexelDirectional = (tds - texelCoordinates) / texelDelta;
				float distanceToNextTexel            = min(distanceToNextTexelDirectional.x, distanceToNextTexelDirectional.y);

				float exitHeight = tangentLightVector.z * distanceToNextTexel + position.z;
				if (exitHeight >= 1.0) { return 1.0; }

				// Distance to second closest texel
				float distanceToNextTexel2 = max(distanceToNextTexelDirectional.x, distanceToNextTexelDirectional.y);
				distanceToNextTexel2 = min(MinOf(((3.0 * tds - 1.0) - texelCoordinates) / (3.0 * texelDelta)), distanceToNextTexel2);

				// Move to halfway trough next texel
				position += 0.5 * (distanceToNextTexel + distanceToNextTexel2) * tangentLightVector;

				// Check for intersection
				if (exitHeight <= ReadHeight(fract(position.xy), textureCoordinateDerivatives)) { return 0.0; }
			}

			return 1.0;
		}
	#endif
#endif

#endif
