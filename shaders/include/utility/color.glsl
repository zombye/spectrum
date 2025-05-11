#if !defined INCLUDE_UTILITY_COLOR
#define INCLUDE_UTILITY_COLOR

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"

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

	return xyz * XYZ_from_render;
}

#endif
