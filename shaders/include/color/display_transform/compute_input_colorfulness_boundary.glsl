#include "./config.glsl"
#include "./internal_color_space.glsl"

bool is_in_input_gamut(vec3 color_inner) {
	vec3 color_xyz = xyz_from_inner(color_inner);

	#if RENDER_PRIMARIES == PRIMARIES_BT2020
		vec3 color_input = BT2020_from_XYZ * color_xyz;
	#elif RENDER_PRIMARIES == PRIMARIES_BT709
		vec3 color_input = BT709_from_XYZ * color_xyz;
	#endif

	return all(greaterThanEqual(color_input, vec3(0.0)));
}
float compute_input_gamut_boundary_colorfulness(float brightness, float hue) {
	// Find inital bounds.
	const int upsearch_exponent_bits = 5;
	const int upsearch_mantissa_bits = 3;
	const int upsearch_min_exponent_part_value = 1; // always 1. if the boundary is in subnormals, the binary search will handle them.
	const int upsearch_max_exponent_part_value = (1 << upsearch_exponent_bits) - 1;
	const int initial_i = upsearch_min_exponent_part_value << upsearch_mantissa_bits;
	const int final_i = (upsearch_max_exponent_part_value - 1) << upsearch_mantissa_bits + 1;

	float bound_lower = 0.0;
	float bound_upper = 65504.0;
	for (int i = initial_i; i < final_i; ++i) {
		float trial_colorfulness = uintBitsToFloat((0x70 << 23) + (i << (23 - upsearch_mantissa_bits)));

		vec3 trial_color = vec3(brightness, hue, trial_colorfulness);
		if (is_in_input_gamut(trial_color)) {
			bound_lower = trial_colorfulness;
		} else {
			bound_upper = trial_colorfulness;
			break;
		}
	}

	if (bound_lower > bound_upper) {
		// Failed to find an upper bound during upsearch.
		// Fall back to float16 max finite value.
		// This should never be reached.
		return 65504.0;
	}

	// Binary search to find final boundary.
	const int target_mantissa_bits = 10;

	//*
	const int bsearch_iterations = target_mantissa_bits - upsearch_mantissa_bits;
	for (int i = 0; i < bsearch_iterations; ++i) {
		float candidate_colorfulness = 0.5 * (bound_lower + bound_upper);
		vec3 candidate_inner = vec3(brightness, hue, candidate_colorfulness);

		// If this is in-gamut, this is the new lower bound.
		if (is_in_input_gamut(candidate_inner)) {
			bound_lower = candidate_colorfulness;
		} else {
			bound_upper = candidate_colorfulness;
		}
	}
	/*/
	const int first_bsearch_bit = 23 - upsearch_mantissa_bits;
	const int last_bsearch_bit = 23 - target_mantissa_bits;

	for (int bit_index = first_bsearch_bit; bit_index >= last_bsearch_bit; --bit_index) {
		float trial_colorfulness = uintBitsToFloat(floatBitsToUint(bound_lower) | (1u << uint(bit_index)));

		// If this is in-gamut, this is the new lower bound. Otherwise, it's the new upper bound.
		vec3 trial_color = vec3(brightness, hue, trial_colorfulness);
		if (is_in_input_gamut(trial_color)) {
			bound_lower = trial_colorfulness;
		} else {
			bound_upper = trial_colorfulness;
		}
	}
	//*/

	return bound_lower;
}
