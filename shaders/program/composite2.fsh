#include "/settings.glsl"

#define DOF_SAMPLES 0 // [0 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100]

const bool colortex4MipmapEnabled = true;

//----------------------------------------------------------------------------//

const float centerDepthHalflife = 2.0;
uniform float centerDepthSmooth; // has a big performance hit for some reason. TODO: Shader-side replacement until centerDepthSmooth performance is fixed

// Viewport
uniform float aspectRatio;
uniform float viewHeight;

// Samplers
uniform sampler2D colortex4; // composite

uniform sampler2D depthtex0;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/debug.glsl"

#include "/lib/util/constants.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/spaceConversion.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"

vec2 dofOffset(float index, float total, vec2 coc) {
	// TODO: Make these two constants part of the optical system settings so they can be properly integrated elsewhere
	const float anamorphic = sqrt(1.0);
	const float pincushion = 0.0;

	vec2 offset = sunflowerFloret(index, total);

	vec2 signedCoord = (offset * coc + screenCoord) * 2.0 - 1.0;

	float dist2 = dot(signedCoord * vec2(1.0, 1.0 / aspectRatio), signedCoord * vec2(1.0, 1.0 / aspectRatio));

	float sine = dot(normalize(signedCoord), vec2(0.0, 1.0 / aspectRatio));
	float cosi = dot(normalize(signedCoord), vec2(1.0, 0.0));

	float distort = dist2 * pincushion + 1.0;

	return mat2(cosi * distort, sine * distort, -sine / distort, cosi / distort) * offset * vec2(anamorphic, 1.0 / anamorphic);
}

vec3 depthOfField() {
	const float aperture = APERTURE_RADIUS;
	      float focal    = abs(aperture * projection[0].x); // I think this might be wrong...

	float depth = abs(linearizeDepth(texture2D(depthtex0, screenCoord).r, projectionInverse));
	float focus = abs(linearizeDepth(centerDepthSmooth, projectionInverse));

	vec2 circleOfConfusion = aperture * focal * abs(depth - focus) / (depth * abs(focus - focal) * vec2(aspectRatio, 1.0));

	float lod = log2(2.0 * viewHeight * circleOfConfusion.y / sqrt(DOF_SAMPLES) + 1.0);

	vec3 result = vec3(0.0);
	for (int i = 0; i < DOF_SAMPLES; i++) {
		result += texture2DLod(colortex4, dofOffset(i + 0.5, DOF_SAMPLES + 1.0, circleOfConfusion) * circleOfConfusion + screenCoord, lod).rgb;
	}
	return result / DOF_SAMPLES;
}

void main() {
	#if DOF_SAMPLES > 0
	vec3 color = depthOfField();
	#else
	vec3 color = texture2D(colortex4, screenCoord).rgb;
	#endif

/* DRAWBUFFERS:4 */

	gl_FragData[0] = vec4(color, 1.0);

	exit();
}
