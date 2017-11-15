#include "/settings.glsl"

const bool colortex4MipmapEnabled = true;

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
uniform sampler2D colortex3; // temporal
uniform sampler2D colortex4; // composite

uniform sampler2D depthtex0;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/debug.glsl"

#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/spaceConversion.glsl"

#include "/lib/misc/temporalAA.glsl"

float calculateSmoothLuminance() {
	float prevLuminance = texture2D(colortex3, screenCoord).a;
	float currLuminance = clamp(dot(texture2DLod(colortex4, vec2(0.5), 100).rgb, lumacoeff_rec709) * prevLuminance / EXPOSURE, 3e0, 3e2);

	if (prevLuminance == 0.0) prevLuminance = 100.0;

	return mix(prevLuminance, currLuminance, frameTime / (1.0 + frameTime));
}

vec3 lowlightDesaturate(vec3 color) {
	float prevLuminance = texture2D(colortex3, screenCoord).a;
	if (prevLuminance == 0.0) prevLuminance = 100.0;
	color *= prevLuminance / EXPOSURE;

	float desaturated = dot(color, vec3(0.15, 0.50, 0.35));
	color = mix(color, vec3(desaturated), 1.0 / (1.0 + desaturated));

	return color * EXPOSURE / prevLuminance;
}

void main() {
	#ifdef TEMPORAL_AA
	vec3 color = taa_apply();
	#else
	vec3 color = texture2D(colortex4, screenCoord).rgb;
	#endif

/* DRAWBUFFERS:34 */

	gl_FragData[0] = vec4(color, calculateSmoothLuminance());
	gl_FragData[1] = vec4(lowlightDesaturate(color), 1.0);

	exit();
}
