#if !defined INCLUDE_COLOR_TRANSFER_FUNCTION
#define INCLUDE_COLOR_TRANSFER_FUNCTION

// Classic gamma 2.2 approximation for srgb, unfortunately common for displays
float eotf_sRGB_approximate(float x) {
	return pow(x, 2.2);
}
vec3 eotf_sRGB_approximate(vec3 x) {
	return pow(x, vec3(2.2));
}
float inverse_eotf_sRGB_approximate(float x) {
	return pow(x, 1.0 / 2.2);
}
vec3 inverse_eotf_sRGB_approximate(vec3 x) {
	return pow(x, vec3(1.0 / 2.2));
}

// sRGB
float eotf_sRGB(float x) {
	return mix(
		pow((200.0 / 211.0) * x + (11.0 / 211.0), 12.0 / 5.0),
		(25.0 / 323.0) * x,
		x <= 0.04045
	);
}
vec3 eotf_sRGB(vec3 x) {
	return mix(
		pow((200.0 / 211.0) * x + (11.0 / 211.0), vec3(12.0 / 5.0)),
		(25.0 / 323.0) * x,
		lessThanEqual(x, vec3(0.04045))
	);
}
float inverse_eotf_sRGB(float x) {
	return mix(
		(211.0 / 200.0) * pow(x, 5.0 / 12.0) - (11.0 / 200.0),
		(323.0 / 25.0) * x,
		x < 0.0031308
	);
}
vec3 inverse_eotf_sRGB(vec3 x) {
	return mix(
		(211.0 / 200.0) * pow(x, vec3(5.0 / 12.0)) - (11.0 / 200.0),
		(323.0 / 25.0) * x,
		lessThan(x, vec3(0.0031308))
	);
}

#endif
