vec3 is_GGX(vec3 normal, vec4 noise, float alpha2) {
	noise.xyz = normalize(cross(normal, noise.xyz * 2.0 - 1.0));
	return normalize(noise.xyz * sqrt(alpha2 * noise.w / (1.0 - noise.w)) + normal);
}

vec3 is_lambertian(vec3 normal, vec4 noise) {
	return (sqrt(noise.w) * normalize(cross(normal, noise.xyz * 2.0 - 1.0))) + (sqrt(1.0 - noise.w) * normal);
}
