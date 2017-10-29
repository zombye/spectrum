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

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

vec2 spiralPoint(float angle, float scale) {
	return vec2(sin(angle), cos(angle)) * pow(angle / scale, 1.0 / phi);
}

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/normal.fsh"

float calculateWaterCaustics(vec3 position, float skylight) {
	#if CAUSTICS_SAMPLES == 0
	return 1.0;
	#endif

	vec3 shadowPosCur = transformPosition(position, shadowModelView);
	vec2 shadowCoord = shadows_distortShadowSpace((mat3(projectionShadow) * shadowPosCur + projectionShadow[3].xyz).xy) * 0.5 + 0.5;

	if (texture2D(shadowcolor1, shadowCoord).b > 0.5 || skylight == 0.0)
		return 1.0;

	const int   samples           = CAUSTICS_SAMPLES;
	const float radius            = CAUSTICS_RADIUS;
	const float defocus           = CAUSTICS_DEFOCUS;
	const float distancePower     = CAUSTICS_DISTANCE_POWER;
	const float distanceThreshold = (sqrt(samples) - 1.0) / (radius * defocus);
	const float resultPower       = CAUSTICS_RESULT_POWER;

	vec3  lightVector       = mat3(gbufferModelViewInverse) * -shadowLightVector;
	vec3  flatRefractVector = refract(lightVector, vec3(0.0, 1.0, 0.0), 0.75);
	float surfDistUp        = shadowPosCur.z - (projectionShadowInverse[2].z * (texture2D(shadowtex0, shadowCoord).r * 2.0 - 1.0) + projectionShadowInverse[3].z);
	      surfDistUp       *= lightVector.y / flatRefractVector.y;
	float dither            = bayer4(gl_FragCoord.st) * 16.0;

	position += cameraPosition;

	vec3 surfPos = position - flatRefractVector * (surfDistUp / flatRefractVector.y);

	float result = 0.0;
	for (float i = 0.0; i < samples; i++) {
		vec3 samplePos     = surfPos;
		     samplePos.xz += spiralPoint(i * 16.0 + dither, samples * 16.0) * radius;
		vec3 refractVector = refract(lightVector, water_calculateNormal(samplePos), 0.75);
		     samplePos     = refractVector * (surfDistUp / refractVector.y) + samplePos;

		result += pow(1.0 - clamp01(distance(position, samplePos) * distanceThreshold), distancePower);
	}

	return pow(result * distancePower / (defocus * defocus), resultPower);
}

vec3 calculateReflectiveShadowMaps(vec3 position, vec3 normal, float skylight) {
	#if RSM_SAMPLES > 0
	if (skylight == 0.0)
	#endif
		return vec3(0.0);

	const float radiusSquared = RSM_RADIUS * RSM_RADIUS;
	const float perSampleArea = radiusSquared / RSM_SAMPLES;
	      float offsetScale   = RSM_RADIUS * projectionShadow[0].x;

	vec3 projectionScale        = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z);
	vec3 projectionInverseScale = vec3(projectionShadowInverse[0].x, projectionShadowInverse[1].y, projectionShadowInverse[2].z);

	vec3  shadowPosition     = mat3(shadowModelView) * position + shadowModelView[3].xyz;
	vec3  shadowClipPosition = projectionScale * shadowPosition + projectionShadow[3].xyz;
	vec3  shadowNormal       = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * -normal;
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

		vec3 samplePosition = projectionInverseScale * vec3(shadowClipPosition.xy + sampleOffset, texture2D(shadowtex0, sampleCoord).r * 2.0 - 1.0) + projectionShadowInverse[3].xyz;

		vec3  sampleVector = shadowPosition - samplePosition;
		float sampleDistSq = dot(sampleVector, sampleVector);
		if (sampleDistSq > radiusSquared) continue;
		      sampleVector = sampleVector * inversesqrt(sampleDistSq);

		vec3 sampleNormal = texture2D(shadowcolor1, sampleCoord.st).rgb * 2.0 - 1.0; sampleNormal.z = abs(sampleNormal.z);
		float sampleVis = max0(dot(sampleVector, shadowNormal)) * max0(dot(sampleVector, sampleNormal)) * sampleNormal.z;

		if (sampleVis <= 0.0) continue;

		// Kind of approximate an area light
		sampleDistSq += perSampleArea;

		vec4 sampleAlbedo = texture2D(shadowcolor0, sampleCoord.st);
		rsm += sampleAlbedo.rgb * sampleAlbedo.a * sampleVis / sampleDistSq;
	}

	return rsm * skylight * skylight * perSampleArea * RSM_BRIGHTNESS;
}

//--//

void main() {
	#if CAUSTICS_SAMPLES == 0 && RSM_SAMPLES == 0
	discard;
	#endif

	vec3 tex1 = textureRaw(colortex1, screenCoord).rgb;

	if (round(tex1.r * 255.0) == 0.0 || floor(screenCoord) != vec2(0.0)) { gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); return; }

	mat3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	backPosition[2] = viewSpaceToSceneSpace(backPosition[1], gbufferModelViewInverse);

	vec3  normal   = unpackNormal(textureRaw(colortex2, screenCoord).rg);
	float skylight = tex1.b;

	//--//

	vec3 rsm = calculateReflectiveShadowMaps(backPosition[2], normal, skylight) * shadowLightColor;
	float caustics = calculateWaterCaustics(backPosition[2], skylight);

/* DRAWBUFFERS:3 */

	gl_FragData[0] = vec4(rsm, caustics);
}
