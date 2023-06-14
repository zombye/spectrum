//--// Settings //------------------------------------------------------------//

#define UPSAMPLE_BICUBIC

//--// Uniforms //------------------------------------------------------------//

#define SOURCE_SAMPLER colortex6
uniform sampler2D SOURCE_SAMPLER;

//--// Custom uniforms

uniform float viewHeight;

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

	/* RENDERTARGETS: 6 */

	out vec4 fragColor;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"

	//--// Fragment Functions //----------------------------------------------//

	float TileWeight(int tile) {
		// Use the default 480p window as a reference point
		// From there, scale width of bloom linearly with resolution for consistent results across resolutions
		float tmp = float(tile) + log2(480.0 / viewHeight);
		if (tmp < 0.0) {
			return max(tmp + 1.0, 0.0);
		}
		return exp2(-0.7 * tmp);
	}
	float WeightNorm() {
		float sum = 0.0;
		for (int i = 0; i <= 9; ++i) {
			sum += TileWeight(i);
		}
		return 1.0 / sum;
	}

	void main() {
		vec2 uv = viewPixelSize * gl_FragCoord.xy;
		vec2 srcUv = uv * 0.5 + 0.5;
		#ifdef UPSAMPLE_BICUBIC
		fragColor.rgb = TextureCubic(SOURCE_SAMPLER, srcUv).rgb;
		#else
		fragColor.rgb = texture(SOURCE_SAMPLER, srcUv).rgb;
		#endif

		// Weigh lods
		#if UPSAMPLE_LOD == 8
		fragColor.rgb *= TileWeight(UPSAMPLE_LOD + 1) * WeightNorm();
		#endif
		fragColor.a = TileWeight(UPSAMPLE_LOD) * WeightNorm();
	}
#endif
