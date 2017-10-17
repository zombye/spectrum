// TODO: Handle flowing water

#define WATER_PARALLAX

vec3 water_calculateParallax(vec3 pos, vec3 direction) {
	#ifndef WATER_PARALLAX
	return pos;
	#endif

	const int steps = 4;

	vec3  interval = 0.4 * direction / abs(direction.y);
	vec3  offset   = vec3(0.0, 0.0, 0.0);
	float height   = water_calculateWaves(pos);

	for (float i = 0.0; i < steps && height < offset.y; i++) {
		offset += mix(vec3(0.0), interval, offset.y - height);
		height  = water_calculateWaves(vec3(1.0, 0.0, 1.0) * offset + pos);
	}

	return vec3(1.0, 0.0, 1.0) * offset + pos;
}

vec3 water_calculateNormal(vec3 pos) {
	const float dist = 0.01;

	vec2 diffs;
	diffs.x = water_calculateWaves(pos + vec3( dist, 0.0, -dist));
	diffs.y = water_calculateWaves(pos + vec3(-dist, 0.0,  dist));
	diffs  -= water_calculateWaves(pos + vec3(-dist, 0.0, -dist));

	vec3 normal = vec3(-2.0 * dist, 4.0 * dist * dist, -2.0 * (dist * dist + dist));
	normal.xz *= diffs;

	return normalize(normal);
}
vec3 water_calculateNormal(vec3 pos, mat3 tbn, vec3 viewDir) {
	pos = water_calculateParallax(pos, (viewDir * tbn).xzy);

	vec3 normal = water_calculateNormal(pos).xzy;

	// Bias normals to flat based on angle - looks a lot better, but not realistic.
	float bias = pow(max0(dot(-viewDir, tbn[2])), 0.76);
	normal = mix(vec3(0.0, 0.0, 1.0), normal, bias);

	return tbn * normal;
}
