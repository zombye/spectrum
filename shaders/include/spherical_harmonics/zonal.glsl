#if !defined INCLUDE_SPHERICAL_HARMONICS_ZONAL
#define INCLUDE_SPHERICAL_HARMONICS_ZONAL

// zonal harmonics, useful for functions which are rotationally constant around an axis

float zh_basis_order1(float direction_z) {
	return sqrt(1.0 / (4.0 * pi));
}
float[2] zh_basis_order2(float direction_z) {
	float basis_1 = zh_basis_order1(direction_z);
	return float[2](
		basis_1,
		sqrt(3.0 / (4.0 * pi)) * direction_z
	);
}
float[3] zh_basis_order3(float direction) {
	float[2] basis_2 = zh_basis_order2(direction);
	return float[3](
		basis_2[0],
		basis_2[1],
		sqrt(5.0 / (4.0 * pi)) * (3.0 * direction * direction - 1.0)
	);
}

#include "/include/spherical_harmonics/core.glsl"
float sh_orient_zh(float zh, vec3 direction) {
	return zh;
}
float[4] sh_orient_zh(float[2] zh, vec3 direction) {
	float[4] basis = sh_basis_order2(direction);
	float[4] sh;
	for (int l = 0; l < 2; ++l) {
		float convolution_coefficient = sqrt(4.0 * pi / (2.0 * l + 1.0));
		int center_index = l + l * l;
		for (int m = -l; m <= l; ++m) {
			sh[center_index + m] = convolution_coefficient * basis[center_index + m] * zh[l];
		}
	}
	return sh;
}
float[9] sh_orient_zh(float[3] zh, vec3 direction) {
	float[9] basis = sh_basis_order3(direction);
	float[9] sh;
	for (int l = 0; l < 3; ++l) {
		float convolution_coefficient = sqrt(4.0 * pi / (2.0 * l + 1.0));
		int center_index = l + l * l;
		for (int m = -l; m <= l; ++m) {
			sh[center_index + m] = convolution_coefficient * basis[center_index + m] * zh[l];
		}
	}
	return sh;
}

#endif
