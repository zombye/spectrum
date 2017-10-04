flat varying mat4 modelView, projection;
flat varying mat4 modelViewInverse, projectionInverse;

#if STAGE == STAGE_VERTEX
uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;

void calculateGbufferMatrices() {
	modelView = gbufferModelView;
	projection = gbufferProjection;
	modelViewInverse = gbufferModelViewInverse;
	projectionInverse = gbufferProjectionInverse;

	// TODO: Correct underwater FOV
}
#endif
