// absolute input color -> absolute display color -> display input values

#include "./config.glsl"

//--//

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"
#include "/include/color/display.glsl"

#include "./internal_color_space.glsl"

//--//

// Produces a scaling factor that maps "linear brightness" down to a 0 to 1 range
float highlight_compression_factor(float brightness) {
	const float curve = 1.0; // 1 to infinity. 1 matches Reinhard. Higher values have a "sharper" peak.

	const float c1 = 1.0 / curve - 1.0;
	const float c2 = sqrt(curve);
	const float c3 = pow(1.0 - 1.0 / curve, sqrt(curve));
	const float c4 = -1.0 / sqrt(curve);
	return 1.0 / (1.0 + brightness * (1.0 + c1 * pow(pow(brightness, c2) + c3, c4)));
}
float highlight_shoulder(float brightness) {
	vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
	float display_white_brightness = inner_from_xyz(display_white_xyz).x;

	return brightness * highlight_compression_factor(brightness / display_white_brightness);
}
float highlight_shoulder_normalized(float brightness) {
	return brightness * highlight_compression_factor(brightness);
}
float shadow_toe_normalized(float brightness) {
	vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
	vec3 display_black_xyz = xyz_absolute_from_display_linear_normalized(vec3(0.0));
	float display_white_brightness = inner_from_xyz(display_white_xyz).x;
	float display_black_brightness = inner_from_xyz(display_black_xyz).x;

	// Requirement: In slope = out slope at white after mapping normalized range to display range.
	// There's a few different ways this can be handled, and I'm not sure which is best.
	#ifdef DISPLAY_TRANSFORM_VISIBILITY_TOE
		// Better visibility near blacks, but also slightly muted contrast in dark ranges
		float power = display_white_brightness / (display_white_brightness - display_black_brightness);
		return pow(brightness, power);
	#else
		// Better contrast through a larger range, but worse visibility near blacks.
		const float add = display_black_brightness / (display_white_brightness - display_black_brightness);
		const float mul = (display_white_brightness - 2.0 * display_black_brightness) / (display_white_brightness - display_black_brightness);
		return brightness * brightness / (add + mul * brightness);
	#endif
}
float shadow_toe(float brightness) {
	vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
	vec3 display_black_xyz = xyz_absolute_from_display_linear_normalized(vec3(0.0));
	float display_white_brightness = inner_from_xyz(display_white_xyz).x;
	float display_black_brightness = inner_from_xyz(display_black_xyz).x;

	// transform to normalized range
	float normalized_brightness = brightness / display_white_brightness;

	// apply toe
	float normalized_brightness_with_toe = shadow_toe_normalized(normalized_brightness);

	// transform to display range
	float brightness_with_toe = normalized_brightness_with_toe * (display_white_brightness - display_black_brightness) + display_black_brightness;

	return brightness_with_toe;
}
float input_brightness_to_display_brightness(float input_brightness, float exposure) {
	// This could be a simple global exposure & curve, as it is here, or something much more powerful like a local exposure apporach.

	vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
	vec3 display_black_xyz = xyz_absolute_from_display_linear_normalized(vec3(0.0));
	float display_white_brightness = inner_from_xyz(display_white_xyz).x;
	float display_black_brightness = inner_from_xyz(display_black_xyz).x;

	// target brightness, i.e. what we might try to output on an ideal display with perfect blacks and unlimited whites
	float target_brightness = display_white_brightness * exposure * input_brightness;

	// Apply shoulder for highlights
	float whitelimited_brightness = highlight_shoulder(target_brightness);

	// Apply toe for shadows
	float display_brightness = shadow_toe(whitelimited_brightness);

	return display_brightness;
}

//--//

#ifdef DISPLAY_TRANSFORM_USE_COLORFULNESS_BOUNDARY_LUTS
#include "./get_input_colorfulness_boundary.glsl"
#include "./get_display_colorfulness_boundary.glsl"
#else
#include "./compute_input_colorfulness_boundary.glsl"
#include "./compute_display_colorfulness_boundary.glsl"
#endif

// Soft clip function for specified in & out range, with configurable softness.
// To invert, swap the range parameters.
float soft_clip(float x, float in_range, float out_range, float softness) {
	if (in_range <= out_range) { return x; }
	float p = 1.0 / softness;
	in_range = pow(in_range, p);
	out_range = pow(out_range, p);
	float fac = (in_range - out_range) / (in_range * out_range);
	return x / pow(1.0 + fac * pow(x, p), 1.0 / p);
}

float set_display_colorfulness(float display_brightness, float input_brightness, float hue, float input_colorfulness) {
	#ifdef DISPLAY_TRANSFORM_USE_COLORFULNESS_BOUNDARY_LUTS
		float input_gamut_boundary_colorfulness   = lookup_input_gamut_boundary_colorfulness  (input_brightness,   hue);
		float display_gamut_boundary_colorfulness = lookup_display_gamut_boundary_colorfulness(display_brightness, hue);
	#else
		float input_gamut_boundary_colorfulness   = compute_input_gamut_boundary_colorfulness  (input_brightness,   hue);
		float display_gamut_boundary_colorfulness = compute_display_gamut_boundary_colorfulness(display_brightness, hue);
	#endif

	// Colorfulness modifier can be applied here.
	// Having it integrated like this works really nicely, IMO.
	//input_colorfulness *= colorfulness_modifier;
	//input_gamut_boundary_colorfulness *= colorfulness_modifier;
	#ifndef DISPLAY_TRANSFORM_ABSOLUTE_LUMINANCE_EFFECTS
		input_colorfulness *= DISPLAY_TRANSFORM_RELATIVE_MODE_COLORFULNESS_SCALE;
		input_gamut_boundary_colorfulness *= DISPLAY_TRANSFORM_RELATIVE_MODE_COLORFULNESS_SCALE;
	#endif

	// Soft clip from input range to display range.
	// Tries to balance good gradients, detail preservation, and accurate colorfulness.
	//float display_colorfulness = soft_clip(input_colorfulness, input_gamut_boundary_colorfulness, display_gamut_boundary_colorfulness, 0.5);
	float display_colorfulness = min(input_colorfulness, display_gamut_boundary_colorfulness);

	return display_colorfulness;
}

//--//

vec3 apply_display_transform(
	vec3 absolute_input_color,
	float exposure
) {
	#ifndef DISPLAY_TRANSFORM_ABSOLUTE_LUMINANCE_EFFECTS
		absolute_input_color *= exposure * DISPLAY_WHITE_LUMINANCE;
		exposure = 1.0 / DISPLAY_WHITE_LUMINANCE;
	#endif

	absolute_input_color = max(absolute_input_color, 1e-6); // TODO: deal with the actual precision error

	vec3 absolute_input_color_inner = inner_from_xyz(absolute_input_color);

	float hue = absolute_input_color_inner.y;

	float input_brightness   = absolute_input_color_inner.x;
	float input_colorfulness = absolute_input_color_inner.z;

	float display_brightness   = input_brightness_to_display_brightness(input_brightness, exposure);
	float display_colorfulness = set_display_colorfulness(display_brightness, input_brightness, hue, input_colorfulness);

	vec3 display_color = vec3(display_brightness, hue, display_colorfulness);

	display_color = xyz_from_inner(display_color);

	display_color = display_linear_normalized_from_xyz_absolute(display_color);

	//return vec3(display_colorfulness);

	return display_color;
}
