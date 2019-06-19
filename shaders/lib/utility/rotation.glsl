#if !defined INCLUDE_UTILITY_ROTATION
#define INCLUDE_UTILITY_ROTATION

vec2 Rotate(vec2 vector, float angle) {
	float cosine = cos(angle);
	float sine = sin(angle);

	return vec2(cosine * vector.x - sine * vector.y, cosine * vector.y + sine * vector.x);
}
vec3 Rotate(vec3 vector, vec3 axis, float angle) {
	// https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
	float cosine = cos(angle);
	float sine = sin(angle);

	float tmp = dot(axis, vector);
	return cosine * vector + sine * cross(axis, vector) + (tmp - tmp * cosine) * axis;
}
vec3 Rotate(vec3 vector, vec3 from, vec3 to) {
	// where "from" and "to" are two unit vectors determining how far to rotate
	// adapted version of https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula

	float cosine = dot(from, to);
	vec3 axis = cross(from, to);
	float cosecant = inversesqrt(dot(axis, axis));

	return cosine * vector + cross(axis, vector) + (cosecant - cosecant * cosine) * cosecant * dot(axis, vector) * axis;
}

mat2 GetRotationMatrix(float angle) {
	float cosine = cos(angle);
	float sine = sin(angle);
	return mat2(cosine, -sine, sine, cosine);
}

#endif
