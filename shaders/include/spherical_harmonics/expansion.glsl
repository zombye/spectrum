#if !defined INCLUDE_SPHERICAL_HARMONICS_EXPANSION
#define INCLUDE_SPHERICAL_HARMONICS_EXPANSION

// some useful basic SH expansions
// to expand an arbitrary function f(direction): integrate sh_basis(direction) * f(direction) over all directions

#include "/include/spherical_harmonics/zonal.glsl"

// expansion of a function that is uniform 1 over the entire sphere
float sh_expansion_uniform_order1() {
	return sqrt(4.0 * pi);
}
float[4] sh_expansion_uniform_order2() {
	return float[4](sqrt(4.0 * pi), 0.0, 0.0, 0.0);
}
float[9] sh_expansion_uniform_order3() {
	return float[9](sqrt(4.0 * pi), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
}

// expansion of a function that is uniform 1 over a hemisphere and 0 over the other hemisphere
float sh_expansion_hemisphere_order1(vec3 hemisphere_direction) {
	return sqrt(pi);
}
float[4] sh_expansion_hemisphere_order2(vec3 hemisphere_direction) {
	return float[4](
		sqrt(pi),
		sqrt((3.0 / 4.0) * pi) * hemisphere_direction.y,
		sqrt((3.0 / 4.0) * pi) * hemisphere_direction.z,
		sqrt((3.0 / 4.0) * pi) * hemisphere_direction.x
	);
}
float[9] sh_expansion_hemisphere_order3(vec3 hemisphere_direction) {
	return float[9](
		sqrt(pi),
		sqrt((3.0 / 4.0) * pi) * hemisphere_direction.y,
		sqrt((3.0 / 4.0) * pi) * hemisphere_direction.z,
		sqrt((3.0 / 4.0) * pi) * hemisphere_direction.x,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0
	);
}

// expansion of cos(theta), with theta=0 in direction & theta=pi in -direction
// pretty trivial, but no reason not to include it
float sh_expansion_cosine_order1(vec3 direction) {
	return 0.0;
}
float[4] sh_expansion_cosine_order2(vec3 direction) {
	return float[4](
		0.0,
		sqrt((4.0 / 3.0) * pi) * direction.y,
		sqrt((4.0 / 3.0) * pi) * direction.z,
		sqrt((4.0 / 3.0) * pi) * direction.x
	);
}
float[9] sh_expansion_cosine_order3(vec3 direction) {
	return float[9](
		0.0,
		sqrt((4.0 / 3.0) * pi) * direction.y,
		sqrt((4.0 / 3.0) * pi) * direction.z,
		sqrt((4.0 / 3.0) * pi) * direction.x,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0
	);
}

// expansion of max(cos(theta), 0), with theta=0 in direction & theta=pi in -direction
// useful for surface irradiance evaluation
float sh_expansion_clampedcosine_order1(vec3 direction) {
	return sqrt(pi / 4.0);
}
float[4] sh_expansion_clampedcosine_order2(vec3 direction) {
	return float[4](
		sqrt(pi / 4.0),
		sqrt(pi / 3.0) * direction.y,
		sqrt(pi / 3.0) * direction.z,
		sqrt(pi / 3.0) * direction.x
	);
}
float[9] sh_expansion_clampedcosine_order3(vec3 direction) {
	const float[3] zh = float[3](sqrt(pi / 4.0), sqrt(pi / 3.0), sqrt((5.0 / 64.0) * pi));
	return sh_orient_zh(zh, direction);
}

#endif
