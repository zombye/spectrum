#include "../config.glsl"

/* RENDERTARGETS: 15 */

out vec2 grayline_ab;

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"
#include "/include/color/display.glsl"

#include "../internal_color_space.glsl"

float find_grayline_luminance(float target_brightness, vec3 display_white_xyz) {
	const int upsearch_exponent_bits = 8;
	const int upsearch_mantissa_bits = 0;
	const int upsearch_min_exponent_part_value = 1;
	const int upsearch_max_exponent_part_value = (1 << upsearch_exponent_bits) - 1;
	const int initial_i = upsearch_min_exponent_part_value << upsearch_mantissa_bits;
	const int final_i = (upsearch_max_exponent_part_value - 1) << upsearch_mantissa_bits + 1;

	float bound_lower = 0.0;
	float bound_upper = intBitsToFloat(0x7f7fffff); // Largest finite float
	for (int i = initial_i; i < final_i; ++i) {
		int trial_bitpattern = (0x70 << 23) + (i << (23 - upsearch_mantissa_bits));
		float trial_luminance = intBitsToFloat(trial_bitpattern);

		float trial_brightness = inner_iab_from_xyz(trial_luminance * display_white_xyz).x;
		if (trial_brightness < target_brightness) {
			bound_lower = trial_luminance;
		} else {
			bound_upper = trial_luminance;
			break;
		}
	}

	if (bound_lower > bound_upper) {
		// Failed to find an upper bound during upsearch.
		// Fall back to float32 largest finite value.
		// This should never be reached.
		return intBitsToFloat(0x7f7fffff);
	}

	// Binary search to find final boundary.
	const int target_mantissa_bits = 23;

	const int bsearch_iterations = target_mantissa_bits - upsearch_mantissa_bits;
	for (int i = 0; i < bsearch_iterations; ++i) {
		float trial_luminance = 0.5 * (bound_lower + bound_upper);

		float trial_brightness = inner_iab_from_xyz(trial_luminance * display_white_xyz).x;
		if (trial_brightness < target_brightness) {
			bound_lower = trial_luminance;
		} else {
			bound_upper = trial_luminance;
		}
	}

	// If nothing went wrong, upper bound is exactly the luminance of the target brightness;
	return bound_upper;
}

void main() {
	grayline_ab = vec2(0.0);

	if (gl_FragCoord.x < (DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE - 1)) {
		float brightness_coordinate = floor(gl_FragCoord.x) / float(DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE - 1);

		float max_i = response_transfer_function_max();
		float target_brightness = max_i * brightness_coordinate * brightness_coordinate;

		vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
		float luminance = find_grayline_luminance(target_brightness, display_white_xyz);

		grayline_ab = inner_iab_from_xyz(luminance * display_white_xyz).yz;
	}
}
