#if !defined INCLUDE_UTILITY_COLORSPACE
#define INCLUDE_UTILITY_COLORSPACE

/*\
 *   r      g      b      w
 * x 0.6400 0.3000 0.1500 0.3127
 * y 0.3300 0.6000 0.0600 0.3290
 * z 0.0300 0.1000 0.7900 0.3583
 * Y 0.2126 0.7152 0.0722 1.0000
 * 
 * X = (Y / y) * x
 * Y = Y
 * Z = (Y / y) * (1 - x - y) = (Y / y) * z
 * 
 * X = (r * (0.2126 / 0.3300) * 0.6400) + (g * (0.7152 / 0.6000) * 0.3000) + (b * (0.0722 / 0.0600) * 0.1500)
 * Y = (r *  0.2126                   ) + (g *  0.7152                   ) + (b *  0.0722                   )
 * Z = (r * (0.2126 / 0.3300) * 0.0300) + (g * (0.7152 / 0.6000) * 0.1000) + (b * (0.0722 / 0.0600) * 0.7900)
\*/
const mat3 RgbToXyz = mat3(
	vec3((0.2126 / 0.3300) * 0.6400, (0.7152 / 0.6000) * 0.3000, (0.0722 / 0.0600) * 0.1500),
	vec3( 0.2126                   ,  0.7152                   ,  0.0722                   ),
	vec3((0.2126 / 0.3300) * 0.0300, (0.7152 / 0.6000) * 0.1000, (0.0722 / 0.0600) * 0.7900)
);
const mat3 XyzToRgb = inverse(RgbToXyz);

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
