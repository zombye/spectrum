#if !defined INCLUDE_COLOR_DISPLAY_TRANSFORM_GET_INPUT_COLORFULNESS_BOUNDARY
#define INCLUDE_COLOR_DISPLAY_TRANSFORM_GET_INPUT_COLORFULNESS_BOUNDARY

#include "./config.glsl"
#include "./internal_color_space.glsl"

uniform sampler2D colortex14;

float lookup_input_gamut_boundary_colorfulness(float brightness, float hue) {
	float hue_coordinate = fract(hue / (2.0 * 3.14159265));

	float max_i = response_transfer_function_max();
	float brightness_coordinate = sqrt(inner_i_from_y(brightness) / max_i);

	const ivec2 lut_size = ivec2(DISPLAY_TRANSFORM_LUT_HUE_SIZE, DISPLAY_TRANSFORM_LUT_INPUT_BRIGHTNESS_SIZE);
	vec2 lut_uv = mix(0.5 / lut_size, (lut_size - 0.5) / lut_size, vec2(hue_coordinate, brightness_coordinate));

	return texture(colortex14, lut_uv).x;
}

#endif
