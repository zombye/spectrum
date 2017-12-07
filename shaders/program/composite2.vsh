#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform int isEyeInWater;

// Time
uniform int frameCounter;

// Viewport
uniform float viewWidth, viewHeight;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/misc/temporalAA.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"

void main() {
	calculateGbufferMatrices();

	gl_Position = ftransform();
	screenCoord = gl_Position.xy * 0.5 + 0.5;
}
