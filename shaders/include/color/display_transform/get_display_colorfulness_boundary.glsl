#if !defined INCLUDE_COLOR_DISPLAY_TRANSFORM_GET_DISPLAY_COLORFULNESS_BOUNDARY
#define INCLUDE_COLOR_DISPLAY_TRANSFORM_GET_DISPLAY_COLORFULNESS_BOUNDARY

#include "./config.glsl"
#include "./internal_color_space.glsl"

uniform sampler2D colortex13;

float lookup_display_gamut_boundary_colorfulness(float brightness, float hue_angle) {
	vec3 display_white_xyz = xyz_absolute_from_display_linear_normalized(vec3(1.0));
	vec3 display_black_xyz = xyz_absolute_from_display_linear_normalized(vec3(0.0));
	float display_white_brightness = inner_i_from_y(inner_from_xyz(display_white_xyz).x);
	float display_black_brightness = inner_i_from_y(inner_from_xyz(display_black_xyz).x);

	brightness = (inner_i_from_y(brightness) - display_black_brightness) / (display_white_brightness - display_black_brightness);
	float brightness_coordinate = sqrt(brightness);

	float hue_coordinate = fract(hue_angle / (2.0 * 3.14159265));

	ivec2 lut_size = ivec2(DISPLAY_TRANSFORM_LUT_HUE_SIZE, DISPLAY_TRANSFORM_LUT_DISPLAY_BRIGHTNESS_SIZE);

	vec2 lut_uv = mix(0.5 / lut_size, (lut_size - 0.5) / lut_size, vec2(hue_coordinate, brightness_coordinate));

	return texture(colortex13, lut_uv).x;
}

#endif
