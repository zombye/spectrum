#include "./config.glsl"
#include "./internal_color_space.glsl"

bool is_below_bright_clip_boundary(vec3 color_inner) {
	vec3 color_xyz = xyz_from_inner(color_inner);
	vec3 color_display = display_linear_normalized_from_xyz_absolute(color_xyz);
	return all(lessThanEqual(color_display, vec3(1.0)));
}
bool is_above_dark_clip_boundary(vec3 color_inner) {
	vec3 color_xyz = xyz_from_inner(color_inner);
	vec3 color_display = display_linear_normalized_from_xyz_absolute(color_xyz);
	return all(greaterThanEqual(color_display, vec3(0.0)));
}
bool is_in_display_gamut(vec3 color_inner) {
	return is_below_bright_clip_boundary(color_inner) && is_above_dark_clip_boundary(color_inner);
}

float find_bright_clip_boundary_colorfulness(float brightness, float hue) {
	// Find inital bounds.
	const int upsearch_exponent_bits = 5;
	const int upsearch_mantissa_bits = 1;
	const int upsearch_min_exponent_part_value = 1; // always 1. if the boundary is in subnormals, the binary search will handle them.
	const int upsearch_max_exponent_part_value = (1 << upsearch_exponent_bits) - 1;
	const int initial_i = upsearch_min_exponent_part_value << upsearch_mantissa_bits;
	const int final_i = (upsearch_max_exponent_part_value - 1) << upsearch_mantissa_bits + 1;

	float bound_lower = 0.0;
	float bound_upper = 65504.0;
	for (int i = initial_i; i < final_i; ++i) {
		int trial_bitpattern = (0x70 << 23) + (i << (23 - upsearch_mantissa_bits));
		float trial_colorfulness = uintBitsToFloat(trial_bitpattern);

		vec3 trial_color = vec3(brightness, hue, trial_colorfulness);
		if (is_below_bright_clip_boundary(trial_color)) {
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

	const int bsearch_iterations = target_mantissa_bits - upsearch_mantissa_bits;
	for (int i = 0; i < bsearch_iterations; ++i) {
		float candidate_colorfulness = 0.5 * (bound_lower + bound_upper);
		vec3 candidate_inner = vec3(brightness, hue, candidate_colorfulness);

		// If this is in the boundary, this is the new lower bound.
		if (is_below_bright_clip_boundary(candidate_inner)) {
			bound_lower = candidate_colorfulness;
		} else {
			bound_upper = candidate_colorfulness;
		}
	}

	return bound_lower;
}
float find_dark_clip_boundary_colorfulness(float brightness, float hue) {
	// Find inital bounds.
	const int upsearch_exponent_bits = 5;
	const int upsearch_mantissa_bits = 1;
	const int upsearch_min_exponent_part_value = 1; // always 1. if the boundary is in subnormals, the binary search will handle them.
	const int upsearch_max_exponent_part_value = (1 << upsearch_exponent_bits) - 1;
	const int initial_i = upsearch_min_exponent_part_value << upsearch_mantissa_bits;
	const int final_i = (upsearch_max_exponent_part_value - 1) << upsearch_mantissa_bits + 1;

	float bound_lower = 0.0;
	float bound_upper = 65504.0;
	for (int i = initial_i; i < final_i; ++i) {
		int trial_bitpattern = (0x70 << 23) + (i << (23 - upsearch_mantissa_bits));
		float trial_colorfulness = uintBitsToFloat(trial_bitpattern);

		vec3 trial_color = vec3(brightness, hue, trial_colorfulness);
		if (is_above_dark_clip_boundary(trial_color)) {
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

	const int bsearch_iterations = target_mantissa_bits - upsearch_mantissa_bits;
	for (int i = 0; i < bsearch_iterations; ++i) {
		float candidate_colorfulness = 0.5 * (bound_lower + bound_upper);
		vec3 candidate_inner = vec3(brightness, hue, candidate_colorfulness);

		// If this is in the boundary, this is the new lower bound.
		if (is_above_dark_clip_boundary(candidate_inner)) {
			bound_lower = candidate_colorfulness;
		} else {
			bound_upper = candidate_colorfulness;
		}
	}

	return bound_lower;
}

// cubic polynomial - from: https://iquilezles.org/articles/smin/
float smin_cubic( float a, float b, float k ) {
	k *= 6.0;
	float h = max( k-abs(a-b), 0.0 )/k;
	return min(a,b) - h*h*h*k*(1.0/6.0);
}

float compute_display_gamut_boundary_colorfulness(float brightness, float hue) {
	// "Bright" and "dark" boundaries of display gamut are separated to facilitate a smooth transition between them.
	float bright_clip_boundary_colorfulness = find_bright_clip_boundary_colorfulness(brightness, hue);
	float dark_clip_boundary_colorfulness   = find_dark_clip_boundary_colorfulness  (brightness, hue);

	// Need to take max with 0 because of what appears to be floating-point errors.
	return max(smin_cubic(bright_clip_boundary_colorfulness, dark_clip_boundary_colorfulness, 0.2 * dark_clip_boundary_colorfulness), 0.0);
}
