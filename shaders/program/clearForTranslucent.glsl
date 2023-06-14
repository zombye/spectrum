/*\
 * Program Description:
 * Clears colortex3 to let forward rendered objects write to it properly
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex3;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* RENDERTARGETS: 3 */

	layout (location = 0) out vec4 colortex3Write;

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		colortex3Write = vec4(0.0);
	}
#endif
