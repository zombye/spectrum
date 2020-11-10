/*\
 * Copies downsampled tiles, in order to merge some passes during upsample step
 * I'd prefer to not do this, but with the current limitations I don't have enough passes if I don't.
\*/

//--// Settings //------------------------------------------------------------//

#define SOURCE_SAMPLER colortex6

const int countInstances = 4;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D SOURCE_SAMPLER;

uniform int instanceId;

//--// Custom uniforms

uniform vec2 viewPixelSize;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		// based on instance
		int lod = instanceId * 2;

		vec2 vertPos = gl_Vertex.xy * exp2(-lod) / 2.0;
		     vertPos = vertPos + 1.0 - exp2(-lod);
		gl_Position = vec4(vertPos * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:6 */

	out vec3 fragColor;

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		fragColor = texelFetch(SOURCE_SAMPLER, ivec2(gl_FragCoord.xy), 0).rgb;
	}
#endif
