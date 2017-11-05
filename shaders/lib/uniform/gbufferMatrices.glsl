uniform mat4 gbufferModelView, gbufferModelViewInverse;

flat varying mat4 projection;
flat varying mat4 projectionInverse;

#if STAGE == STAGE_VERTEX
#if PROGRAM != PROGRAM_HAND
uniform mat4 gbufferProjection, gbufferProjectionInverse;
#endif

void calculateGbufferMatrices() {
	#if PROGRAM != PROGRAM_HAND
	projection = gbufferProjection;
	projectionInverse = gbufferProjectionInverse;
	#else // Hand has its own projection
	projection = gl_ProjectionMatrix;
	projectionInverse = gl_ProjectionMatrixInverse;
	#endif

	// Add per-frame offset for TAA
	#ifdef TEMPORAL_AA
	vec2 offset = taa_offset();
	projection[2].xy += offset;
	projectionInverse[3].xy += offset * vec2(projectionInverse[0].x, projectionInverse[1].y);
	#endif

	// TODO: Correct underwater FOV
}
#endif
