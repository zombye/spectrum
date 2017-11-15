//#define TERRAIN_PARALLAX
#define TERRAIN_PARALLAX_DEPTH 0.25 // [0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50]
#define TEXTURE_RESOLUTION 128 // [16 32 64 128 256 512 1024 2048]

float lod = textureQueryLOD(tex, baseUV).x;

#if PROGRAM == PROGRAM_TERRAIN || PROGRAM == PROGRAM_WATER
#ifdef TERRAIN_PARALLAX
#define texture2D(x, y) texture2DLod(x, y, lod)
#endif
#endif

vec2 calculateParallaxedUV(vec2 coord, vec3 dir) {
	#if defined TERRAIN_PARALLAX && (PROGRAM == PROGRAM_TERRAIN || PROGRAM == PROGRAM_WATER)
	if (dir.z >= 0.0) return coord; // For some reason dir.z is sometimes positive. It should always be negative.

	float tileRes    = TEXTURE_RESOLUTION * exp2(-floor(lod));
	vec2  atlasTiles = vec2(atlasSize) / TEXTURE_RESOLUTION;
	vec2  tileSize   = TEXTURE_RESOLUTION / vec2(atlasSize);
	vec2  tilePos    = floor(coord * atlasTiles) * tileSize;

	dir *= vec3(vec2(TERRAIN_PARALLAX_DEPTH), 1.0);
	vec2 texelDelta = dir.xy * tileRes;

	vec3 pos = vec3(coord * atlasTiles, 1.0);
	float height;

	for (float i = 0.0; i < 256; i += 1.0) {
		height = texture2D(normals, fract(pos.xy) * tileSize + tilePos).a;

		// This first bit calculates the distances to the next two texels.
		// xy = closest texel along ray & zw = second closest texel along ray.
		vec4 texelCoord = fract(pos.xyxy * tileRes);
		texelCoord = texelCoord * vec2(2.0, 1.0).xxyy + vec2(-1.0, -0.5).xxyy;
		texelCoord = (texelCoord * sign(texelDelta).xyxy) * -0.5 + 0.5;
		// texelCoord must be a little bit above 0 now for correct results. Not sure why.
		vec4 distToNextTexelDirectional = max(texelCoord, 0.000001) / abs(texelDelta).xyxy;
		float distToNextTexel = min(distToNextTexelDirectional.x, distToNextTexelDirectional.y);

		// Check if we intersect.
		if (pos.z + dir.z * distToNextTexel < height) break;

		// Distance to second closest texel along ray.
		float distToNextTexel2 = min(max(distToNextTexelDirectional.x, distToNextTexelDirectional.y), min(distToNextTexelDirectional.z, distToNextTexelDirectional.w));

		// Move to halfway trough next texel.
		pos += dir * (distToNextTexel + distToNextTexel2) * 0.5;
	}

	return fract(pos.xy) * tileSize + tilePos;
	#else
	return coord;
	#endif
}
