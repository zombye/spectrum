#include "/initialize.glsl"
#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform int isEyeInWater;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Samplers
uniform sampler2D colortex1; // gbuffer1 | ID, lightmap
uniform sampler2D colortex2; // gbuffer2 | Normal, Specular

uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/debug.glsl"

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/get3DNoise.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/normal.fsh"

vec3 calculateReflectiveShadowMaps(vec3 position, vec3 normal, float dither) {
	#if RSM_SAMPLES == 0
	return vec3(0.0);
	#endif

	const float radiusSquared = RSM_RADIUS * RSM_RADIUS;
	const float perSampleArea = radiusSquared / RSM_SAMPLES;
	      float offsetScale   = RSM_RADIUS * projectionShadow[0].x;

	vec3 projectionScale        = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z);
	vec3 projectionInverseScale = vec3(projectionShadowInverse[0].x, projectionShadowInverse[1].y, projectionShadowInverse[2].z);

	vec3 shadowPosition     = mat3(shadowModelView) * position + shadowModelView[3].xyz;
	vec3 shadowClipPosition = projectionScale * shadowPosition + projectionShadow[3].xyz;
	vec3 shadowNormal       = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * -normal;

	vec3 rsm = vec3(0.0);
	for (float i = 0.0; i < RSM_SAMPLES; i += 1.0) {
		vec2 sampleOffset = spiralPoint(i * 256.0 + dither, RSM_SAMPLES * 256.0) * offsetScale;

		// Discard samples that definitely can't contribute ASAP
		if (dot(shadowNormal.xy, sampleOffset) > 0.0) continue;

		vec2  sampleCoord  = shadowClipPosition.xy + sampleOffset;
		float distortCoeff = shadows_calculateDistortionCoeff(sampleCoord);
		      sampleCoord *= distortCoeff;
		      sampleCoord  = sampleCoord * 0.5 + 0.5;

		vec3 samplePosition = projectionInverseScale * vec3(shadowClipPosition.xy + sampleOffset, texture2D(shadowtex0, sampleCoord).r * 2.0 - 1.0) + projectionShadowInverse[3].xyz;

		vec3  sampleVector = shadowPosition - samplePosition;
		float sampleDistSq = dot(sampleVector, sampleVector);
		if (sampleDistSq > radiusSquared) continue;
		      sampleVector = sampleVector * inversesqrt(sampleDistSq);

		vec3 sampleNormal = texture2D(shadowcolor1, sampleCoord.st).rgb * 2.0 - 1.0; sampleNormal.z = abs(sampleNormal.z);
		float sampleVis = clamp01(dot(sampleVector, shadowNormal)) * clamp01(dot(sampleVector, sampleNormal)) * sampleNormal.z;

		if (sampleVis <= 0.0) continue;

		// Approximate an area light
		sampleDistSq += pow2(RSM_RADIUS / RSM_SAMPLES);

		vec4 sampleAlbedo = texture2D(shadowcolor0, sampleCoord.st);
		rsm += sampleAlbedo.rgb * sampleAlbedo.a * sampleVis / sampleDistSq;
	}

	return rsm * perSampleArea * RSM_BRIGHTNESS / pi;
}

#include "/lib/fragment/volumetricClouds.fsh"

float calculateCloudShadowMap() {
	vec3 shadowPos = vec3(screenCoord * COMPOSITE0_SCALE, 0.0) * 2.0 - 1.0;
	shadowPos.st /= 1.0 - length(shadowPos.st);
	shadowPos = transformPosition(transformPosition(shadowPos, projectionShadowInverse), shadowModelViewInverse);

	return volumetricClouds_shadow(shadowPos);
}

//--//

void main() {
	gl_FragData[0].a = calculateCloudShadowMap();

	#if RSM_SAMPLES == 0
	exit(); return;
	#endif

	vec2 id_skylight = textureRaw(colortex1, screenCoord).rb;

	if (round(id_skylight.r * 255.0) == 0.0 || floor(screenCoord) != vec2(0.0) || id_skylight.g == 0.0) { exit(); return; }

	mat3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	backPosition[2] = viewSpaceToSceneSpace(backPosition[1], gbufferModelViewInverse);

	vec3 normal = unpackNormal(textureRaw(colortex2, screenCoord).rg);

	float dither = bayer16(gl_FragCoord.st);

	vec3 rsm = calculateReflectiveShadowMaps(backPosition[2], normal, dither * 16.0) * id_skylight.g * id_skylight.g;

/* DRAWBUFFERS:5 */

	gl_FragData[0].rgb = rsm;

	exit();
}
