/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

//--// Shared Functions

#if defined STAGE_VERTEX
	//--// Vertex Functions

	void main() {
		gl_Position = vec4(1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Functions

	void main() {
		discard;
	}
#endif
