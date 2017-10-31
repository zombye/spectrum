//#define DIRECTIONAL_LIGHTMAP_BLOCK
//#define DIRECTIONAL_LIGHTMAP_SKY

vec2 directionalLightmap(vec2 lightmap, vec3 normal) {
	#if !defined DIRECTIONAL_LIGHTMAP_BLOCK && !defined DIRECTIONAL_LIGHTMAP_SKY
	return lightmap;
	#endif

	const float normalBiasDark   = 0.1;
	const float normalBiasBright = 1.0;
	const float normalBiasCurve  = 5.0;

	lightmap = clamp01(lightmap);

	vec2 normalBias = pow(mix(vec2(normalBiasDark), vec2(normalBiasBright), lightmap), vec2(normalBiasCurve));

	vec3 geometryDerivativeX = normalize(dFdx(positionView));
	vec3 geometryDerivativeY = normalize(dFdy(positionView));
	vec3 geometryDerivativeNormal = cross(geometryDerivativeX, geometryDerivativeY);

	vec2 shading = vec2(1.0);

	#ifdef DIRECTIONAL_LIGHTMAP_BLOCK
	vec2 blockDerivatives = vec2(dFdx(lightmap.x), dFdy(lightmap.x));
	vec3 blockLightVector = normalize((blockDerivatives.x * geometryDerivativeX) + (blockDerivatives.y * geometryDerivativeY) + (geometryDerivativeNormal * 1e-6));
	     blockLightVector = normalize(mix(blockLightVector, tbn[2], normalBias.x));

	shading.x = clamp01(dot(blockLightVector, normal) * 0.5 + 0.5);
	if (shading.x == 0.0) shading.x = 1.0;
	#endif

	#ifdef DIRECTIONAL_LIGHTMAP_SKY
	vec2 skyDerivatives   = vec2(dFdx(lightmap.y), dFdy(lightmap.y));
	vec3 skyLightVector = normalize((skyDerivatives.x * geometryDerivativeX) + (skyDerivatives.y * geometryDerivativeY) + (geometryDerivativeNormal * 1e-6));
	     skyLightVector = normalize(mix(skyLightVector, tbn[2], normalBias.y));

	shading.y = clamp01(dot(skyLightVector, normal) * 0.5 + 0.5);
	if (shading.y == 0.0) shading.y = 1.0;
	#endif

	return lightmap * shading;
}
