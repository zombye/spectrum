#if !defined INCLUDE_UTILITY_COLORSPACE
#define INCLUDE_UTILITY_COLORSPACE

/*\
 *   r      g      b      w
 * x 0.6400 0.3000 0.1500 0.3127
 * y 0.3300 0.6000 0.0600 0.3290
 * z 0.0300 0.1000 0.7900 0.3583
 * Y 0.2126 0.7152 0.0722 1.0000
 *
 * X = Y * (x / y)
 * Y = Y
 * Z = Y * ((1 - x - y) / y) = Y * (z / y)
 *
 * X = (r * 0.2126 * (0.6400 / 0.3300)) + (g * 0.7152 * (0.3000 / 0.6000)) + (b * 0.0722 * (0.1500 / 0.0600))
 * Y = (r * 0.2126                    ) + (g * 0.7152                    ) + (b * 0.0722                    )
 * Z = (r * 0.2126 * (0.0300 / 0.3300)) + (g * 0.7152 * (0.1000 / 0.6000)) + (b * 0.0722 * (0.7900 / 0.0600))
\*/
const vec3 lumacoeff_rec709 = vec3(0.2126, 0.7152, 0.0722);
const mat3 RgbToXyz = mat3(
	lumacoeff_rec709 * vec3(0.6400 / 0.3300, 0.3000 / 0.6000, 0.1500 / 0.0600),
	lumacoeff_rec709,
	lumacoeff_rec709 * vec3(0.0300 / 0.3300, 0.1000 / 0.6000, 0.7900 / 0.0600)
);
const mat3 XyzToRgb = inverse(RgbToXyz);

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

vec3 Blackbody(float temperature) {
	// https://en.wikipedia.org/wiki/Planckian_locus
	const vec4[2] xc = vec4[2](
		vec4(-0.2661293e9,-0.2343589e6, 0.8776956e3, 0.179910), // 1667k <= t <= 4000k
		vec4(-3.0258469e9, 2.1070479e6, 0.2226347e3, 0.240390)  // 4000k <= t <= 25000k
	);
	const vec4[3] yc = vec4[3](
		vec4(-1.1063814,-1.34811020, 2.18555832,-0.20219683), // 1667k <= t <= 2222k
		vec4(-0.9549476,-1.37418593, 2.09137015,-0.16748867), // 2222k <= t <= 4000k
		vec4( 3.0817580,-5.87338670, 3.75112997,-0.37001483)  // 4000k <= t <= 25000k
	);

	float temperatureSquared = temperature * temperature;
	vec4 t = vec4(temperatureSquared * temperature, temperatureSquared, temperature, 1.0);

	float x = dot(1.0 / t, temperature < 4000.0 ? xc[0] : xc[1]);
	float xSquared = x * x;
	vec4 xVals = vec4(xSquared * x, xSquared, x, 1.0);

	vec3 xyz = vec3(0.0);
	xyz.y = 1.0;
	xyz.z = 1.0 / dot(xVals, temperature < 2222.0 ? yc[0] : temperature < 4000.0 ? yc[1] : yc[2]);
	xyz.x = x * xyz.z;
	xyz.z = xyz.z - xyz.x - 1.0;

	return xyz * XyzToRgb;
}

#endif
