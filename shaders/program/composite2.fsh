#include "/settings.glsl"

//#define MOTION_BLUR
#define MOTION_BLUR_SAMPLES 8

//----------------------------------------------------------------------------//

// Positions
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

// Viewport
uniform float viewWidth, viewHeight;

// Matrices
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;

// Samplers
uniform sampler2D colortex3;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/dither.glsl"

vec2 clampToScreen(vec2 coord) {
	vec2 lim = 0.5 / vec2(viewWidth, viewHeight);
	return clamp(coord, lim, 1.0 - lim);
}

vec3 motionBlur() {
	vec4 position = vec4(screenCoord, texture2D(depthtex0, screenCoord).r, 1.0) * 2.0 - 1.0;
	vec4 previousPosition = gbufferModelViewInverse * gbufferProjectionInverse * position;
	previousPosition /= previousPosition.w;
	previousPosition.xyz += cameraPosition - previousCameraPosition;
	previousPosition = gbufferPreviousProjection * gbufferPreviousModelView * previousPosition;
	previousPosition /= previousPosition.w;

	vec2 velocity = position.xy - previousPosition.xy;
	velocity *= 0.5 / MOTION_BLUR_SAMPLES;

	vec2 sampleCoord = velocity * bayer8(gl_FragCoord.st) + screenCoord;

	vec3 color = vec3(0.0);
	for (float i = 0.0; i < MOTION_BLUR_SAMPLES; i++, sampleCoord += velocity) {
		color += texture2DLod(colortex6, clampToScreen(sampleCoord), 0.0).rgb;
	}
	return color / MOTION_BLUR_SAMPLES;
}

void main() {
	#ifdef MOTION_BLUR
	vec3 color = motionBlur();
	#else
	vec3 color = texture2D(colortex6, screenCoord).rgb;
	#endif

/* DRAWBUFFERS:67 */

	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = texture2D(colortex3, screenCoord);
}
