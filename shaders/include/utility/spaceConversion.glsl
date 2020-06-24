#if !defined INCLUDE_UTILITY_SPACECONVERSION
#define INCLUDE_UTILITY_SPACECONVERSION

vec3 ViewSpaceToScreenSpace(vec3 viewPosition, mat4 projection) {
	vec3 screenPosition = vec3(projection[0].x, projection[1].y, projection[2].z) * viewPosition + projection[3].xyz;

	return screenPosition * (0.5 / -viewPosition.z) + 0.5;
}
vec3 ScreenSpaceToViewSpace(vec3 screenPosition, mat4 projectionInverse) {
	screenPosition = screenPosition * 2.0 - 1.0;

	vec3 viewPosition  = vec3(vec2(projectionInverse[0].x, projectionInverse[1].y) * screenPosition.xy + projectionInverse[3].xy, projectionInverse[3].z);
	     viewPosition /= projectionInverse[2].w * screenPosition.z + projectionInverse[3].w;

	return viewPosition;
}

vec3 GetViewDirection(vec2 uv, mat4 projectionInverse) {
	uv = uv * 2.0 - 1.0;

	uv = vec2(projectionInverse[0].x, projectionInverse[1].y) * uv + projectionInverse[3].xy;

	return normalize(vec3(uv, projectionInverse[3].z));
}

float ViewSpaceToScreenSpace(float depth, mat4 projection) {
	return (projection[2].z * depth + projection[3].z) * 0.5 / -depth + 0.5;
}
float ScreenSpaceToViewSpace(float depth, mat4 projectionInverse) {
	depth = depth * 2.0 - 1.0;
	return projectionInverse[3].z / (projectionInverse[2].w * depth + projectionInverse[3].w);
}

#endif
