/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

//--// Uniforms

uniform int frameCounter;

uniform sampler2D colortex3;
uniform sampler2D colortex6; // Bloom tiles

// Custom Uniforms
uniform vec2 viewPixelSize;

//--// Shared Libraries

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Functions

	void main() {
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Outputs

	/* DRAWBUFFERS:4 */

	layout (location = 0) out vec4 colortex4Write;

	//--// Fragment Libraries

	#include "/lib/utility.glsl"
	#include "/lib/utility/colorspace.glsl"
	#include "/lib/utility/encoding.glsl"
	#include "/lib/utility/noise.glsl"

	#include "/lib/shared/blurTileOffset.glsl"

	#include "/lib/fragment/filmTonemap.fsh"

	//--// Fragment Functions

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
			color = mix(color, GetBloom(screenCoord), 0.1);
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

		const mat3 coneOverlapMatrix2Deg = mat3(
			mix(vec3(1.0, 0.0, 0.0), vec3(0.5595088340965042, 0.39845359892109633, 0.04203756698239944), vec3(CONE_OVERLAP_SIMULATION)),
			mix(vec3(0.0, 1.0, 0.0), vec3(0.43585871315661756, 0.5003841413971261, 0.06375714544625634), vec3(CONE_OVERLAP_SIMULATION)),
			mix(vec3(0.0, 0.0, 1.0), vec3(0.10997368482498855, 0.15247972169325025, 0.7375465934817612), vec3(CONE_OVERLAP_SIMULATION))
		);
		color = Tonemap(color * coneOverlapMatrix2Deg) * inverse(coneOverlapMatrix2Deg);
		colortex4Write = EncodeRGBE8(color);
	}
#endif
