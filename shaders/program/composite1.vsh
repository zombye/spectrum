#include "/settings.glsl"

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/uniform/gbufferMatrices.glsl"

void main() {
	calculateGbufferMatrices();

	gl_Position = ftransform();
	screenCoord = gl_Position.xy * 0.5 + 0.5;
}
