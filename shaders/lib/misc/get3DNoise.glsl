float get3DNoise(vec3 position) {
	float flr = floor(position.z);
	vec2 coord = (position.xy * 0.015625) + (flr * 0.265625); // 1/64 | 17/64
	vec2 noise = texture2D(noisetex, coord).xy;
	return mix(noise.x, noise.y, position.z - flr);
}
