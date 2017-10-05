#define WATER_PARALLAX

vec3 water_calculateParallax(vec3 pos, vec3 dir) {
	#ifndef WATER_PARALLAX
	return pos;
	#endif

	const int steps = 4;

	vec3  increm = 0.4 * dir / abs(dir.y);
	vec3  offset = vec3(0.0, 0.0, 0.0);
	float height = water_calculateWaves(pos);

	for (float i = 0.0; i < steps && height < offset.y; i += 1.0) {
		offset += mix(vec3(0.0), increm, offset.y - height);
		height  = water_calculateWaves(pos + vec3(offset.x, 0.0, offset.z));
	}

	return pos + vec3(offset.x, 0.0, offset.z);
}
