vec4 projectVertex(vec3 position) {
	#if   PROGRAM == PROGRAM_SHADOW // Shadow space is distorted to give more detail closer to the player
		position = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * position + projectionShadow[3].xyz;
		float distortCoeff = shadows_calculateDistortionCoeff(position.xy);
		position.xy *= distortCoeff;
		position.z -= calculateAntiAcneOffset(normal, distortCoeff);
		return vec4(position, 1.0);
	#else // Gbuffers use the full vec4 transform for TAA
		return projection * vec4(position.xyz, 1.0);
	#endif
}
