// TODO: Handle flowing water

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
