//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform usampler2D colortex2;
layout (r32ui) uniform uimage2D colorimg2;

//--// Inputs //--------------------------------------------------------------//

layout (local_size_x = 128, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

//--// Includes //------------------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"
#include "/include/shared/celestialConstants.glsl"

//--// Functions //-----------------------------------------------------------//

shared uint[HISTOGRAM_BIN_COUNT] histogram;
shared uint[HISTOGRAM_BIN_COUNT] histogram_cumulative;
shared uint[HISTOGRAM_BIN_COUNT] weighted;

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
	histogram[gl_LocalInvocationIndex] = texelFetch(colortex2, ivec2(gl_LocalInvocationIndex, 0), 0).x;

	// Parallel prefix sum to generate cumulative histogram
	histogram_cumulative[gl_LocalInvocationIndex] = histogram[gl_LocalInvocationIndex];
	const uint startStride = 1u;
	for (uint stride = startStride; stride < HISTOGRAM_BIN_COUNT; stride *= 2u) {
		uint src_sum = histogram_cumulative[gl_LocalInvocationIndex];

		barrier();

		uint dst_index = gl_LocalInvocationIndex + stride;
		if (dst_index < HISTOGRAM_BIN_COUNT) {
			histogram_cumulative[dst_index] += src_sum;
		}

		barrier();
	}

	// Weighted bin indices
	// Bins with more pixels have a higher weight, but a fraction of the darkest & brightest pixels are excluded
	uint clamp_min =                                                 uint(round(AUTOEXPOSURE_IGNORE_DARK   * float(histogram_cumulative[HISTOGRAM_BIN_COUNT - 1])));
	uint clamp_max = histogram_cumulative[HISTOGRAM_BIN_COUNT - 1] - uint(round(AUTOEXPOSURE_IGNORE_BRIGHT * float(histogram_cumulative[HISTOGRAM_BIN_COUNT - 1])));
	uint included_count = clamp_max - clamp_min;

	uint weight = clamp(histogram_cumulative[gl_LocalInvocationIndex], clamp_min, clamp_max);
	if (gl_LocalInvocationIndex == 0) {
		weight -= clamp_min;
	} else {
		weight -= clamp(histogram_cumulative[gl_LocalInvocationIndex - 1], clamp_min, clamp_max);
	}

	weighted[gl_LocalInvocationIndex] = weight * gl_LocalInvocationIndex;

	// Parallel sum, after this index 0 is a weighted sum of the bin indices
	for (int stride = HISTOGRAM_BIN_COUNT / 2; stride > 0; stride /= 2) {
		barrier();

		if (gl_LocalInvocationIndex < stride) {
			weighted[gl_LocalInvocationIndex] += weighted[gl_LocalInvocationIndex + stride];
		}
	}

	if (gl_LocalInvocationIndex == 0u) {
		// No need for a barrier here since this thread is the only one that writes to index 0
		// Since bins are logarithmically spaced, getting the luminance of the mean bin give the geometric mean of luminance
		float geometricMeanLuminance = LuminanceFromBin(float(weighted[0]) / float(included_count));

		const float K = 14.0;
		const float calibration = exp2(CAMERA_AUTOEXPOSURE_BIAS) * K / 100.0;

		const float minExposure = exp2(CAMERA_AUTOEXPOSURE_BIAS) * pi /  dot(sunIlluminance, RgbToXyz[1]);
		const float maxExposure = 0.03 * exp2(CAMERA_AUTOEXPOSURE_BIAS) * pi / (dot(moonIlluminance, RgbToXyz[1]) * NIGHT_SKY_BRIGHTNESS);

		const float a =     calibration / minExposure;
		const float b = a - calibration / maxExposure;
		float targetExposure = calibration / (a - b * exp(-geometricMeanLuminance / b));

		imageStore(colorimg2, ivec2(HISTOGRAM_BIN_COUNT, 0), uvec4(floatBitsToUint(targetExposure), 0, 0, 0));
	}
}
