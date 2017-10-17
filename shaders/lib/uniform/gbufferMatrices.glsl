uniform mat4 gbufferModelView, gbufferModelViewInverse;

flat varying mat4 projection;
flat varying mat4 projectionInverse;

#if STAGE == STAGE_VERTEX
uniform mat4 gbufferProjection, gbufferProjectionInverse;

void calculateGbufferMatrices() {
	projection = gbufferProjection;
	projectionInverse = gbufferProjectionInverse;

	// TODO: Correct underwater FOV
}
#endif
