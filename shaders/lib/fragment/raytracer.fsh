bool raytraceIntersection(vec3 start, vec3 direction, out vec3 position, float dither, const float quality, const float refinements) {
	position   = start;
	start      = screenSpaceToViewSpace(start, projectionInverse);
	direction *= -start.z;
	direction  = viewSpaceToScreenSpace(direction + start, projection) - position;
	direction *= minof((step(0.0, direction) - position) / direction) / quality;

	float difference;
	bool  intersected = false;

	// raytrace for intersection
	position   += direction * dither;
	difference  = texture2D(depthtex1, position.st).r - position.p;
	intersected = -2.0 * direction.z < difference && difference < 0.0;

	for (float i = 1.0; i <= quality && !intersected && position.p < 1.0; i++) {
		position   += direction;
		difference  = texture2D(depthtex1, position.st).r - position.p;
		intersected = -2.0 * direction.z < difference && difference < 0.0;
	}

	// validate intersection
	intersected = intersected && (difference + position.p) < 1.0 && position.p > 0.0;

	if (intersected) {
		// refine intersection position
		direction *= 0.5;
		position  += difference < 0.0 ? -direction : direction;

		for (float i = 1.0; i < refinements; i++) {
			direction *= 0.5;
			position  += texture2D(depthtex1, position.st).r - position.p < 0.0 ? -direction : direction;
		}
	}

	return intersected;
}
bool raytraceIntersection(vec3 start, vec3 direction, out vec3 position, float dither, const float quality) {
	return raytraceIntersection(start, direction, position, dither, quality, 0.0);
}
