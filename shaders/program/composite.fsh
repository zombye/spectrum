#include "/settings.glsl"

const bool gaux1MipmapEnabled = true;

#define REFRACTIONS 0 // [0 1 2]

//----------------------------------------------------------------------------//

uniform float rainStrength;
uniform float wetness;

uniform ivec2 eyeBrightness;

uniform int isEyeInWater;

// Viewport
uniform float viewWidth, viewHeight;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Samplers
uniform sampler2D colortex0; // gbuffer0
uniform sampler2D colortex1; // gbuffer1
uniform sampler2D colortex2; // gbuffer2
uniform sampler2D colortex3; // temporal
uniform sampler2D gaux1;     // composite
uniform sampler2D gaux2;     // aux0
uniform sampler2D colortex6; // aux1
uniform sampler2D colortex7; // aux2

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
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
#include "/lib/util/noise.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/get3DNoise.glsl"
#include "/lib/misc/importanceSampling.glsl"
#include "/lib/misc/lightmapCurve.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/sky/constants.glsl"
#include "/lib/sky/phaseFunctions.glsl"
#include "/lib/sky/main.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/normal.fsh"
#include "/lib/fragment/water/caustics.fsh"

#include "/lib/fragment/flatClouds.fsh"
#include "/lib/fragment/volumetricClouds.fsh"

#include "/lib/fragment/fog.fsh"

#include "/lib/fragment/raytracer.fsh"
#include "/lib/fragment/specularBRDF.fsh"
#include "/lib/fragment/reflections.fsh"

vec3 calculateRefractions(vec3 frontPosition, vec3 frontNormal, masks mask, inout vec3 direction, inout vec3 backPosition) {
	vec2 refractedCoord = screenCoord;

	#if REFRACTIONS != 0
	#if REFRACTIONS == 1
	if (frontPosition != backPosition && mask.water) {
	#else
	if (frontPosition != backPosition) {
	#endif
		vec3 rayDirection = refract(direction, frontNormal, 0.75);

		vec3 refractedPosition = rayDirection * clamp01(distance(frontPosition, backPosition)) + frontPosition;
		refractedPosition = viewSpaceToScreenSpace(refractedPosition, projection);

		float refractedDepth = texture2D(depthtex1, refractedPosition.st).r;
		if (refractedDepth > delinearizeDepth(frontPosition.z, projection)) {
			refractedPosition.z = refractedDepth;
			refractedCoord = refractedPosition.st;

			backPosition = screenSpaceToViewSpace(refractedPosition, projectionInverse);
		}
	}
	#endif

	return texture2D(gaux1, refractedCoord).rgb / PRE_EXPOSURE_SCALE;
}

//--//

void main() {
	vec4 tex0 = texture2D(colortex0, screenCoord);
	vec4 tex2 = texture2D(colortex2, screenCoord);
	vec3 tex7 = texture2D(colortex7, screenCoord).rgb;
	vec3 frontNormal = unpackNormal(tex7.rg);
	tex7.rg = unpack2x8(tex7.b);

	masks mask = calculateMasks(round(tex0.a * 255.0), round(tex7.r * 255.0));

	vec2  lightmap      = tex2.ba;
	float frontSkylight = tex7.g;

	mat2x3 frontPosition;
	frontPosition[0] = vec3(screenCoord, texture2D(depthtex0, screenCoord).r);
	frontPosition[1] = screenSpaceToViewSpace(frontPosition[0], projectionInverse);
	mat2x3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	vec3 direction = normalize(backPosition[1]);

	vec3 refractedPosition = backPosition[1];
	vec3 composite = calculateRefractions(frontPosition[1], frontNormal, mask, direction, refractedPosition);

	float dither = bayer8(gl_FragCoord.st);

	#ifdef MC_SPECULAR_MAP
	if (!mask.sky) {
		material mat = calculateMaterial(tex0.rgb, texture2D(colortex1, screenCoord), mask);
		vec3 normal  = unpackNormal(tex2.rg);

		#ifdef TOTAL_INTERNAL_REFLECTION
		float eta = isEyeInWater == 1 ? f0ToIOR(mat.reflectance) : 1.0 / f0ToIOR(mat.reflectance);
		#else
		float eta = 1.0 / f0ToIOR(mat.reflectance);
		#endif

		vec3 specular = calculateReflections(backPosition, direction, normal, eta, mat.roughness, lightmap, texture2D(gaux2, screenCoord).rgb, dither);
		composite = blendMaterial(composite, specular, mat);
	}
	#endif

	if (mask.water) {
		if (isEyeInWater != 1) {
			composite = waterFog(composite, frontPosition[1], refractedPosition, frontSkylight, dither);
		} else {
			composite = fog(composite, frontPosition[1], refractedPosition, lightmap, dither);
			// TODO: Fake crepuscular rays here as well
		}
	}

	vec4 transparent = texture2D(colortex6, screenCoord);
	composite = composite * (1.0 - transparent.a) + (transparent.rgb / PRE_EXPOSURE_SCALE);

	if (isEyeInWater == 1) {
		composite = waterFog(composite, vec3(0.0), frontPosition[1], mask.water ? frontSkylight : lightmap.y, dither);
	} else {
		composite  = fog(composite, vec3(0.0), frontPosition[1], lightmap, dither);
		composite += fakeCrepuscularRays(direction, dither);
	}

	float prevLuminance = texture2D(colortex3, screenCoord).a;
	if (prevLuminance == 0.0) prevLuminance = 100.0;
	composite *= EXPOSURE / prevLuminance;

/* DRAWBUFFERS:4 */

	gl_FragData[0] = vec4(composite, 1.0);

	exit();
}
