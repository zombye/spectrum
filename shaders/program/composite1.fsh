#include "/settings.glsl"

const bool colortex6MipmapEnabled = true;

//----------------------------------------------------------------------------//

// Time
uniform int   frameCounter;
uniform float frameTime;

// Positions
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

// Viewport
uniform float viewWidth, viewHeight;

// Matrices
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform mat4 gbufferPreviousProjectionInverse;

// Samplers
uniform sampler2D colortex6; // composite
uniform sampler2D colortex7; // temporal

uniform sampler2D depthtex0;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/spaceConversion.glsl"

#include "/lib/misc/temporalAA.glsl"

float calculateSmoothLuminance() {
	float prevLuminance = texture2D(colortex7, screenCoord).a;
	float currLuminance = clamp(dot(texture2DLod(colortex6, vec2(0.5), 100).rgb, lumacoeff_rec709) * prevLuminance / EXPOSURE, 20.0, 8e3);

	if (prevLuminance == 0.0) prevLuminance = 0.35;

	return mix(prevLuminance, currLuminance, frameTime / (1.0 + frameTime));
}

void main() {
	vec3 color = texture2D(colortex6, screenCoord).rgb;

	#ifdef TEMPORAL_AA
	// Reproject for previous color
	vec3 reprojectedPosition = taa_reproject(vec3(screenCoord, texture2D(depthtex0, screenCoord).r));

	float blendWeight = 0.85;
	if (floor(reprojectedPosition.xy) != vec2(0.0)) blendWeight = 0.0;

	// Get the color for the previous frame
	vec3 prevColor = texture2D(colortex7, reprojectedPosition.st).rgb;

	// Apply a simple tonemap, blend with previous frame, and reverse the tonemap
	color     /= 1.0 + color;
	prevColor /= 1.0 + prevColor;
	color = mix(color, prevColor, blendWeight);
	color /= 1.0 - color;
	#endif

/* DRAWBUFFERS:67 */

	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(color, calculateSmoothLuminance());
}
