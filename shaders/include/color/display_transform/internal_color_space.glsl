#if !defined INCLUDE_COLOR_DISPLAY_TRANSFORM_INTERNAL_COLOR_SPACE
#define INCLUDE_COLOR_DISPLAY_TRANSFORM_INTERNAL_COLOR_SPACE

#include "./config.glsl"
#include "/include/utility/color.glsl"

// Based on the JzAzBz color space & the ZCAM color appearance model.

//--// Brightness separation parameters

// L cone vs M cone contribution
const float iab_i_blend_l_m = 0.65;
// L&M cones vs S cone contribution
const float iab_i_blend_lm_s = 0.0;

//--// Chroma separation transform parameters

const float iab_a_angle      = 311.0;
const float iab_a_to_b_angle = 129.0;
const float iab_a_length     = 5.4;
const float iab_b_length     = 1.1;

//--// Transfer function parameters

// brightness where colorfulness peaks
// (in the low saturation limit, higher saturation peaks later)
const float response_reference_brightness = 3.6e4;
// colorfulness falloff rate vs peak
// limit towards 0 = no falloff, towards 1 = instant
const float response_falloff_rate = 0.66;
// how quickly max falloff rate is reached
// limit towards 0 = never, towards 1 = instant
// side efect: also affects falloff rate after peak
const float response_falloff_sharpness = 0.076;

//--// LMS matrix

// White doesn't usually change much.
const vec2 lms_white_chromaticity  = vec2(0.3175, 0.33);
// LMS cone chromaticity coordinates are very important, but also have a lot more freedom than one might expect.
const vec2 lms_long_chromaticity   = vec2(0.75, 0.26);
const vec2 lms_medium_chromaticity = vec2(1.35, -0.34);
const vec2 lms_short_chromaticity  = vec2(0.25, -0.05);

// Chromaticities of some LMS transforms, for reference:
// Hunt-Pointer-Estevez LMS matrix:
// L: { x: 0.83738, y:  0.16262 }
// M: { x: 2.3022,  y: -1.3022  }
// S: { x: 0.08529, y:  0.05046 }
//
// CIE XYZ 2012 LMS basis primaries:
// L: { x: 0.7384,  y:  0.2616  }
// M: { x: 1.32672, y: -0.32672 }
// S: { x: 0.15862, y:  0       }
//
// Primaries derived from linear-space fit of LMS CMFs:
// L: { x: 0.76392, y:  0.25475 }
// M: { x: 1.59632, y: -0.50942 }
// S: { x: 0.16965, y: -0.01876 }
//
// Primaries derived from log-space fit of LMS CMFs:
// L: { x: 0.75254, y:  0.24757 }
// M: { x: 1.34534, y: -0.34299 }
// S: { x: 0.17121, y: -0.01915 }

mat3 xyz_from_lms = create_conversion_matrix(lms_white_chromaticity, lms_long_chromaticity, lms_medium_chromaticity, lms_short_chromaticity);
mat3 lms_from_xyz = inverse(xyz_from_lms);

//--//

struct dtconf {
	float response_p_in;
	float response_p_out;
	float response_c;
};

const dtconf dt = dtconf(
	response_falloff_sharpness * response_falloff_rate / ((1.0 - response_falloff_sharpness) * (1.0 - response_falloff_rate)),
	response_falloff_rate / (1.0 - response_falloff_rate),
	response_falloff_sharpness
);

float response_transfer_function(float x) {
	float tmp = sign(x) * pow(abs(x / response_reference_brightness), dt.response_p_in);
	tmp /= dt.response_c + (1.0 - dt.response_c) * tmp;
	return sign(tmp) * pow(abs(tmp), dt.response_p_out / dt.response_p_in);
}
vec3 response_transfer_function(vec3 x) {
	vec3 tmp = sign(x) * pow(abs(x / response_reference_brightness), vec3(dt.response_p_in));
	tmp /= dt.response_c + (1.0 - dt.response_c) * tmp;
	return sign(tmp) * pow(abs(tmp), vec3(dt.response_p_out / dt.response_p_in));
}
float response_transfer_function_inverse(float x) {
	float tmp = sign(x) * pow(abs(x), dt.response_p_in / dt.response_p_out);
	tmp /= (1.0 / dt.response_c) + (1.0 - (1.0 / dt.response_c)) * tmp;
	return response_reference_brightness * sign(tmp) * pow(abs(tmp), 1.0 / dt.response_p_in);
}
vec3 response_transfer_function_inverse(vec3 x) {
	vec3 tmp = sign(x) * pow(abs(x), vec3(dt.response_p_in / dt.response_p_out));
	tmp /= (1.0 / dt.response_c) + (1.0 - (1.0 / dt.response_c)) * tmp;
	return response_reference_brightness * sign(tmp) * pow(abs(tmp), vec3(1.0 / dt.response_p_in));
}

float response_transfer_function_max() {
	return pow(1.0 / (1.0 - dt.response_c), dt.response_p_out / dt.response_p_in);
}

//--//

const float iab_b_angle = iab_a_angle + iab_a_to_b_angle;
const float iab_b_length_scaled = iab_b_length / sin(radians(iab_a_to_b_angle));

const float iab_a_l_weight = iab_a_length * cos(radians(iab_a_angle));
const float iab_a_m_weight = iab_a_length * sin(radians(iab_a_angle));
const float iab_b_l_weight = iab_b_length_scaled * cos(radians(iab_b_angle));
const float iab_b_m_weight = iab_b_length_scaled * sin(radians(iab_b_angle));

const vec3 iab_i_lms_weight = vec3(
	(1.0 - iab_i_blend_l_m) * (1.0 - iab_i_blend_lm_s),
	iab_i_blend_l_m * (1.0 - iab_i_blend_lm_s),
	iab_i_blend_lm_s
);

const mat3 iab_from_lms_prime = mat3(
	iab_i_lms_weight.x, iab_a_l_weight, iab_b_l_weight,
	iab_i_lms_weight.y, iab_a_m_weight, iab_b_m_weight,
	iab_i_lms_weight.z, -iab_a_l_weight - iab_a_m_weight, -iab_b_l_weight - iab_b_m_weight
);
const mat3 lms_prime_from_iab = inverse(iab_from_lms_prime);
vec3 inner_iab_from_xyz(vec3 color_xyz) {
	vec3 color_lms = lms_from_xyz * color_xyz;
	vec3 color_lms_prime = response_transfer_function(color_lms);
	vec3 color_iab = iab_from_lms_prime * color_lms_prime;

	return color_iab;
}
vec3 xyz_from_inner_iab(vec3 color_iab) {
	vec3 color_lms_prime = lms_prime_from_iab * color_iab;
	vec3 color_lms = response_transfer_function_inverse(color_lms_prime);
	vec3 color_xyz = xyz_from_lms * color_lms;

	return color_xyz;
}
float inner_i_from_y(float y) {
	return response_transfer_function(y);
}
float y_from_inner_i(float i) {
	return response_transfer_function_inverse(i);
}

float colorfulness_rate(float y) {
	float num = pow(y / response_reference_brightness, dt.response_p_in);
	float den = dt.response_c + (1.0 - dt.response_c) * num;
	return dt.response_p_out * dt.response_c * pow(num / den, dt.response_p_out / dt.response_p_in - 1.0) * num / (den * den);
}

//--//

uniform sampler2D colortex15;
vec2 get_display_grayline_ab(float brightness) {
	const float max_i = response_transfer_function_max();
	float brightness_coordinate = sqrt(brightness / max_i);
	float lut_coordinate = mix(
		0.5 / DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE,
		(DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE - 0.5) / DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE,
		brightness_coordinate
	);
	return texture(colortex15, vec2(lut_coordinate, 0.5)).xy;
}

// Components: (brightness, hue, colorfulness)

vec3 inner_from_iab(vec3 color_iab) {
	// Move display grayline to relative
	color_iab.yz -= get_display_grayline_ab(color_iab.x);

	return vec3(
		y_from_inner_i(color_iab.x),
		atan(color_iab.z, color_iab.y),
		length(color_iab.yz)
	);
}
vec3 iab_from_inner(vec3 color_inner) {
	vec3 color_iab = vec3(
		inner_i_from_y(color_inner.x),
		cos(color_inner.y) * color_inner.z,
		sin(color_inner.y) * color_inner.z
	);

	// Move display grayline to absolute
	color_iab.yz += get_display_grayline_ab(color_iab.x);

	return color_iab;
}

vec3 inner_from_xyz(vec3 color_xyz) {
	vec3 color_iab = inner_iab_from_xyz(color_xyz);
	return inner_from_iab(color_iab);
}
vec3 xyz_from_inner(vec3 color_inner) {
	vec3 color_iab = iab_from_inner(color_inner);
	return xyz_from_inner_iab(color_iab);
}

#endif
