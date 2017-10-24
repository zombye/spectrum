mat3 calculateTBN() {
	vec3 tangent = normalize(at_tangent.xyz / at_tangent.w);
	vec3 normal  = normalize(gl_Normal);
	return gl_NormalMatrix * mat3(tangent, cross(tangent, normal), normal);
}
