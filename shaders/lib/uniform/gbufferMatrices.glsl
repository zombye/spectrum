uniform mat4 gbufferModelView, gbufferModelViewInverse;

flat varying mat4 projection;
flat varying mat4 projectionInverse;

#if STAGE == STAGE_VERTEX
#if PROGRAM != PROGRAM_HAND
uniform mat4 gbufferProjection, gbufferProjectionInverse;
#endif

#extension GL_ARB_gpu_shader5 : enable

void calculateGbufferMatrices() {
	#if PROGRAM != PROGRAM_HAND
	projection = gbufferProjection;
	projectionInverse = gbufferProjectionInverse;
	#else // Hand has its own projection
	projection = gl_ProjectionMatrix;
	projectionInverse = gl_ProjectionMatrixInverse;
	#endif

	// Add per-frame offset for TAA
	vec2 offset = taa_offset();
	projection[2].xy        += offset;
	projectionInverse[3].xy += offset;

	// TODO: Correct underwater FOV
}
#endif
