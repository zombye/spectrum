#define DIFFUSE_MODEL 0 // [0 1]

#define RTCS
#define RTCS_SAMPLES 16
#define RTCS_RANGE   0.3
#define RTCS_SURFACE_THICKNESS 0.2

#define HBAO
#define HBAO_RADIUS            2.0 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0]
#define HBAO_DIRECTIONS        5   // [2 3 4 5 6 7 8]
#define HBAO_SAMPLES_DIRECTION 3   // [2 3 4 5 6 7 8]

//--//

#if DIFFUSE_MODEL == 1
float diffuse_burley(vec3 view, vec3 normal, vec3 light, float roughness) {
	const vec2 efc = vec2(-51.0 / 151.0, 1.0) / pi;

	float NoL = clamp01(dot(normal, light));
	float VoH = dot(view, normalize(light + view));

	vec2 rs = (2.0 * roughness * (VoH * VoH + 0.25) - 1.0) * pow5(1.0 - vec2(NoL, clamp01(dot(normal, view)))) + 1.0;

	return NoL * rs.x * rs.y * (efc.x * roughness + efc.y);
}
#define diffuse(v, n, l, r) diffuse_burley(v, n, l, r)
#else
float diffuse_lambertian(vec3 normal, vec3 light) {
	return clamp01(dot(normal, light)) / pi;
}
#define diffuse(v, n, l, r) diffuse_lambertian(n, l)
#endif

#if SHADOW_FILTER_TYPE == 2 || SHADOW_FILTER_TYPE == 3
const vec2[18] pcss_offset = vec2[18](
	vec2(-0.98685560, -0.03261871),
	vec2(-0.47958790,  0.23570540),
	vec2(-0.30706600, -0.15843290),
	vec2(-0.60807480,  0.01524314),
	vec2(-0.17485240,  0.49767420),
	vec2( 0.18764890,  0.45603400),
	vec2(-0.14323580,  0.75790890),
	vec2(-0.78102060, -0.44097930),
	vec2(-0.12428560, -0.78665660),
	vec2(-0.01482044, -0.48689910),
	vec2( 0.18829080,  0.71168610),
	vec2( 0.26197550, -0.61955050),
	vec2( 0.52478220,  0.61679990),
	vec2( 0.75702890,  0.08125463),
	vec2( 0.33045960, -0.31044460),
	vec2( 0.69684450, -0.61393110),
	vec2( 0.07468465,  0.99449370),
	vec2( 0.45471010, -0.78973980)
);
#endif

#if SHADOW_FILTER_TYPE != 3 || !defined SHADOW_COLORED
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
#endif

#if SHADOW_FILTER_TYPE == 1
vec3 softShadow(vec3 position) {
	const vec2[9] offset = vec2[9](
		vec2(-0.7, 0.7),
		vec2( 0.0, 1.0),
		vec2( 0.7, 0.7),
		vec2(-1.0, 0.0),
		vec2( 0.0, 0.0),
		vec2( 1.0, 0.0),
		vec2(-0.7,-0.7),
		vec2( 0.0,-1.0),
		vec2( 0.7,-0.7)
	);

	vec2 pixel = 1.0 / textureSize2D(shadowtex1, 0);

	vec3 result = vec3(0.0);
	for (int i = 0; i < offset.length(); i++) result += shadowSample(vec3(offset[i] * pixel + position.xy, position.z));

	return result / offset.length();
}
#elif SHADOW_FILTER_TYPE == 2
vec3 pcss(vec3 position, float angularRadius, float dither) {
	const float searchScale = 0.05;
	float spread = -tan(angularRadius) * projectionShadowInverse[2].z * projectionShadow[0].x;
	float searchRadius = spread * searchScale;

	dither *= tau;
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
#elif SHADOW_FILTER_TYPE == 3
vec3 lpcss(vec3 position, float angularRadius, float dither) {
	const float searchScale = 0.05;
	float spread = -tan(angularRadius) * projectionShadowInverse[2].z * projectionShadow[0].x;
	float searchRadius = spread * searchScale;

	dither *= tau;
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
#endif

vec3 shadows(vec3 position, vec3 shadowPosition, vec3 shadowClip, vec3 shadowCoord, float cloudShadow, float dither) {
	#if SHADOW_FILTER_TYPE == 2 || SHADOW_FILTER_TYPE == 3
	float angularRadius  = mix(moonAngularRadius, sunAngularRadius, smoothstep(-0.01, 0.01, dot(sunVector, upVector)));
	      angularRadius *= mix(10.0, 1.0, sqrt(cloudShadow));
	#endif

	#if SHADOW_FILTER_TYPE == 1
	vec3 result = softShadow(shadowCoord);
	#elif SHADOW_FILTER_TYPE == 2 || (SHADOW_FILTER_TYPE == 3 && !defined SHADOW_COLORED)
	vec3 result = pcss(shadowClip, angularRadius, dither);
	#elif SHADOW_FILTER_TYPE == 3
	vec3 result = lpcss(shadowClip, angularRadius, dither);
	#else
	vec3 result = shadowSample(shadowCoord);
	#endif

	#if CAUSTICS_SAMPLES > 0
	if (result != vec3(0.0))
		result *= waterCaustics(position, shadowPosition, shadowCoord);
	#endif

	return result;
}

#ifdef RTCS
bool checkContactShadowIntersection(vec3 position, vec3 interval, float depth, float difference, vec2 pixel) {
	vec2 dd = vec2(
		max(abs(texture2D(depthtex1, vec2( 1.0,  0.0) * pixel + position.st).r - depth),
		    abs(texture2D(depthtex1, vec2(-1.0,  0.0) * pixel + position.st).r - depth)),
		max(abs(texture2D(depthtex1, vec2( 0.0,  1.0) * pixel + position.st).r - depth),
		    abs(texture2D(depthtex1, vec2( 0.0, -1.0) * pixel + position.st).r - depth)));

	return difference < -maxof(dd) && min(-interval.z, position.z - delinearizeDepth(linearizeDepth(position.z, projectionInverse) - RTCS_SURFACE_THICKNESS, projection)) < difference;
}

float raytracedContactShadows(vec3 start, float dither) {
	vec2  pixel = 1.0 / textureSize2D(depthtex1, 0);

	vec3 direction = shadowLightVector * RTCS_RANGE / RTCS_SAMPLES;
	     direction = viewSpaceToScreenSpace(direction + screenSpaceToViewSpace(start, projectionInverse), projection) - start;

	// raytrace for intersection
	vec3  position    = direction * dither + start;
	float depth       = texture2D(depthtex1, position.st).r;
	float difference  = depth - position.p;
	bool  intersected = checkContactShadowIntersection(position, direction, depth, difference, pixel);

	float i;
	for (i = dither; i < RTCS_SAMPLES && !intersected; i++) {
		position   += direction;
		depth       = texture2D(depthtex1, position.st).r;
		difference  = depth - position.p;
		intersected = checkContactShadowIntersection(position, direction, depth, difference, pixel);
	}

	// validate intersection
	intersected = intersected && (difference + position.p) < 1.0 && position.p > 0.0 && floor(position.st) == vec2(0.0);

	return mix(1.0, smoothstep(0.5, 1.0, i / RTCS_SAMPLES), float(intersected));
}
#endif

float blockLight(float lightmap) {
	return lightmapCurve(lightmap, LIGHTMAP_FALLOFF_BLOCK);
}
float skyLight(float lightmap, vec3 normal) {
	return (dot(normal, upVector) * 0.2 + 0.8) * lightmapCurve(lightmap, LIGHTMAP_FALLOFF_SKY);
}

float handLight(vec3 position, vec3 normal) {
	// TODO: Make this accurate to standard block lighting

	if (heldBlockLightValue + heldBlockLightValue2 == 0) return 0.0;

	const mat2x3 handPosition = mat2x3(
		vec3( 1.4, -0.6, -1.0) * MC_HAND_DEPTH,
		vec3(-1.4, -0.6, -1.0) * MC_HAND_DEPTH
	);

	mat2x3 lightVector = handPosition - mat2x3(position, position);

	vec2 dist = clamp01((vec2(heldBlockLightValue, heldBlockLightValue2) - vec2(length(lightVector[0]), length(lightVector[1]))) * 0.0625);
	vec2 lm   = lightmapCurve(dist, LIGHTMAP_FALLOFF_BLOCK);

	lm *= vec2(
		diffuse(-normalize(position), normal, normalize(lightVector[0]), 0.0),
		diffuse(-normalize(position), normal, normalize(lightVector[1]), 0.0)
	) * pi;

	return lm.x + lm.y;
}

#ifdef HBAO
float hbao_depthFetch(vec2 c) {
	//return texture2D(depthtex2, c).r; // can result in incorrect occlusion

	vec2 r = vec2(viewWidth, viewHeight);
	vec4 g = textureGather(depthtex2, c);
	vec4 w = fract(c * r + 0.5).xxyy * vec4(1,-1,1,-1) + vec4(0,1,0,1);
	return dot(g, w.yxxy * w.zzww) + maxof(abs(g.xzxy - g.ywzw));
}

float hbao(vec3 position, vec3 direction, vec3 normal, float dither) {
	const float alpha = tau / HBAO_DIRECTIONS;

	#ifdef TEMPORAL_AA
	vec2 noise = hash22(vec2(dither, frameCounter % 16));
	#else
	vec2 noise = hash22(vec2(dither));
	#endif
	noise.x *= alpha;

	float result = 0.0;
	for (int i = 0; i < HBAO_DIRECTIONS; i++) {
		float angle = alpha * i + noise.x;
		vec3 dir = vec3(cos(angle), sin(angle), 0.0);

		vec3 pv = 1e-2 * dir + direction * 1e2;
		float cosHorizon = dot(direction, normalize(pv * dot(direction, normal) / dot(pv, normal) - direction));

		dir *= HBAO_RADIUS / HBAO_SAMPLES_DIRECTION;

		// Find cosine of the angle between view & horizon
		for (int j = 0; j < HBAO_SAMPLES_DIRECTION; j++) {
			vec2 sampleUV = viewSpaceToScreenSpace(dir * (j + noise.y) + position, projection).st;
			if (floor(sampleUV) != vec2(0.0)) break;
			vec3 samplePosition = screenSpaceToViewSpace(vec3(sampleUV, hbao_depthFetch(sampleUV)), projectionInverse);

			vec3 sampleVector = samplePosition - position;
			float distanceSquared = dot(sampleVector, sampleVector);

			if (distanceSquared > HBAO_RADIUS * HBAO_RADIUS) continue;

			cosHorizon = max(cosHorizon, dot(direction, sampleVector) * inversesqrt(distanceSquared));
		}

		// Add angle above horizon to result
		result += acos(clamp(cosHorizon, -1.0, 1.0));
	}

	return result / (HBAO_DIRECTIONS * pi * 0.5);
}
#endif

vec3 calculateLighting(mat3 position, vec3 direction, vec3 normal, vec2 lightmap, material mat, float dither, out vec3 sunVisibility) {
	direction = -direction;

	vec3 shadowPosition = mat3(shadowModelView) * position[2] + shadowModelView[3].xyz;
	vec3 shadowClip     = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * shadowPosition + projectionShadow[3].xyz;
	vec3 shadowCoord    = shadows_distortShadowSpace(shadowClip) * 0.5 + 0.5;

	float cloudShadow = texture2DLod(gaux2, shadowCoord.xy, 0.0).a;
	sunVisibility = vec3(cloudShadow);

	vec3 shadowLight = vec3(lightmap.y * lightmap.y);
	if (shadowLight != vec3(0.0)) {
		vec3 fakeSubsurface = (1.0 - mat.albedo) * sqrt(mat.albedo) * (max0(-dot(normal, shadowLightVector)) * 0.5 + 0.5) / pi;
		vec3 diffuse = fakeSubsurface * mat.subsurface + diffuse(direction, normal, shadowLightVector, mat.roughness);

		if (diffuse != vec3(0.0)) {
			sunVisibility *= shadows(position[2], shadowPosition, shadowClip, shadowCoord, cloudShadow, dither);
			#ifdef RTCS
			if (sunVisibility != vec3(0.0) && mat.subsurface == 0.0)
				sunVisibility *= raytracedContactShadows(position[0], dither);
			#endif
		} else {
			sunVisibility *= 0.0;
		}

		shadowLight *= diffuse * sunVisibility;
	} else {
		sunVisibility *= 0.0;
	}
	#if PROGRAM != PROGRAM_WATER && RSM_SAMPLES > 0
	vec3 rsm = bilateralResample(normal, position[1].z);
	shadowLight += rsm * cloudShadow;
	#endif

	float skyLight = skyLight(lightmap.y, normal);
	#if defined HBAO && PROGRAM != PROGRAM_WATER
	if (skyLight > 0.0)
		skyLight *= hbao(position[1], direction, normal, dither);
	#endif

	float blockLight = blockLight(lightmap.x) + handLight(position[1], normal);

	vec3
	lighting  = shadowLightColor * shadowLight;
	lighting += skyLightColor    * skyLight;
	lighting += blockLightColor  * blockLight;

	return lighting;
}
