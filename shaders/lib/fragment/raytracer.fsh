bool raytraceIntersection(vec3 start, vec3 direction, out vec3 position, float dither, const float quality) {
	position   = start;
	start      = screenSpaceToViewSpace(start, projectionInverse); // Make start be linearized
	direction *= -start.z; // Ensures direction is always correct even when very close to a surface.
	direction  = viewSpaceToScreenSpace(direction + start, projection) - position;
	direction *= inversesqrt(dot(direction.xy, direction.xy));

	//direction *= minof((step(0.0, direction) - position) / direction) / quality;
	direction /= quality;
	float difference;
	bool  intersected;

	{
		position += direction * dither;

		if (floor(position.st) != vec2(0.0)) return false;

		difference  = texture2D(depthtex1, position.st).r - position.p;
		intersected = difference < 0.0;
	}

	while (!intersected && position.p < 1.0) {
		position += direction;

		if (floor(position.st) != vec2(0.0)) return false;

		difference  = texture2D(depthtex1, position.st).r - position.p;
		intersected = difference < 0.0;
	}

	return intersected && (difference + position.p) < 1.0 && position.p > 0.0;
}
