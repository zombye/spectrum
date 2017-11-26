#include "/initialize.glsl"
#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Weather
uniform float rainStrength;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex7;

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

#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/get3DNoise.glsl"
#include "/lib/misc/shadowDistortion.glsl"

#if RSM_SAMPLES > 0
vec3 calculateReflectiveShadowMaps(vec3 position, vec3 normal, float dither) {
	const float radiusSquared = RSM_RADIUS * RSM_RADIUS;
	const float perSampleArea = radiusSquared / RSM_SAMPLES;
	const float sampleDistAdd = sqrt(perSampleArea) / 16.0;
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

		vec3 samplePosition = shadowClipPosition + vec3(sampleOffset, 0.0);
		vec2 sampleCoord    = shadows_distortShadowSpace(samplePosition.xy) * 0.5 + 0.5;
		     samplePosition = projectionInverseScale * vec3(samplePosition.xy, texture2D(shadowtex0, sampleCoord).r * 2.0 - 1.0) + projectionShadowInverse[3].xyz;

		vec3  sampleVector = shadowPosition - samplePosition;
		float sampleDistSq = dot(sampleVector, sampleVector);
		if (sampleDistSq > radiusSquared) continue;
		      sampleVector = sampleVector * inversesqrt(sampleDistSq);

		vec3 sampleNormal = texture2D(shadowcolor1, sampleCoord).rgb * 2.0 - 1.0; sampleNormal.z = abs(sampleNormal.z);
		float sampleVis = clamp01(dot(sampleVector, shadowNormal)) * clamp01(dot(sampleVector, sampleNormal)) * sampleNormal.z;

		if (sampleVis <= 0.0) continue;

		sampleDistSq += sampleDistAdd;

		vec4 sampleAlbedo = texture2D(shadowcolor0, sampleCoord);
		rsm += sampleAlbedo.rgb * sampleAlbedo.a * sampleVis / sampleDistSq;
	}

	return rsm * perSampleArea * RSM_BRIGHTNESS / pi;
}
#endif

#include "/lib/fragment/volumetricClouds.fsh"
float calculateCloudShadowMap() {
	vec3 shadowPos = vec3(screenCoord, 0.0) * 2.0 - 1.0;
	shadowPos.st /= 1.0 - length(shadowPos.st);
	shadowPos = transformPosition(transformPosition(shadowPos, projectionShadowInverse), shadowModelViewInverse);

	return volumetricClouds_shadow(shadowPos);
}

void main() {
	vec3 tex7; // id, specular alpha channel, skylight
	     tex7.rb = texture2D(colortex7, screenCoord).rg;
	     tex7.rg = unpack2x8(tex7.r);

	gl_FragData[0] = vec4(texture2D(colortex0, screenCoord).rgb, tex7.r);
	gl_FragData[1] = vec4(texture2D(colortex1, screenCoord).rgb, tex7.g);
	gl_FragData[2] = vec4(texture2D(colortex2, screenCoord).rgb, tex7.b);

	gl_FragData[3].a = calculateCloudShadowMap();

	#if RSM_SAMPLES > 0
	if (round(tex7.r * 255.0) == 0.0 || floor(screenCoord) != vec2(0.0) || tex7.b == 0.0) { exit(); return; }

	mat3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	backPosition[2] = viewSpaceToSceneSpace(backPosition[1], gbufferModelViewInverse);

	vec3 normal = unpackNormal(gl_FragData[2].rg);

	float dither = bayer16(gl_FragCoord.st);

	vec3 rsm = calculateReflectiveShadowMaps(backPosition[2], normal, dither * 256.0) * tex7.b * tex7.b;

/* DRAWBUFFERS:0125 */

	gl_FragData[3].rgb = rsm;
	#endif

	exit();
}
