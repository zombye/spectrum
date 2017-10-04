vec4 projectVertex(vec3 position) {
	#if   PROGRAM == PROGRAM_SHADOW // Shadow space is distorted to give more detail closer to the player
		position = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * position + projectionShadow[3].xyz;
		position.xy = shadows_distortShadowSpace(position.xy);
		return vec4(position, 1.0);
	#elif PROGRAM == PROGRAM_BASIC || PROGRAM == PROGRAM_HAND
		return vec4(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y, gl_ProjectionMatrix[2].zw) * position.xyzz + gl_ProjectionMatrix[3];
	#else // Most gbuffers use a custom projection matrix
		return vec4(projection[0].x, projection[1].y, projection[2].zw) * position.xyzz + projection[3];
	#endif
}
