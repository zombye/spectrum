#include "/settings.glsl"

const bool colortex5MipmapEnabled = true;

//----------------------------------------------------------------------------//

uniform float rainStrength;

// Time
uniform int   frameCounter;
uniform float frameTimeCounter;

// Viewport
uniform float viewWidth, viewHeight;

// Positions
uniform vec3 cameraPosition;

// Hand light
uniform int heldBlockLightValue, heldBlockLightValue2;

// Samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;

uniform sampler2D gaux2;

uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

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
#include "/lib/util/noise.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/get3DNoise.glsl"
#include "/lib/misc/lightmapCurve.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/sky/constants.glsl"
#include "/lib/sky/phaseFunctions.glsl"
#include "/lib/sky/main.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"

vec3 bilateralResample(vec3 normal, float depth) {
	const float filterLod = 2.0;
	const float range = 1.5;

	vec2 px = exp2(filterLod) / vec2(viewWidth, viewHeight);

	vec3 filtered = vec3(0.0);
	float totalWeight = 0.0;
	for (float i = -range; i <= range; i++) {
		for (float j = -range; j <= range; j++) {
			vec2 offset = vec2(i, j) * px;
			vec2 coord = clamp01(screenCoord + offset);

			vec3 normalSample = unpackNormal(textureRaw(colortex2, coord).rg);
			float depthSample = linearizeDepth(texture2D(depthtex1, coord).r, projectionInverse);

			float weight  = clamp01(dot(normal, normalSample));
			      weight *= 1.0 - clamp(abs(depth - depthSample), 0.0, 1.0);

			filtered += texture2DLod(gaux2, coord, filterLod).rgb * weight;
			totalWeight += weight;
		}
	}

	if (totalWeight == 0.0) { // fallback
		filtered = texture2DLod(gaux2, screenCoord, filterLod).rgb;
		totalWeight = 1.0;
	}

	filtered /= totalWeight;
	return filtered;
}

#include "/lib/fragment/water/constants.fsh"
#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/normal.fsh"
#include "/lib/fragment/water/caustics.fsh"

#include "/lib/fragment/clouds/layerParameters.fsh"
#include "/lib/fragment/clouds/density.fsh"
#include "/lib/fragment/clouds/main.fsh"

#include "/lib/fragment/lighting.fsh"

#include "/lib/fragment/specularBRDF.fsh"

//--//

void main() {
	gl_FragData[1].a = texture2D(gaux2, screenCoord).a;

	vec4 tex0 = texture2D(colortex0, screenCoord);
	masks mask = calculateMasks(round(tex0.a * 255.0));

	mat3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	backPosition[2] = viewSpaceToSceneSpace(backPosition[1], gbufferModelViewInverse);
	vec3 direction = normalize(backPosition[1]);

	float dither = bayer8(gl_FragCoord.st);

	vec3 composite = texture2D(colortex4, screenCoord).rgb;

	if (mask.sky) {
		composite = sky_render(composite, direction);
		composite = clouds_main(composite, vec3(0.0), direction, dither);
	} else {
		vec4 tex2 = texture2D(colortex2, screenCoord);
		vec3 normal   = unpackNormal(tex2.rg);
		vec2 lightmap = tex2.ba;

		material mat  = calculateMaterial(tex0.rgb, texture2D(colortex1, screenCoord), mask);

		composite  = calculateLighting(backPosition, direction, normal, lightmap, mat, dither, gl_FragData[1].rgb);
		composite *= mat.albedo;
		if (mat.reflectance > 0.0)
			composite *= 1.0 - f_dielectric(clamp01(dot(normal, -direction)), 1.0 / f0ToIOR(mat.reflectance));
		composite = mat.emittance * 1e2 + composite;
	}

/* DRAWBUFFERS:45 */

	gl_FragData[0] = vec4(composite * PRE_EXPOSURE_SCALE, 1.0);

	exit();
}
