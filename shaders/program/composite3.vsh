#include "/settings.glsl"

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

void main() {
	gl_Position = ftransform();
	screenCoord = gl_Position.xy * 0.5 + 0.5;
}
