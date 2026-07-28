#if !defined INCLUDE_COLOR_DISPLAY
#define INCLUDE_COLOR_DISPLAY

#define DISPLAY_WHITE_LUMINANCE 350.0
//#define DISPLAY_BLACK_LUMINANCE 0.35 // 1000:1 contrast ratio
#define DISPLAY_BLACK_LUMINANCE 0.0

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"

//#define DISPLAY_USES_APPROXIMATE_SRGB // If you know your display uses the common approximation of the sRGB transfer function, turn this on.
float eotf_display(float x) {
	#ifdef DISPLAY_USES_APPROXIMATE_SRGB
		return eotf_sRGBapproximate(x);
	#else
		return eotf_sRGB(x);
	#endif
}
vec3 eotf_display(vec3 x) {
	#ifdef DISPLAY_USES_APPROXIMATE_SRGB
		return eotf_sRGBapproximate(x);
	#else
		return eotf_sRGB(x);
	#endif
}
float inverse_eotf_display(float x) {
	#ifdef DISPLAY_USES_APPROXIMATE_SRGB
		return inverse_eotf_sRGBapproximate(x);
	#else
		return inverse_eotf_sRGB(x);
	#endif
}
vec3 inverse_eotf_display(vec3 x) {
	#ifdef DISPLAY_USES_APPROXIMATE_SRGB
		return inverse_eotf_sRGBapproximate(x);
	#else
		return inverse_eotf_sRGB(x);
	#endif
}

mat3 get_display_from_xyz_matrix() {
	return BT709_from_XYZ;
}
mat3 get_xyz_from_display_matrix() {
	return XYZ_from_BT709;
}
mat3 display_from_XYZ = get_display_from_xyz_matrix();
mat3 XYZ_from_display = get_xyz_from_display_matrix();

vec3 display_linear_normalized_from_xyz_absolute(vec3 xyz_absolute) {
	// This has some additional complexity in order to correctly account for the display's black point.
	// Also, it looks like the computations here have very poor precision. Unsure why.

	// Corners for transforms to/from display gamut.
	// We assume:
	//   White & black are correct
	//   Red, green, blue have the correct chromaticity coordinate (we will later solve for their luminance)
	vec3 black_point_xyz = mat3(XYZ_from_display) * vec3(DISPLAY_BLACK_LUMINANCE);
	vec3 white_point_xyz = mat3(XYZ_from_display) * vec3(DISPLAY_WHITE_LUMINANCE);
	vec3 red_point_xyz   = XYZ_from_display[0];// = mat3(XYZ_from_display) * vec3(1.0, 0.0, 0.0);
	vec3 green_point_xyz = XYZ_from_display[1];// = mat3(XYZ_from_display) * vec3(0.0, 1.0, 0.0);
	vec3 blue_point_xyz  = XYZ_from_display[2];// = mat3(XYZ_from_display) * vec3(0.0, 0.0, 1.0);

	// To solve for red, green, blue point luminances we need to find scales such that:
	// black_point_xyz + red_point_xyz * scales.r + green_point_xyz * scales.g + blue_point_xyz * scales.b = white_point_xyz
	//
	// Rearranging...
	// red_point_xyz * scales.r + green_point_xyz * scales.g + blue_point_xyz * scales.b = white_point_xyz - black_point_xyz
	// mat3(red_point_xyz, green_point_xyz, blue_point_xyz) * scales = white_point_xyz - black_point_xyz
	//
	// Finally, we get our solution:
	// scales = inverse(mat3(red_point_xyz, green_point_xyz, blue_point_xyz)) * (white_point_xyz - black_point_xyz)
	//
	// For idealized displays with perfect blacks, the values will be exactly the white point luminance value.
	// For less-than-ideal displays, they'll typically be very close - they'll only deviate by much if the contrast ratio is truly horrid.
	vec3 scales = display_from_XYZ * (white_point_xyz - black_point_xyz);

	// Build remaining parts of transform to XYZ, incorporating the scales:
	vec3 black_point_to_red_point   = scales.r * red_point_xyz   - black_point_xyz;
	vec3 black_point_to_green_point = scales.g * green_point_xyz - black_point_xyz;
	vec3 black_point_to_blue_point  = scales.b * blue_point_xyz  - black_point_xyz;

	// We now have the true transform to XYZ from normalized linear display color:
	// xyz = black_point_to_red_point   * display.r
	//     + black_point_to_green_point * display.g
	//     + black_point_to_blue_point  * display.b
	//     + black_point_xyz;

	// Invert it and we get the final transform from XYZ to linear normalized display color:
	// This matrix is (apparently) not precise enough. Unclear why.
	return inverse(mat3(black_point_to_red_point, black_point_to_green_point, black_point_to_blue_point)) * (xyz_absolute - black_point_xyz);
}
vec3 xyz_absolute_from_display_linear_normalized(vec3 display_linear_normalized) {
	// This has some additional complexity in order to correctly account for the display's black point.
	// Also, it looks like the computations here have very poor precision. Unsure why.

	// Corners for transforms to/from display gamut.
	// We assume:
	//   White & black are correct
	//   Red, green, blue have the correct chromaticity coordinate (we will later solve for their luminance)
	vec3 black_point_xyz = mat3(XYZ_from_display) * vec3(DISPLAY_BLACK_LUMINANCE);
	vec3 white_point_xyz = mat3(XYZ_from_display) * vec3(DISPLAY_WHITE_LUMINANCE);
	vec3 red_point_xyz   = XYZ_from_display[0];// = mat3(XYZ_from_display) * vec3(1.0, 0.0, 0.0);
	vec3 green_point_xyz = XYZ_from_display[1];// = mat3(XYZ_from_display) * vec3(0.0, 1.0, 0.0);
	vec3 blue_point_xyz  = XYZ_from_display[2];// = mat3(XYZ_from_display) * vec3(0.0, 0.0, 1.0);

	// To solve for red, green, blue point luminances we need to find scales such that:
	// black_point_xyz + red_point_xyz * scales.r + green_point_xyz * scales.g + blue_point_xyz * scales.b = white_point_xyz
	//
	// Rearranging...
	// red_point_xyz * scales.r + green_point_xyz * scales.g + blue_point_xyz * scales.b = white_point_xyz - black_point_xyz
	// mat3(red_point_xyz, green_point_xyz, blue_point_xyz) * scales = white_point_xyz - black_point_xyz
	//
	// Finally, we get our solution:
	// scales = inverse(mat3(red_point_xyz, green_point_xyz, blue_point_xyz)) * (white_point_xyz - black_point_xyz)
	//
	// For idealized displays with perfect blacks, the values will be exactly the white point luminance value.
	// For less-than-ideal displays, they'll typically be very close - they'll only deviate by much if the contrast ratio is truly horrid.
	vec3 scales = display_from_XYZ * (white_point_xyz - black_point_xyz);

	// Build remaining parts of transform to XYZ, incorporating the scales:
	vec3 black_point_to_red_point   = scales.r * red_point_xyz   - black_point_xyz;
	vec3 black_point_to_green_point = scales.g * green_point_xyz - black_point_xyz;
	vec3 black_point_to_blue_point  = scales.b * blue_point_xyz  - black_point_xyz;

	// We now have the true transform to XYZ from normalized linear display color:
	// xyz = black_point_to_red_point   * display.r
	//     + black_point_to_green_point * display.g
	//     + black_point_to_blue_point  * display.b
	//     + black_point_xyz;
	return mat3(black_point_to_red_point, black_point_to_green_point, black_point_to_blue_point) * display_linear_normalized + black_point_xyz;
}

#endif
