#if !defined INCLUDE_UTILITY_COLORSPACE
#define INCLUDE_UTILITY_COLORSPACE

const vec3 lumacoeff_rec709 = vec3(0.2126, 0.7152, 0.0722);
const vec3 srgbPrimaryWavelengthsNanometers = vec3(612.5, 549.0, 451.0); // Approximate

vec3 RgbToYcocg(vec3 rgb) {
	const mat3 mat = mat3(
		 0.25, 0.5, 0.25,
		 0.5,  0.0,-0.5,
		-0.25, 0.5,-0.25
	);
	return rgb * mat;
}
vec3 YcocgToRgb(vec3 ycocg) {
	float tmp = ycocg.x - ycocg.z;
	return vec3(tmp + ycocg.y, ycocg.x + ycocg.z, tmp - ycocg.y);
}

vec3 XyzToRgb(vec3 xyz) {
	const mat3 mat = mat3(
		 3.2409699419,-1.5373831776,-0.4986107603,
		-0.9692436363, 1.8759675015, 0.0415550574,
		 0.0556300797,-0.2039769589, 1.0569715142
	);
	return xyz * mat;
}

float LinearToSrgb(float color) {
	return mix(1.055 * pow(color, 1.0 / 2.4) - 0.055, color * 12.92, step(color, 0.0031308));
}
vec3 LinearToSrgb(vec3 color) {
	return mix(1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, color * 12.92, step(color, vec3(0.0031308)));
}
float SrgbToLinear(float color) {
	return mix(pow(color / 1.055 + (0.055 / 1.055), 2.4), color / 12.92, step(color, 0.04045));
}
vec3 SrgbToLinear(vec3 color) {
	return mix(pow(color / 1.055 + (0.055 / 1.055), vec3(2.4)), color / 12.92, step(color, vec3(0.04045)));
}

#endif
