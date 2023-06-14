//--// Settings

#include "/settings.glsl"

#define FILTER_SIGMAL 20.0
#define FILTER_SIGMAN 128.0

//--// Uniforms

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform sampler2D depthtex1;

uniform sampler2D colortex1;
uniform sampler2D colortex5;

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;

uniform vec2 taaOffset;

#if defined STAGE_VERTEX
	//--// Vertex Functions

	void main() {
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	//--// Fragment Outputs

	/* RENDERTARGETS: 5 */

	layout (location = 0) out vec4 lighting;

	//--// Fragment Libraries

	#include "/include/utility.glsl"
	#include "/include/utility/color.glsl"
	#include "/include/utility/encoding.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/spaceConversion.glsl"

	//--// Fragment Functions

	float Gaussian3x3LuminanceVariance(vec2 fragCoord) {
		float sum  = texture(colortex5, (fragCoord + vec2( 0.5, 0.5)) * viewPixelSize).a;
		      sum += texture(colortex5, (fragCoord + vec2( 0.5,-0.5)) * viewPixelSize).a;
		      sum += texture(colortex5, (fragCoord + vec2(-0.5,-0.5)) * viewPixelSize).a;
		      sum += texture(colortex5, (fragCoord + vec2(-0.5, 0.5)) * viewPixelSize).a;
		return sum * 0.25;
	}

	void main() {
		ivec2 fragCoord = ivec2(gl_FragCoord.st);

		if (fragCoord.x <= ceil(viewResolution.x / 2.0) || fragCoord.y >= viewResolution.y / 2) {
			lighting = texelFetch(colortex5, fragCoord, 0);
			return;
		}

		ivec2 fragCoord2 = 2 * (fragCoord - ivec2(ceil(viewResolution.x / 2.0), 0));

		float depth = texelFetch(depthtex1, fragCoord2, 0).r;

		if (depth < 1.0) {
			const int stepSize = 1 << FILTER_ITERATION;

			const float sigmaP = 0.001;
			const float sigmaN = FILTER_SIGMAN;
			const float sigmaL = FILTER_SIGMAL;

			// Init for filter - start weight and result with center sample
			float weightAccum = 1.0;
			vec4 result = texelFetch(colortex5, fragCoord, 0);

			// Misc prep
			vec3  posCenter      = ScreenSpaceToViewSpace(vec3(viewPixelSize * fragCoord2, depth), gbufferProjectionInverse);
			vec3  normalCenter   = DecodeNormal(Unpack2x8(texelFetch(colortex1, fragCoord2, 0).a) * 2.0 - 1.0);
			vec3  normalCenterVS = mat3(gbufferModelView) * normalCenter;
			float lumCenter      = dot(result.rgb, RgbToXyz[1]);

			float phiPos = -posCenter.z * stepSize * sigmaP;

			// Perform spatial filter
			// 3x3 seems to give similar quality as 5x5
			for (int x = -1; x <= 1; ++x) {
				for (int y = -1; y <= 1; ++y) {
					if (x == 0 && y == 0) { continue; }

					ivec2 offset = ivec2(x, y) * stepSize;
					ivec2 samplePos = fragCoord + offset;
					ivec2 samplePos2 = fragCoord2 + 2 * offset;

					vec3  posSample      = vec3(viewPixelSize * samplePos2, texelFetch(depthtex1, samplePos2, 0).r);
					      posSample      = ScreenSpaceToViewSpace(posSample, gbufferProjectionInverse);
					vec3  normalSample   = DecodeNormal(Unpack2x8(texelFetch(colortex1, samplePos2, 0).a) * 2.0 - 1.0);
					vec4  lightingSample = texelFetch(colortex5, samplePos, 0);

					float wGauss  = exp2(-x * x - y * y);
					float wNormal = pow(Clamp01(dot(normalCenter, normalSample)), sigmaN);
					float wPos    = dot(normalCenterVS, posSample - posCenter) / phiPos;

					float weight = exp(-wPos * wPos) * wNormal * wGauss;

					result += lightingSample * vec4(vec3(weight), weight * weight);
					weightAccum += weight;
				}
			}

			result /= vec4(vec3(weightAccum), weightAccum * weightAccum);

			lighting = result;
		} else {
			lighting = vec4(0.0);
		}
	}
#endif
