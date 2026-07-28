// 512x128 LUT
// X is hue, Y is input brightness

#include "../config.glsl"

/* RENDERTARGETS: 14 */

out float boundary_colorfulness;

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"
#include "/include/color/display.glsl"

#include "../internal_color_space.glsl"
#include "../compute_input_colorfulness_boundary.glsl"

void main() {
	float hue_coordinate        = floor(gl_FragCoord.x) / float(DISPLAY_TRANSFORM_LUT_HUE_SIZE              - 1);
	float brightness_coordinate = floor(gl_FragCoord.y) / float(DISPLAY_TRANSFORM_LUT_INPUT_BRIGHTNESS_SIZE - 1);

	float hue_angle = 2.0 * 3.14159265 * hue_coordinate;

	float max_i = response_transfer_function_max();
	float brightness = y_from_inner_i(max_i * brightness_coordinate * brightness_coordinate);

	boundary_colorfulness = compute_input_gamut_boundary_colorfulness(brightness, hue_angle);
}
