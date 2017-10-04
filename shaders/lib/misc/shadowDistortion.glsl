float shadows_calculateDistortionCoeff(vec2 position) {
	return 1.0 / (length(position) + 1.0);
}

vec2 shadows_distortShadowSpace(vec2 position) {
	position *= shadows_calculateDistortionCoeff(position);
	return position;
}
vec3 shadows_distortShadowSpace(vec3 position) {
	position.xy *= shadows_calculateDistortionCoeff(position.xy);
	return position;
}
