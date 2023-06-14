//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#define CONTRAST -0.1 // [-1 -0.9 -0.8 -0.7 -0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1]
#define CONTRAST_MIDPOINT 0.14
#define SATURATION 1 // [0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2]

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

	#include "/include/fragment/tonemap.fsh"

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

	vec3 LowlightDesaturate(vec3 color, float exposure) {
		float desaturated = dot(color, vec3(0.05, 0.55, 0.4));
		//float desaturated = dot(color, RgbToXyz[1]);
		//float desatAmt = Clamp01(exp(-50.0 * desaturated / exposure));
		float desatAmt = Clamp01(exp(-1e2 * (desaturated*desaturated) / (exposure*exposure)));
		return color * (1.0 - desatAmt) + (desaturated * desatAmt);
	}
	vec3 LowlightNoise(vec3 color, float exposure) {
		vec3 invSNR = inversesqrt(color * 5.0 / exposure);
		vec3 noise  = Hash3(vec3(gl_FragCoord.st * viewPixelSize, frameCounter % 256 / 256.0));

		return (invSNR * noise * color + color) / (0.5 * invSNR + 1.0);
	}

	vec3 Contrast(vec3 color) {
		float luminance = dot(color, RgbToXyz[1]);
		float newLuminance = CONTRAST_MIDPOINT * pow(luminance / CONTRAST_MIDPOINT, exp2(CONTRAST));
		return color * Max0(newLuminance / luminance);
	}
	vec3 Saturation(vec3 color) {
		float luminance = dot(color, RgbToXyz[1]);
		float minComp = MinOf(color), maxComp = MaxOf(color);

		// compute the desired output saturation
		//float originalSaturation = maxComp == 0.0 ? 0.0 : Clamp01(1.0 - minComp / maxComp);
		float newSaturation = maxComp == 0.0 ? 0.0 : Clamp01(1.0 - pow(minComp / maxComp, SATURATION));

		// compute fully saturated version of the color (if it exits)
		vec3 saturatedColor = (maxComp - minComp) == 0.0 ? vec3(maxComp) : (color - minComp) / (maxComp - minComp);

		// compute new color from saturated & non-saturated color
		color  = mix(vec3(1.0), saturatedColor, newSaturation);
		color *= luminance / dot(color, RgbToXyz[1]);

		return color;
	}

	mat3 ChromaticAdaptationMatrix(vec3 sourceXYZ, vec3 destinationXYZ) {
		const mat3 XyzToLms = mat3(
			 0.7328, 0.4296,-0.1624,
			-0.7036, 1.6975, 0.0061,
			 0.0030, 0.0136, 0.9834
		); // CAT02

		vec3 sourceLMS = sourceXYZ * XyzToLms;
		vec3 destinationLMS = destinationXYZ * XyzToLms;

		vec3 tmp = destinationLMS / sourceLMS;

		mat3 vonKries = mat3(
			tmp.x, 0.0, 0.0,
			0.0, tmp.y, 0.0,
			0.0, 0.0, tmp.z
		);

		return (XyzToLms * vonKries) * inverse(XyzToLms);
	}
	vec3 WhiteBalance(vec3 color) {
		vec3 sourceXYZ = Blackbody(WHITE_BALANCE) * RgbToXyz;
		vec3 destinationXYZ = Blackbody(6500.0) * RgbToXyz;
		mat3 matrix = RgbToXyz * ChromaticAdaptationMatrix(sourceXYZ, destinationXYZ) * XyzToRgb;

		return color * matrix;
	}

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
		#ifdef LOWLIGHT_DESATURATION
			color = LowlightDesaturate(color, exposure);
		#endif

		color = WhiteBalance(color);

		color = Contrast(color);
		color = Saturation(color);

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
