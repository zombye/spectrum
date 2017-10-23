#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Time
uniform int frameCounter;

// Viewport
uniform float viewWidth, viewHeight;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"

#include "/lib/misc/temporalAA.glsl"

#include "/lib/uniform/vectors.glsl"
#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

void main() {
	gl_Position = ftransform();
	screenCoord = gl_Position.xy * 0.5 + 0.5;
	screenCoord /= COMPOSITE0_SCALE;

	calculateVectors();
	calculateColors();
	calculateGbufferMatrices();
	calculateShadowMatrices();
}
