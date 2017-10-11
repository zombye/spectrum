bool raytraceIntersection(vec3 start, vec3 direction, out vec3 position, float dither, const float quality, const float refinements) {
	position   = start;
	start      = screenSpaceToViewSpace(start, projectionInverse); // Make start be linearized
	direction *= -start.z; // Ensures direction is always correct even when very close to a surface.
	direction  = viewSpaceToScreenSpace(direction + start, projection) - position;

	direction *= clamp(minof((step(0.0, direction) - position) / direction) / quality, 0.0001, 1.0);
	float difference;
	bool  intersected = false;

	position -= direction * dither;

	for (float i = 0.0; i <= quality && !intersected && position.p < 1.0; i++) {
		position += direction;

		if (floor(position.st) != vec2(0.0)) return false;

		difference  = texture2D(depthtex1, position.st).r - position.p;
		intersected = -2.0 * direction.z < difference && difference < 0.0;
	}

	bool hit = intersected && (difference + position.p) < 1.0 && position.p > 0.0;

	// Refinements
	for (float i = 0.0; i < refinements; i++) {
		direction *= 0.5;
		position  += difference < 0.0 ? -direction : direction;

		difference = texture2D(depthtex1, position.st).r - position.p;
	}

	return hit;
}
bool raytraceIntersection(vec3 start, vec3 direction, out vec3 position, float dither, const float quality) {
	return raytraceIntersection(start, direction, position, dither, quality, 0.0);
}
