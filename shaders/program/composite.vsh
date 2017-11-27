#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform float rainStrength;

uniform int isEyeInWater;

uniform vec3 cameraPosition;

// Time
uniform int frameCounter;

// Viewport
uniform float viewWidth, viewHeight;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"

#include "/lib/misc/temporalAA.glsl"

#include "/lib/sky/constants.glsl"
#include "/lib/sky/phaseFunctions.glsl"

#include "/lib/uniform/vectors.glsl"
#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

void main() {
	gl_Position = ftransform();
	screenCoord = gl_Position.xy * 0.5 + 0.5;

	calculateVectors();
	calculateColors();
	calculateGbufferMatrices();
	calculateShadowMatrices();
}
