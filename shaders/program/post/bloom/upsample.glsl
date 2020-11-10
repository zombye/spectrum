//--// Settings //------------------------------------------------------------//

#define UPSAMPLE_BICUBIC

//--// Uniforms //------------------------------------------------------------//

#define SOURCE_SAMPLER colortex6
uniform sampler2D SOURCE_SAMPLER;

//--// Custom uniforms

uniform vec2 viewPixelSize;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		// based on upsample lod, place quad in different locations
		vec2 vertPos = gl_Vertex.xy * exp2(-UPSAMPLE_LOD) / 2.0;
		     vertPos = vertPos + 1.0 - exp2(-UPSAMPLE_LOD);
		gl_Position = vec4(vertPos * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:6 */

	out vec4 fragColor;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		vec2 uv = viewPixelSize * gl_FragCoord.xy;
		vec2 srcUv = uv * 0.5 + 0.5;
		#ifdef UPSAMPLE_BICUBIC
		fragColor.rgb = TextureCubic(SOURCE_SAMPLER, srcUv).rgb;
		#else
		fragColor.rgb = texture(SOURCE_SAMPLER, srcUv).rgb;
		#endif

		// Weigh lods
		const float[7] weights = float[7](1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0);
		const float wSum = weights[0] + weights[1] + weights[2] + weights[3] + weights[4] + weights[5] + weights[6];

		#if UPSAMPLE_LOD == 5
		fragColor.rgb *= weights[UPSAMPLE_LOD + 1] / wSum;
		#endif
		fragColor.a    = weights[UPSAMPLE_LOD]     / wSum;
	}
#endif
