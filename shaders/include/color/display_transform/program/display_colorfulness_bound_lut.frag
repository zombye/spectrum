// 512x64 LUT
// X is hue, Y is display brightness

#include "../config.glsl"

/* RENDERTARGETS: 13 */

out float boundary_colorfulness;

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"
#include "/include/color/display.glsl"

#include "../internal_color_space.glsl"
#include "../compute_display_colorfulness_boundary.glsl"

void main() {
	float hue_coordinate        = floor(gl_FragCoord.x) / float(DISPLAY_TRANSFORM_LUT_HUE_SIZE                - 1);
	float brightness_coordinate = floor(gl_FragCoord.y) / float(DISPLAY_TRANSFORM_LUT_DISPLAY_BRIGHTNESS_SIZE - 1);

	float hue_angle = 2.0 * 3.14159265 * hue_coordinate;

	vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
	vec3 display_black_xyz = xyz_absolute_from_display_linear_normalized(vec3(0.0));
	float display_white_brightness = inner_from_xyz(display_white_xyz).x;
	float display_black_brightness = inner_from_xyz(display_black_xyz).x;

	float display_brightness = y_from_inner_i(mix(
		inner_i_from_y(display_black_brightness),
		inner_i_from_y(display_white_brightness),
		brightness_coordinate * brightness_coordinate
	));

	boundary_colorfulness = compute_display_gamut_boundary_colorfulness(display_brightness, hue_angle);
}
