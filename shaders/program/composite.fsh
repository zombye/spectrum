#include "/initialize.glsl"
#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform int isEyeInWater;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex6;

uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

// Generate a point along a spiral. Integer increments of angle will have a uniform distribution.
vec2 spiralPoint(float angle, float scale) {
	return vec2(sin(angle), cos(angle)) * pow(angle / scale, 1.0 / phi);
}

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/importanceSampling.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/parallax.fsh"
#include "/lib/fragment/water/normal.fsh"
#include "/lib/fragment/water/caustics.fsh"

//--//

#include "/lib/fragment/raytracer.fsh"
#include "/lib/fragment/sky.fsh"

#if DIRECTIONAL_SKY_DIFFUSE != OFF
vec3 calculateDirectionalSkyDiffuse(vec3 position, vec3 normal, vec2 lightmap) {
	vec3 temp = vec3(0.0);
	vec3 result = vec3(0.0);

	if (lightmap.y <= 0.0) return vec3(0.0);

	float dither = bayer16(gl_FragCoord.st) + (0.5 / 256.0);

	for (float i = 0.0; i < DIRECTIONAL_SKY_DIFFUSE_SAMPLES; i++) {
		vec3 rayDir = is_lambertian(normal, hash42(vec2(i, dither)));

		#if DIRECTIONAL_SKY_DIFFUSE == FANCY
		if (raytraceIntersection(position, rayDir, temp, dither, 4.0)) continue;
		result += sky_atmosphere(vec3(0.0), rayDir);
		#else
		float mul = clamp01(dot(rayDir, upVector) + 0.6);
		result += sky_atmosphere(vec3(0.0), rayDir) * mul;
		#endif
	}
	result /= DIRECTIONAL_SKY_DIFFUSE_SAMPLES;

	result *= lightmap.y / (pow2(-4.0 * lightmap.y + 4.0) + 1.0);

	return result;
}
#endif

#ifdef RSM
vec3 calculateReflectiveShadowMaps(vec3 position, vec3 normal, vec2 lightmap) {
	const float radiusSquared = RSM_RADIUS * RSM_RADIUS;
	const float perSampleArea = radiusSquared / RSM_SAMPLES;
	      float offsetScale   = RSM_RADIUS * projectionShadow[0].x;

	vec3 projectionScale        = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z);
	vec3 projectionInverseScale = vec3(projectionShadowInverse[0].x, projectionShadowInverse[1].y, projectionShadowInverse[2].z);

	vec3  shadowPosition     = mat3(modelViewShadow) * position + modelViewShadow[3].xyz;
	vec3  shadowClipPosition = projectionScale * shadowPosition + projectionShadow[3].xyz;
	vec3  shadowNormal       = mat3(modelViewShadow) * mat3(modelViewInverse) * -normal;
	float dither             = bayer16(gl_FragCoord.st) * 256.0;

	vec3 rsm = vec3(0.0);
	for (float i = 0.0; i < RSM_SAMPLES; i += 1.0) {
		vec2 sampleOffset = spiralPoint(i * 256.0 + dither, RSM_SAMPLES * 256.0) * offsetScale;

		// Discard samples that definitely can't contribute ASAP
		if (dot(shadowNormal.xy, sampleOffset) > 0.0) continue;

		vec2  sampleCoord  = shadowClipPosition.xy + sampleOffset;
		float distortCoeff = shadows_calculateDistortionCoeff(sampleCoord);
		      sampleCoord *= distortCoeff;
		      sampleCoord  = sampleCoord * 0.5 + 0.5;

		vec3 samplePosition = projectionInverseScale * vec3(shadowClipPosition.xy + sampleOffset, texture2DLod(shadowtex0, sampleCoord, 1.0 / distortCoeff).r * 2.0 - 1.0) + projectionShadowInverse[3].xyz;

		vec3  sampleVector = shadowPosition - samplePosition;
		float sampleDistSq = dot(sampleVector, sampleVector);
		if (sampleDistSq > radiusSquared) continue;
		      sampleVector = sampleVector * inversesqrt(sampleDistSq);

		vec3 sampleNormal = texture2DLod(shadowcolor1, sampleCoord.st, 3.0 / distortCoeff).rgb * 2.0 - 1.0;
		float sampleVis = max0(dot(sampleVector, shadowNormal)) * max0(dot(sampleVector, sampleNormal)) * sampleNormal.z;

		if (sampleVis <= 0.0) continue;

		// Kind of approximate an area light
		sampleDistSq += perSampleArea;

		vec4 sampleAlbedo = texture2DLod(shadowcolor0, sampleCoord.st, 3.0 / distortCoeff);
		rsm += sampleAlbedo.rgb * sampleAlbedo.a * sampleVis / sampleDistSq;
	}
	return rsm * perSampleArea / pi;
}
#endif

//--//

void main() {
	#if !defined RSM && DIRECTIONAL_SKY_DIFFUSE == OFF
	discard;
	#else

	vec3 tex0 = textureRaw(colortex0, screenCoord).rgb;

	float id = round(unpack2x8(tex0.g).y * 255.0);

	if (id == 0.0 || floor(screenCoord) != vec2(0.0)) { gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); return; }

	mat3 position;
	position[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	#if defined RSM || defined CAUSTCS
	position[1] = screenSpaceToViewSpace(position[0], projectionInverse);
	position[2] = viewSpaceToSceneSpace(position[1], modelViewInverse);
	#endif

	vec3 normal   = unpackNormal(textureRaw(colortex1, screenCoord).rg);
	vec2 lightmap = unpack2x8(tex0.b);

	//--//

	vec3 additive = vec3(0.0);
	#if DIRECTIONAL_SKY_DIFFUSE != OFF
	additive += calculateDirectionalSkyDiffuse(position[0], normal, lightmap);
	#endif
	#ifdef RSM
	additive += calculateReflectiveShadowMaps(position[2], normal, lightmap) * shadowLightColor * RSM_INTENSITY;
	#endif
	float caustics = 1.0;
	bool waterMask = abs(unpack2x8(textureRaw(colortex6, screenCoord).b).r * 255.0 - 8.5) < 0.6;
	if ((isEyeInWater == 1) != waterMask) caustics *= water_calculateCaustics(position[2] + cameraPosition, lightmap.y);

/* DRAWBUFFERS:3 */

	gl_FragData[0] = vec4(additive, caustics);

	#endif
}
