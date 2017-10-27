#define DIFFUSE_MODEL 0 // [0 1]

#define RTAO_SAMPLES     0   // [0 1 2 3 4]
#define RTAO_RAY_QUALITY 2.0 // [1.0 1.5 2.0 2.5]

#define SRAO_RADIUS 1.0 // Radius of short-range AO (HBAO, SSAO)

//#define HBAO
#define HBAO_DIRECTIONS        4
#define HBAO_SAMPLES_DIRECTION 4

#define SSAO_SAMPLES 16 // [0 9 16]
#define SSAO_RADIUS  SRAO_RADIUS

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
	opaque = sqrt(opaque);
	vec4 colorSample = texture2D(shadowcolor0, position.st);
	colorSample.rgb = mix(vec3(1.0), colorSample.rgb * (1.0 - colorSample.a), colorSample.a);
	float transparentShadow = sqrt(textureShadow(shadowtex0, position));

	vec3 transparent = colorSample.rgb * (1.0 - transparentShadow) + transparentShadow;
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

const vec2[36] pcss_offset = vec2[36](
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
vec3 pcss(vec3 position) {
	const float searchScale = 0.05;
	float spread = -tan(sunAngularRadius) * projectionShadowInverse[2].z * projectionShadow[0].x;
	float searchRadius = spread * searchScale;

	float dither = bayer8(gl_FragCoord.st) * tau;
	mat2 ditherRotaion = mat2(cos(dither), sin(dither), -sin(dither), cos(dither));

	// blocker search & penumbra estimation
	float blockerDepth = 0.0;
	for (int i = 0; i < pcss_offset.length(); i++) {
		vec2 sampleCoord = shadows_distortShadowSpace(ditherRotaion * pcss_offset[i] * searchRadius + position.st) * 0.5 + 0.5;
		float blockerSample = texture2D(shadowtex1, sampleCoord).r;
		blockerDepth += max0(position.z - (blockerSample * 2.0 - 1.0));
	} blockerDepth = clamp(blockerDepth / pcss_offset.length(), 0.0, searchScale) * spread;

	// filter
	vec3 result = vec3(0.0);
	for (int i = 0; i < pcss_offset.length(); i++) {
		result += shadowSample(shadows_distortShadowSpace(vec3(ditherRotaion * pcss_offset[i], 0.0) * blockerDepth + position) * 0.5 + 0.5);
	} result /= pcss_offset.length();

	return result;
}
vec3 lpcss(vec3 position) {
	const float searchScale = 0.05;
	float spread = -tan(sunAngularRadius) * projectionShadowInverse[2].z * projectionShadow[0].x;
	float searchRadius = spread * searchScale;

	float dither = bayer8(gl_FragCoord.st) * tau;
	mat2 ditherRotaion = mat2(cos(dither), sin(dither), -sin(dither), cos(dither));

	// blocker search & penumbra estimation
	vec2 blockerDepths = vec2(0.0);
	for (int i = 0; i < pcss_offset.length(); i++) {
		vec2 sampleCoord = shadows_distortShadowSpace(ditherRotaion * pcss_offset[i] * searchRadius + position.st) * 0.5 + 0.5;
		vec2 blockerSample = vec2(texture2D(shadowtex1, sampleCoord).r, texture2D(shadowtex0, sampleCoord).r);
		blockerDepths += max0(position.z - (blockerSample * 2.0 - 1.0));
	} blockerDepths = clamp(blockerDepths / pcss_offset.length(), 0.0, searchScale) * spread;

	// filter
	vec3 result = vec3(0.0);
	for (int i = 0; i < pcss_offset.length(); i++) {
		vec3 baseOffset = vec3(ditherRotaion * pcss_offset[i], 0.0);
		float opaqueShadowLayer = sqrt(textureShadow(shadowtex1, shadows_distortShadowSpace(baseOffset * blockerDepths.x + position) * 0.5 + 0.5));

		vec3 transparentPos = shadows_distortShadowSpace(baseOffset * blockerDepths.y + position) * 0.5 + 0.5;
		float transparentShadow = sqrt(textureShadow(shadowtex0, transparentPos));

		vec4 colorSample = texture2D(shadowcolor0, transparentPos.st);
		colorSample.rgb = mix(vec3(1.0), colorSample.rgb * (1.0 - colorSample.a), colorSample.a);

		vec3 transparentShadowLayer = colorSample.rgb * (1.0 - transparentShadow) + transparentShadow;

		result += opaqueShadowLayer * transparentShadowLayer;
	} result /= pcss_offset.length();

	return result;
}

vec3 shadows(vec3 position) {
	position = mat3(shadowModelView) * position + shadowModelView[3].xyz;
	vec3 normal = normalize(cross(dFdx(position), dFdy(position)));
	position = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * position + projectionShadow[3].xyz;

	#if SHADOW_FILTER_TYPE == 2 || (SHADOW_FILTER_TYPE == 3 && !defined SHADOW_COLORED)
	return pcss(position);
	#elif SHADOW_FILTER_TYPE == 3
	return lpcss(position);
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

float hbao(mat3 position, vec3 normal) {
	#ifndef HBAO
	return 1.0;
	#endif

	const float hbao_nir2 = -1.0 / SRAO_RADIUS;
	const float alpha = tau / HBAO_DIRECTIONS;

	#ifdef TEMPORAL_AA
	vec2 noise = hash22(vec2(bayer8(gl_FragCoord.st), frameCounter % 16)) * vec2(alpha, 1.0);
	#else
	vec2 noise = hash22(vec2(bayer8(gl_FragCoord.st))) * vec2(alpha, 1.0);
	#endif

	float result = 0.0;
	for (int i = 0; i < HBAO_DIRECTIONS; i++) {
		float angle = alpha * i + noise.x;
		vec3 dir = vec3(cos(angle), sin(angle), 0.0) * SRAO_RADIUS / HBAO_SAMPLES_DIRECTION;

		// Find cosinus of angle between normal & horizon
		float cosHorizon = 0.0;
		for (int j = 0; j < HBAO_SAMPLES_DIRECTION; j++) {
			vec2 sampleUV = viewSpaceToScreenSpace(dir * (j + noise.y) + position[1], projection).st;
			vec3 samplePosition = screenSpaceToViewSpace(vec3(sampleUV, texture2D(depthtex1, sampleUV).r), projectionInverse);

			vec3 sampleVector = samplePosition - position[1];
			float distanceSquared = dot(sampleVector, sampleVector);

			if (distanceSquared > SRAO_RADIUS * SRAO_RADIUS) continue;

			cosHorizon = max(cosHorizon, dot(normal, sampleVector) * inversesqrt(distanceSquared));
		}

		// Add angle above horizon to result
		result += acos(clamp01(cosHorizon)) / pi;
	}

	return result / HBAO_DIRECTIONS;
}
float rtao(vec3 position, vec3 normal) {
	#if RTAO_SAMPLES == 0
	return 1.0;
	#endif

	float dither = bayer8(gl_FragCoord.st);

	float result = 0.0;
	for (int i = 0; i < RTAO_SAMPLES; i++) {
		vec3 rayDir = is_lambertian(normal, hash42(vec2(((frameCounter % 16) * RTAO_SAMPLES + i) * 0.2516, dither)));

		vec3 temp;
		if (raytraceIntersection(position, rayDir, temp, dither, RTAO_RAY_QUALITY)) continue;

		result += 1.0 / RTAO_SAMPLES;
	} return result;
}
float ssao(vec3 position, vec3 normal) {
	#if SSAO_SAMPLES == 0
	return 1.0;
	#endif

	float dither = bayer8(gl_FragCoord.st);

	float result = 1.0;
	for (int i = 0; i < SSAO_SAMPLES; i++) {
		#ifdef TEMPORAL_AA
		vec4 noise = hash42(vec2(((frameCounter % 16) * SSAO_SAMPLES + i) * 0.2516, dither));
		#else
		vec4 noise = hash42(vec2(i, dither));
		#endif

		vec3 offset = normalize(noise.xyz * 2.0 - 1.0) * noise.w;
		if (dot(offset, normal) < 0.0) offset = -offset;

		vec3 sp = offset * SSAO_RADIUS + position;
		vec3 sd = viewSpaceToScreenSpace(offset * SSAO_RADIUS + position, projection);
		float od = texture2D(depthtex1, sd.st).r;
		vec3 op = screenSpaceToViewSpace(vec3(sd.st, od), projectionInverse);

		vec3 v = sp - op;

		if (dot(v, v) > SSAO_RADIUS * SSAO_RADIUS) continue;

		result -= float(sp.z < op.z) / SSAO_SAMPLES;
	}
	return result;
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
	if (skyLight > 0.0) {
		skyLight *= hbao(position, normal);
		skyLight *= rtao(position[0], normal);
		#ifndef HBAO
		skyLight *= ssao(position[1], normal);
		#endif
	}

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
