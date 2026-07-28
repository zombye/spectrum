#if !defined INCLUDE_UTILITY_COLOR
#define INCLUDE_UTILITY_COLOR

#include "/include/color/primary_transform.glsl"
#include "/include/color/transfer_function.glsl"

// Computes the matrix to convert to XYZ from a color space with specified xyY xy primaries.
mat3 create_conversion_matrix(
	vec2 pri_white_xy,
	vec2 pri_first_xy,
	vec2 pri_second_xy,
	vec2 pri_third_xy
) {
	vec3 pri_white_xyz  = vec3(pri_white_xy,  1.0 - pri_white_xy.x  - pri_white_xy.y );
	vec3 pri_first_xyz  = vec3(pri_first_xy,  1.0 - pri_first_xy.x  - pri_first_xy.y );
	vec3 pri_second_xyz = vec3(pri_second_xy, 1.0 - pri_second_xy.x - pri_second_xy.y);
	vec3 pri_third_xyz  = vec3(pri_third_xy,  1.0 - pri_third_xy.x  - pri_third_xy.y );

	// Solve for relative weights:
	// Wx = Rw * Rx + Gw * Gx + Bw * Bx
	// Wy = Rw * Ry + Gw * Gy + Bw * By
	// Wz = Rw * Rz + Gw * Gz + Bw * Bz
	// -> Matrix form
	// | Wx |   | Rx Gx Bx | | Rw |
	// | Wy | = | Ry Gy By | | Gw |
	// | Wz |   | Rz Gz Bz | | Bw |
	// -> Invert matrix to find solution
	vec3 pri_weight = inverse(mat3(
		pri_first_xyz,
		pri_second_xyz,
		pri_third_xyz
	)) * pri_white_xyz;

	// Find normalization c such that
	// 1 = c * (Rw * Ry + Gw * Gy + Bw * By)
	// and apply to weights
	pri_weight /= pri_weight.r * pri_first_xyz.y + pri_weight.g * pri_second_xyz.y + pri_weight.b * pri_third_xyz.y;

	// Assemble the matrix
	return mat3(
		pri_weight.r * pri_first_xyz,
		pri_weight.g * pri_second_xyz,
		pri_weight.b * pri_third_xyz
	);
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
