#include "/settings.glsl"

//----------------------------------------------------------------------------//

void main() {
	// Hardcoded to ensure entire screen is covered.
	     if (gl_VertexID == 1) gl_Position = vec4( 3.0,-1.0, 0.0, 1.0);
	else if (gl_VertexID == 2) gl_Position = vec4(-1.0, 3.0, 0.0, 1.0);
	else                       gl_Position = vec4(-1.0,-1.0, 0.0, 1.0);
}
