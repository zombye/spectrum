#include "/settings.glsl"

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"

#include "/lib/uniform/vectors.glsl"
#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

void main() {
	#if !defined RSM && DIRECTIONAL_SKY_DIFFUSE == OFF
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	#else
	gl_Position = ftransform();
	screenCoord = gl_Position.xy * 0.5 + 0.5;
	screenCoord /= COMPOSITE0_SCALE;

	calculateVectors();
	calculateColors();
	calculateGbufferMatrices();
	calculateShadowMatrices();
	#endif
}
