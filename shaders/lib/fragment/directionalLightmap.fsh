vec2 directionalLightmap(vec2 lightmap, vec3 normal) {
	const float normalBias = 0.1;

	vec2 blockDerivatives = vec2(dFdx(lightmap.x), dFdy(lightmap.x));
	vec2 skyDerivatives   = vec2(dFdx(lightmap.y), dFdy(lightmap.y));

	vec3 geometryDerivativeX = dFdx(positionView);
	vec3 geometryDerivativeY = dFdy(positionView);

	vec3 blockLightVector = normalize((blockDerivatives.x * geometryDerivativeX) + (blockDerivatives.y * geometryDerivativeY) + tbn[2]*0.00000001);
	blockLightVector = normalize(mix(blockLightVector, tbn[2], normalBias));

	vec3 skyLightVector = normalize((skyDerivatives.x * geometryDerivativeX) + (skyDerivatives.y * geometryDerivativeY) + tbn[2]*0.00000001);
	skyLightVector = normalize(mix(skyLightVector, tbn[2], normalBias));

	lightmap.x *= dot(blockLightVector, normal) * 0.5 + 0.5;
	lightmap.y *= dot(skyLightVector,   normal) * 0.5 + 0.5;

	if (dot(blockLightVector, tbn[2]) > 0.9) lightmap.x *= 0.6;
	if (dot(skyLightVector,   tbn[2]) > 0.9) lightmap.y *= 0.6;

	return clamp01(lightmap / 0.6);
}
