/*\
 * Program Description:
 * Simple passthrough for now.
 * Just used to flip colortex6 so we get back the sky image.
\*/

//--// Uniforms

uniform sampler2D colortex4;

#if STAGE == STAGE_VERTEX

	//--// Vertex Outputs

	out vec2 screenCoord;

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	//--// Fragment Outputs

	/* DRAWBUFFERS:4 */

	layout (location = 0) out vec4 colortex4Write;

	//--// Fragment Functions

	void main() {
		colortex4Write = texture(colortex4, screenCoord);
	}
#endif
