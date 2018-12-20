/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Functions

	void main() {
		gl_Position = vec4(1.0);
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Functions

	void main() {
		discard;
	}
#endif
