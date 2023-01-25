//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex6;

layout (r32ui) uniform uimage2D colorimg2;

//--// Inputs //--------------------------------------------------------------//

layout (local_size_x = 16, local_size_y = 8, local_size_z = 1) in;

//--// Includes //------------------------------------------------------------//

#include "/include/utility/color.glsl"

//--// Functions //-----------------------------------------------------------//

shared uint[HISTOGRAM_BIN_COUNT] localHistogram;

float LuminanceFromBin(float bin) {
	float logLuminance = bin * (log2(HISTOGRAM_LUMINANCE_MAX) - log2(HISTOGRAM_LUMINANCE_MIN)) / (HISTOGRAM_BIN_COUNT - 1.0) + log2(HISTOGRAM_LUMINANCE_MIN);
	float luminance = exp2(logLuminance);
	return luminance;
}
float BinFromLuminance(float luminance) {
	float logLuminance = log2(luminance);
	float bin = (logLuminance - log2(HISTOGRAM_LUMINANCE_MIN)) * (HISTOGRAM_BIN_COUNT - 1.0) / (log2(HISTOGRAM_LUMINANCE_MAX) - log2(HISTOGRAM_LUMINANCE_MIN));
	return bin;
}

void main() {
	localHistogram[gl_LocalInvocationIndex] = 0u;

	memoryBarrierShared();
	barrier();

	if (all(lessThan(gl_GlobalInvocationID.xy, textureSize(colortex6, 0)))) {
		vec3 color = texelFetch(colortex6, ivec2(gl_GlobalInvocationID.xy), 0).rgb;
		float luminance = dot(color, RgbToXyz[1]);

		// Discard pixels with luminance values that are less than or equal to 0, infinite, or NaN.
		if (!isnan(luminance) && !isinf(luminance) && luminance > 0.0) {
			int binIndex = int(round(BinFromLuminance(luminance)));
			binIndex = clamp(binIndex, 0, HISTOGRAM_BIN_COUNT - 1);

			atomicAdd(localHistogram[binIndex], 1u);
		}
	}

	memoryBarrierShared();
	barrier();

	imageAtomicAdd(colorimg2, ivec2(gl_LocalInvocationIndex, 0), localHistogram[gl_LocalInvocationIndex]);
}
