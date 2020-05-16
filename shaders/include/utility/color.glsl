#if !defined INCLUDE_UTILITY_COLOR
#define INCLUDE_UTILITY_COLOR

// Returns a color conversion matrix to XYZ with specified source white point and primaries
mat3 CreateConversionMatrix(vec2 Wxy, vec2 Rxy, vec2 Gxy, vec2 Bxy) {
	vec3 Wxyz = vec3(Wxy, 1.0 - Wxy.x - Wxy.y);
	vec3 Rxyz = vec3(Rxy, 1.0 - Rxy.x - Rxy.y);
	vec3 Gxyz = vec3(Gxy, 1.0 - Gxy.x - Gxy.y);
	vec3 Bxyz = vec3(Bxy, 1.0 - Bxy.x - Bxy.y);

	vec3 WXYZ = Wxyz / Wxyz.y;

	mat3 tmp = mat3(
		Rxyz.x / Rxyz.y, Gxyz.x / Gxyz.y, Bxyz.x / Bxyz.y,
		1.0,             1.0,             1.0,
		Rxyz.z / Rxyz.y, Gxyz.z / Gxyz.y, Bxyz.z / Bxyz.y
	);
	vec3 lc = WXYZ * inverse(tmp);
	return mat3(lc * tmp[0], lc, lc * tmp[2]);
}

//--// Conversion matrices //-------------------------------------------------//

/*
Rec. 709 / sRGB

Wxy = 0.3127x + 0.329y
Rxy = 0.64x   + 0.33y
Gxy = 0.3x    + 0.6y
Bxy = 0.15x   + 0.06y
*/
const mat3 tmp_r709 = mat3(
	0.64 / 0.33, 0.3 / 0.6, 0.15 / 0.06,
	1.0,         1.0,       1.0,
	0.03 / 0.33, 0.1 / 0.6, 0.79 / 0.06
);
const vec3 lc_r709 = vec3(0.3127 / 0.329, 1.0, 0.3583 / 0.329) * inverse(tmp_r709);

const mat3 R709ToXyz = mat3(lc_r709 * tmp_r709[0], lc_r709, lc_r709 * tmp_r709[2]);
const mat3 XyzToR709 = inverse(R709ToXyz);

/*
Rec. 2020 / Rec. 2100

Wxy = 0.3127x + 0.329y
Rxy = 0.708x  + 0.292y
Gxy = 0.17x   + 0.797y
Bxy = 0.131x  + 0.046y
*/
const mat3 tmp_r2020 = mat3(
	0.708 / 0.292, 0.17  / 0.797, 0.131 / 0.046,
	1.0,           1.0,           1.0,
	0.0   / 0.292, 0.033 / 0.797, 0.823 / 0.046
);
const vec3 lc_r2020 = vec3(0.3127 / 0.3290, 1.0, 0.3583 / 0.3290) * inverse(tmp_r2020);

const mat3 R2020ToXyz = mat3(lc_r2020 * tmp_r2020[0], lc_r2020, lc_r2020 * tmp_r2020[2]);
const mat3 XyzToR2020 = inverse(R2020ToXyz);

//--// Set up working color space

//#define USE_R2020
#if defined USE_R2020
const mat3 XyzToRgb = XyzToR2020;
const mat3 RgbToXyz = R2020ToXyz;
#else // R709
const mat3 XyzToRgb = XyzToR709;
const mat3 RgbToXyz = R709ToXyz;
#endif

const mat3 R709ToRgb = R709ToXyz * XyzToRgb;
const mat3 RgbToR709 = RgbToXyz * XyzToR709;

// Variant that divides out the old white point
// Needed to correctly convert fractions of reflected/transmitted light (i.e. the albedo of a surface, transmittance through an atmosphere, and other things where you multiply by the illuminant)
const mat3 R709ToRgb_unlit = mat3(
	R709ToRgb[0] / (R709ToRgb[0].x + R709ToRgb[0].y + R709ToRgb[0].z),
	R709ToRgb[1] / (R709ToRgb[1].x + R709ToRgb[1].y + R709ToRgb[1].z),
	R709ToRgb[2] / (R709ToRgb[2].x + R709ToRgb[2].y + R709ToRgb[2].z)
);

//--// Transfer functions //--------------------------------------------------//

float SrgbFromLinear(float x) {
	return x <= 0.0031308 ? x * 12.92 : pow(x, 1.0 / 2.4) * 1.055 - 0.055;
}
float LinearFromSrgb(float x) {
	return x <= 0.04045 ? x / 12.92 : pow(x / 1.055 + (0.055 / 1.055), 2.4);
}

vec3 SrgbFromLinear(vec3 x) {
	return mix(pow(x, vec3(1.0 / 2.4)) * 1.055 - 0.055, x * 12.92, lessThanEqual(x, vec3(0.0031308)));
}
vec3 LinearFromSrgb(vec3 x) {
	return mix(pow(x / 1.055 + (0.055 / 1.055), vec3(2.4)), x / 12.92, lessThanEqual(x, vec3(0.04045)));
}

//----------------------------------------------------------------------------//

vec2 PlanckianLocus(float temperature) {
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

	float y = dot(xVals, temperature < 2222.0 ? yc[0] : temperature < 4000.0 ? yc[1] : yc[2]);

	return vec2(x, y);
}
vec3 Blackbody(float temperature) { // Returns XYZ blackbody radiation
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
