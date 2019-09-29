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
	float cosecantSquared = 1.0 / dot(axis, axis);

	return cosine * vector + cross(axis, vector) + (cosecantSquared - cosecantSquared * cosine) * dot(axis, vector) * axis;
}

mat2 GetRotationMatrix(float angle) {
	float cosine = cos(angle);
	float sine = sin(angle);
	return mat2(cosine, -sine, sine, cosine);
}
mat3 GetRotationMatrix(vec3 unitAxis, float angle) {
	float cosine = cos(angle);

	vec3 axis = unitAxis * sin(angle);
	vec3 tmp = unitAxis - unitAxis * cosine;

	return mat3(
		unitAxis.x * tmp.x + cosine, unitAxis.x * tmp.y - axis.z, unitAxis.x * tmp.z + axis.y,
		unitAxis.y * tmp.x + axis.z, unitAxis.y * tmp.y + cosine, unitAxis.y * tmp.z - axis.x,
		unitAxis.z * tmp.x - axis.y, unitAxis.z * tmp.y + axis.x, unitAxis.z * tmp.z + cosine
	);
}
mat3 GetRotationMatrix(vec3 from, vec3 to) {
	float cosine = dot(from, to);
	vec3 axis = cross(to, from);

	float tmp = 1.0 / dot(axis, axis);
	      tmp = tmp - tmp * cosine;
	vec3 tmpv = axis * tmp;

	return mat3(
		axis.x * tmpv.x + cosine, axis.x * tmpv.y - axis.z, axis.x * tmpv.z + axis.y,
		axis.y * tmpv.x + axis.z, axis.y * tmpv.y + cosine, axis.y * tmpv.z - axis.x,
		axis.z * tmpv.x - axis.y, axis.z * tmpv.y + axis.x, axis.z * tmpv.z + cosine
	);
}

#endif
