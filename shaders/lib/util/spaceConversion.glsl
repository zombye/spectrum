vec3 screenSpaceToViewSpace(vec3 position, mat4 projectionInverse) {
	position = position * 2.0 - 1.0;
	return (vec3(projectionInverse[0].x, projectionInverse[1].y, projectionInverse[2].z) * position + projectionInverse[3].xyz) / (position.z * projectionInverse[2].w + projectionInverse[3].w);
}
vec3 viewSpaceToScreenSpace(vec3 position, mat4 projection) {
	return ((vec3(projection[0].x, projection[1].y, projection[2].z) * position + projection[3].xyz) / position.z) * -0.5 + 0.5;
}

vec3 viewSpaceToSceneSpace(vec3 position, mat4 modelViewInverse) {
	return mat3(modelViewInverse) * position + modelViewInverse[3].xyz;
}
vec3 sceneSpaceToViewSpace(vec3 position, mat4 modelView) {
	return mat3(modelView) * position + modelView[3].xyz;
}

float linearizeDepth(float depth, mat4 projectionInverse) {
	return -1.0 / ((depth * 2.0 - 1.0) * projectionInverse[2].w + projectionInverse[3].w);
}
float delinearizeDepth(float depth, mat4 projection) {
	return ((depth * projection[2].z + projection[3].z) / depth) * -0.5 + 0.5;
}
