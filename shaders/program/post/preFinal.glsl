//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex3;
uniform sampler2D colortex6; // Bloom tiles

//--// Time uniforms

uniform int frameCounter;

//--// Custom Uniforms

uniform vec2 viewPixelSize;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:4 */

	layout (location = 0) out vec4 colortex4Write;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"
	#include "/include/utility/colorspace.glsl"
	#include "/include/utility/encoding.glsl"
	#include "/include/utility/noise.glsl"

	#include "/include/shared/blurTileOffset.glsl"

	#include "/include/fragment/tonemap.fsh"

	//--// Fragment Functions //----------------------------------------------//

	vec3 GetBloom(vec2 screenCoord) {
		vec3 bloom = texture(colortex6, screenCoord * exp2(-1.0) + CalculateTileOffset(0)).rgb;
		float totalWeight = 1.0;
		for (int i = 1; i < 7; ++i) {
			float tileWeight = 1.0 / (i + 1.0);
			bloom += texture(colortex6, screenCoord * exp2(-i - 1.0) + CalculateTileOffset(i)).rgb * tileWeight;
			totalWeight += tileWeight;
		}
		bloom /= totalWeight;

		return bloom;
	}

	vec3 LowlightDesaturate(vec3 color, float exposure) {
		float desaturated = dot(color, vec3(0.15, 0.50, 0.35));
		float desatAmt = Clamp01(exp(-50.0 * desaturated / exposure));
		return color * (1.0 - desatAmt) + (desaturated * desatAmt);
	}
	vec3 LowlightNoise(vec3 color, float exposure) {
		vec3 invSNR = inversesqrt(color * 5.0 / exposure);
		vec3 noise  = Hash3(vec3(gl_FragCoord.st * viewPixelSize, frameCounter % 256 / 256.0));

		return (invSNR * noise * color + color) / (0.5 * invSNR + 1.0);
	}

	void main() {
		vec2 screenCoord = gl_FragCoord.st * viewPixelSize;

		vec4 colorsample = texture(colortex3, screenCoord);
		vec3 color = colorsample.rgb;
		float exposure = colorsample.a;

		#ifdef BLOOM
			color = mix(GetBloom(screenCoord), color, 1.0 / (1.0 + BLOOM_AMOUNT));
		#endif

		#ifdef LOWLIGHT_NOISE
			color = LowlightNoise(color, exposure);
		#endif
		#ifdef LOWLIGHT_DESATURATION
			color = LowlightDesaturate(color, exposure);
		#endif

		color *= mat3( // Apply color matrix before tonemapping
			COLORMATRIX_R_TO_R, COLORMATRIX_G_TO_R, COLORMATRIX_B_TO_R,
			COLORMATRIX_R_TO_G, COLORMATRIX_G_TO_G, COLORMATRIX_B_TO_G,
			COLORMATRIX_R_TO_B, COLORMATRIX_G_TO_B, COLORMATRIX_B_TO_B
		);

		color = Max0(color);

		const mat3 coneOverlapMatrix2Deg = mat3(
			mix(vec3(1.0, 0.0, 0.0), vec3(0.5595088340965042, 0.39845359892109633, 0.04203756698239944), vec3(CONE_OVERLAP_SIMULATION)),
			mix(vec3(0.0, 1.0, 0.0), vec3(0.43585871315661756, 0.5003841413971261, 0.06375714544625634), vec3(CONE_OVERLAP_SIMULATION)),
			mix(vec3(0.0, 0.0, 1.0), vec3(0.10997368482498855, 0.15247972169325025, 0.7375465934817612), vec3(CONE_OVERLAP_SIMULATION))
		);
		color = Tonemap(color * coneOverlapMatrix2Deg) * inverse(coneOverlapMatrix2Deg);

		//#define DEBUG_TONEMAP
		#ifdef DEBUG_TONEMAP
			{
				const ivec2 pos  = ivec2(4, 3);
				const ivec2 size = ivec2(512, 128);
				const float lineWidth = 1.5;

				vec2 coord = gl_FragCoord.xy - pos;

				if (clamp(coord, vec2(0), size) == coord) {
					color *= 0.2;

					float scale = 8.0;

					float newmin = -10.0;
					float newmax =   8.0;

					float cLum = exp2((coord.x / size.x) * (newmax - newmin) + newmin);

					vec3 lineHeight = Tonemap(vec3(cLum)) * size.y;
					vec3 derivative = dFdx(lineHeight);

					vec3 line = LinearStep(0.5 * lineWidth + 0.5, 0.5 * lineWidth - 0.5, abs(lineHeight - coord.y) * inversesqrt(1.0 + derivative * derivative) * sqrt(2.0));
					color = mix(color * 0.2, vec3(1.0), line);
				}
			}
		#endif

		colortex4Write = EncodeRGBE8(color);
	}
#endif
