//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//#define DIFFRACTION_SPIKES

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6; // Bloom tiles

uniform float aspectRatio;

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

	#if defined MC_GL_RENDERER_RADEON // workaround for AMD driver bug(?) causing colortex0 to not get cleared
	/* RENDERTARGETS: 4,0 */

	layout (location = 0) out vec4 colortex4Write;
	layout (location = 1) out vec4 colortex0Write;
	#else
	/* RENDERTARGETS: 4 */

	layout (location = 0) out vec4 colortex4Write;
	#endif

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"
	#include "/include/utility/color.glsl"
	#include "/include/utility/encoding.glsl"
	#include "/include/utility/noise.glsl"

	#include "/include/shared/blurTileOffset.glsl"

	//--// Fragment Functions //----------------------------------------------//

	float Sinc(float x) {
		return (x == 0.0) ? 1.0 : sin(x) / x;
	}

	vec3 DiffractionSpikes(sampler2D sampler, vec2 uv) {
		const int samples = 32;
		const float distribution = 3.0;

		vec3 result = texture(colortex6, uv * 0.5).rgb;
		float weightSum = 1.0;
		for (int spike = 0; spike < CAMERA_IRIS_BLADE_COUNT; ++spike) {
			float theta = (spike + CAMERA_IRIS_BLADE_ROTATION) * tau / CAMERA_IRIS_BLADE_COUNT;
			vec2 dir = vec2(cos(theta), sin(theta));
			for (int i = 1; i < samples; ++i) {
				float f = float(i) / float(samples);

				float x = f < (1.0/distribution) ? distribution*exp(distribution*(1.0/distribution - 1.0))*f : exp(distribution * (f - 1.0));
				float weight = distribution*exp(distribution*(max(f, 1.0/distribution) - 1.0));
				weight *= (1.0 - x * x) / (pow(50.0 * x, 2.0) + 1.0);

				float l = max(log2(x) + 3.0, 0.0);
				float l0 = floor(l);
				float l1 = ceil(l);

				vec3 sl0 = texture(colortex6, (uv + 192.0 * viewPixelSize * dir * x) * exp2(-l0 - 1.0) + 1.0 - exp2(-l0)).rgb;
				vec3 sl1 = texture(colortex6, (uv + 192.0 * viewPixelSize * dir * x) * exp2(-l1 - 1.0) + 1.0 - exp2(-l1)).rgb;

				result += weight * mix(sl0, sl1, fract(l));
				weightSum += weight;
			}
		}

		return result / weightSum;
	}

	vec3 LowlightNoise(vec3 color, float exposure) {
		vec3 invSNR = inversesqrt(color * 5.0 / exposure);
		vec3 noise  = Hash3(vec3(gl_FragCoord.st * viewPixelSize, frameCounter % 256 / 256.0));

		return (invSNR * noise * color + color) / (0.5 * invSNR + 1.0);
	}

	#include "/include/color/display_transform/apply.glsl"

	void main() {
		#if defined MC_GL_RENDERER_RADEON // workaround for AMD driver bug(?) causing colortex0 to not get cleared
		colortex0Write = vec4(0.0, 0.0, 0.0, 1.0);
		#endif

		vec2 screenCoord = gl_FragCoord.st * viewPixelSize;

		vec3 color = texture(colortex5, screenCoord).rgb;
		#ifdef DIFFRACTION_SPIKES
		color = mix(color, DiffractionSpikes(colortex5, screenCoord), 0.1);
		#endif
		float exposure = texture(colortex3, screenCoord).a;

		#ifdef BLOOM
			color += BLOOM_STRENGTH * TextureCubic(colortex6, screenCoord * 0.5).rgb;
		#endif

		#ifdef LOWLIGHT_NOISE
			color = LowlightNoise(color, exposure);
		#endif

		color = apply_display_transform((XYZ_from_render * color) / exposure, exposure);

		colortex4Write = EncodeRGBE8(color);
	}
#endif
