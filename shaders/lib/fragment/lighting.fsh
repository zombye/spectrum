#define DIFFUSE_MODEL 0 // [0 1]

//--//

float diffuse_lambertian(vec3 normal, vec3 light) {
	return max0(dot(normal, light)) / pi;
}
float diffuse_burley(vec3 view, vec3 normal, vec3 light, float roughness) {
	const vec2 efc = vec2(-51.0 / 151.0, 1.0) / pi;

	float NoL = max0(dot(normal, light));
	float VoH = dot(view, normalize(light + view));

	vec2 rs = (2.0 * roughness * (VoH * VoH + 0.25) - 1.0) * pow5(1.0 - vec2(NoL, max0(dot(normal, view)))) + 1.0;

	return NoL * rs.x * rs.y * (efc.x * roughness + efc.y);
}

#if DIFFUSE_MODEL == 1
#define diffuse(v, n, l, r) diffuse_burley(v, n, l, r)
#else
#define diffuse(v, n, l, r) diffuse_lambertian(n, l)
#endif

vec3 shadowSample(vec3 position) {
	float opaque = textureShadow(shadowtex1, position);
	
	#ifdef SHADOW_COLORED
	vec4 colorSample = texture2D(shadowcolor0, position.st);

	vec3 transparent = mix(vec3(1.0), colorSample.rgb, (1.0 - textureShadow(shadowtex0, position)) * colorSample.a);
	#else
	vec3 transparent = vec3(1.0);
	#endif

	return transparent * opaque;
}
vec3 softShadow(vec3 position) {
	const vec2[12] offset = vec2[12](
		vec2(-0.5, 1.5),
		vec2( 0.5, 1.5),
		vec2(-1.5, 0.5),
		vec2(-0.5, 0.5),
		vec2( 0.5, 0.5),
		vec2( 1.5, 0.5),
		vec2(-1.5,-0.5),
		vec2(-0.5,-0.5),
		vec2( 0.5,-0.5),
		vec2( 1.5,-0.5),
		vec2(-0.5,-1.5),
		vec2( 0.5,-1.5)
	);

	vec2 pixel = 1.0 / textureSize2D(shadowtex1, 0);

	vec3 result = vec3(0.0);
	for (int i = 0; i < offset.length(); i++) result += shadowSample(position + vec3(offset[i] * pixel, 0.0));

	return result / offset.length();
}
vec3 pcssShadow(vec3 position) {
	float spread = tan(sunAngularRadius) * 2.0 * projectionShadowInverse[2].z * projectionShadow[0].x;
	float searchRadius = spread * 0.01;

	float dither = bayer8(gl_FragCoord.st) * tau;
	mat2 ditherRotaion = mat2(cos(dither), sin(dither), -sin(dither), cos(dither));

	// Sampling offsets (Poisson disk)
	const vec2[36] offset = vec2[36](
		vec2(-0.90167680,  0.34867350),
		vec2(-0.98685560, -0.03261871),
		vec2(-0.67581730,  0.60829530),
		vec2(-0.47958790,  0.23570540),
		vec2(-0.45314310,  0.48728980),
		vec2(-0.30706600, -0.15843290),
		vec2(-0.09606075, -0.01807100),
		vec2(-0.60807480,  0.01524314),
		vec2(-0.02638345,  0.27449020),
		vec2(-0.17485240,  0.49767420),
		vec2( 0.08868586, -0.19452260),
		vec2( 0.18764890,  0.45603400),
		vec2( 0.39509670,  0.07532994),
		vec2(-0.14323580,  0.75790890),
		vec2(-0.52281310, -0.28745570),
		vec2(-0.78102060, -0.44097930),
		vec2(-0.40987180, -0.51410110),
		vec2(-0.12428560, -0.78665660),
		vec2(-0.52554520, -0.80657600),
		vec2(-0.01482044, -0.48689910),
		vec2(-0.45758520,  0.83156060),
		vec2( 0.18829080,  0.71168610),
		vec2( 0.23589650, -0.95054530),
		vec2( 0.26197550, -0.61955050),
		vec2( 0.47952230,  0.32172530),
		vec2( 0.52478220,  0.61679990),
		vec2( 0.85708400,  0.47555550),
		vec2( 0.75702890,  0.08125463),
		vec2( 0.48267020,  0.86368290),
		vec2( 0.33045960, -0.31044460),
		vec2( 0.59658700, -0.35501270),
		vec2( 0.69684450, -0.61393110),
		vec2( 0.88014110, -0.41306840),
		vec2( 0.07468465,  0.99449370),
		vec2( 0.92697510, -0.10826900),
		vec2( 0.45471010, -0.78973980)
	);

	// blocker search & penumbra estimation
	float blockerDepth = 0.0;
	for (int i = 0; i < offset.length(); i++) {
		blockerDepth += max0(position.z * 0.5 + 0.5 - texture2D(shadowtex0, shadows_distortShadowSpace(ditherRotaion * offset[i] * searchRadius + position.st) * 0.5 + 0.5).r);
	} blockerDepth *= spread / offset.length();

	// filter
	vec3 result = vec3(0.0);
	for (int i = 0; i < offset.length(); i++) {
		result += shadowSample(shadows_distortShadowSpace(vec3(ditherRotaion * offset[i], 0.0) * blockerDepth + position) * 0.5 + 0.5);
	} result /= offset.length();

	return result;
}
vec3 shadows(vec3 position) {
	position = mat3(shadowModelView) * position + shadowModelView[3].xyz;
	vec3 normal = normalize(cross(dFdx(position), dFdy(position)));
	position = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * position + projectionShadow[3].xyz;

	#if SHADOW_FILTER_TYPE == 2
	return pcssShadow(position);
	#endif

	float distortFactor = shadows_calculateDistortionCoeff(position.xy);

	position.xy *= distortFactor;
	position = position * 0.5 + 0.5;

	#if SHADOW_FILTER_TYPE == 1
	return softShadow(position);
	#else
	return shadowSample(position);
	#endif
}

float blockLight(float lightmap) {
	return lightmap / (pow2(-4.0 * lightmap + 4.0) + 1.0);
}
float skyLight(float lightmap, vec3 normal) {
	return (dot(normal, upVector) * 0.2 + 0.8) * lightmap / (pow2(-4.0 * lightmap + 4.0) + 1.0);
}

float handLight(mat3 position, vec3 normal) {
	// TODO: Make this accurate to standard block lighting

	if (heldBlockLightValue + heldBlockLightValue2 == 0) return 0.0;

	const mat2x3 handPosition = mat2x3(
		vec3( 1.4, -0.6, -1.0) * MC_HAND_DEPTH,
		vec3(-1.4, -0.6, -1.0) * MC_HAND_DEPTH
	);

	mat2x3 lightVector = handPosition - mat2x3(position[1], position[1]);

	vec2 dist = clamp01((vec2(heldBlockLightValue, heldBlockLightValue2) - vec2(length(lightVector[0]), length(lightVector[1]))) * 0.0625);
	vec2 lm   = dist / (pow2(-4.0 * dist + 4.0) + 1.0);

	lm *= vec2(
		diffuse(normalize(position[1]), normal, normalize(lightVector[0]), 0.0),
		diffuse(normalize(position[1]), normal, normalize(lightVector[1]), 0.0)
	) * pi;

	return lm.x + lm.y;
}

vec3 calculateLighting(mat3 position, vec3 normal, vec2 lightmap, material mat, out vec3 sunVisibility) {
	#if PROGRAM != PROGRAM_WATER && (CAUSTICS_SAMPLES > 0 || RSM_SAMPLES > 0)
	vec4 filtered = bilateralResample(normal, position[1].z);
	#endif

	sunVisibility = shadows(position[2]);

	vec3
	shadowLight  = sunVisibility;
	shadowLight *= lightmap.y * lightmap.y;
	shadowLight *= mix(diffuse(normalize(position[1]), normal, shadowLightVector, mat.roughness), 1.0 / pi, mat.subsurface);
	#if PROGRAM != PROGRAM_WATER && CAUSTICS_SAMPLES > 0
	shadowLight *= filtered.a;
	#endif

	float skyLight = skyLight(lightmap.y, normal);

	float
	blockLight  = blockLight(lightmap.x);
	blockLight += handLight(position, normal);

	vec3
	lighting  = shadowLightColor * shadowLight;
	lighting += skyLightColor * skyLight;
	lighting += blockLightColor * blockLight;
	#if PROGRAM != PROGRAM_WATER && RSM_SAMPLES > 0
	lighting += filtered.rgb;
	#endif

	return lighting;
}
