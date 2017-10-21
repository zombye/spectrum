#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Time
uniform float frameTimeCounter;

// Viewport
uniform float viewWidth, viewHeight;

// Positions
uniform vec3 cameraPosition;

// Hand light
uniform int heldBlockLightValue, heldBlockLightValue2;

// Samplers
uniform sampler2D colortex0; // gbuffer0
uniform sampler2D colortex1; // gbuffer1
uniform sampler2D colortex2; // gbuffer2

uniform sampler2D colortex3; // aux0 | GI & Water caustics

uniform sampler2D depthtex1;

uniform sampler2D shadowtex1;

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

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"
#include "/lib/fragment/raytracer.fsh"

vec4 bilateralResample(vec3 normal, float depth) {
	const float range = 3.0;
	vec2 px = 1.0 / (COMPOSITE0_SCALE * vec2(viewWidth, viewHeight));

	vec4 filtered = vec4(0.0);
	vec2 totalWeight = vec2(0.0);
	for (float i = -range; i <= range; i++) {
		for (float j = -range; j <= range; j++) {
			vec2 offset = vec2(i, j) * px;
			vec2 coord = clamp01(screenCoord + offset);

			vec3 normalSample = unpackNormal(texture2D(colortex1, coord).rg);
			float depthSample = linearizeDepth(texture2D(depthtex1, coord).r, projectionInverse);

			vec2 weight = vec2(max0(dot(normal, normalSample)), float(i == 0.0 && j == 0.0));
			weight.x *= 1.0 - clamp(abs(depth - depthSample), 0.0, 1.0);

			filtered += texture2D(colortex3, coord * COMPOSITE0_SCALE) * weight.xxxy;
			totalWeight += weight;
		}
	}

	if (totalWeight.x == 0.0) return vec4(0.0);

	filtered /= totalWeight.xxxy;
	return filtered;
}

#include "/lib/fragment/lighting.fsh"

//--//

void main() {
	vec3 tex0 = textureRaw(colortex0, screenCoord).rgb;

	vec4 diff_id = vec4(unpack2x8(tex0.r), unpack2x8(tex0.g));

	masks mask = calculateMasks(diff_id.a * 255.0);

	if (mask.sky) discard;

	mat3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	backPosition[2] = viewSpaceToSceneSpace(backPosition[1], gbufferModelViewInverse);

	vec3 tex1 = textureRaw(colortex1, screenCoord).rgb;

	material mat  = calculateMaterial(diff_id.rgb, unpack2x8(tex1.b), mask);
	vec3 normal   = unpackNormal(tex1.rg);
	vec2 lightmap = unpack2x8(tex0.b);

	vec3
	composite  = calculateLighting(backPosition, normal, lightmap, mat, gl_FragData[1].rgb);
	composite *= mat.albedo;

/* DRAWBUFFERS:63 */

	gl_FragData[0] = vec4(composite, 1.0);
}
