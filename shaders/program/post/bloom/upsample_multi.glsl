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
		vec2 vertPos = gl_Vertex.xy * exp2(-UPSAMPLE_LOD0) / 2.0;
		     vertPos = vertPos + 1.0 - exp2(-UPSAMPLE_LOD0);
		gl_Position = vec4(vertPos * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:6 */

	out vec4 fragColor;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"

	//--// Fragment Functions //----------------------------------------------//

	vec4 BloomUpsample(vec2 uv, int dstLod, int srcLod) {
		vec2 srcUv = uv;
		for (int i = 0; i < srcLod - dstLod; ++i) {
			uv = uv * 0.5 + 0.5;
		}

		vec4 bloom;
		#ifdef UPSAMPLE_BICUBIC
		bloom.rgb = TextureCubic(SOURCE_SAMPLER, srcUv).rgb;
		#else
		bloom.rgb = texture(SOURCE_SAMPLER, srcUv).rgb;
		#endif

		// Weigh lods
		const float[7] weights = float[7](1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0/1.0, 1.0);
		const float wSum = weights[0] + weights[1] + weights[2] + weights[3] + weights[4] + weights[5] + weights[6];

		if (srcLod == 6) { // 6 = max lod
			bloom.rgb *= weights[srcLod] / wSum;
		}
		bloom.a    = weights[dstLod] / wSum;

		return bloom;
	}

	void main() {
		vec2 uv = viewPixelSize * gl_FragCoord.xy;
		vec4 bloom2 = BloomUpsample(uv, UPSAMPLE_LOD0, UPSAMPLE_LOD2 + 1);
		vec4 bloom1 = BloomUpsample(uv, UPSAMPLE_LOD0, UPSAMPLE_LOD1 + 1);
		vec4 bloom0 = BloomUpsample(uv, UPSAMPLE_LOD0, UPSAMPLE_LOD0 + 1);
		fragColor.rgb = bloom0.rgb * bloom1.a + (bloom1.rgb * bloom2.a + bloom2.rgb);
		fragColor.a   = bloom0.a;
	}
#endif
