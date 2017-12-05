vec4 projectVertex(vec3 position) {
	#if   PROGRAM == PROGRAM_SHADOW // Shadow space is distorted to give more detail closer to the player
		position = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * position + projectionShadow[3].xyz;
		float distortCoeff = shadows_calculateDistortionCoeff(position.xy);
		position.xy *= distortCoeff;
		position.z -= calculateAntiAcneOffset(normal, distortCoeff);
		return vec4(position, 1.0);
	#else
		return vec4(projection[0].x, projection[1].y, projection[2].zw) * position.xyzz + projection[3] + vec4(projection[2].xy * position.z, 0.0, 0.0);
	#endif
}
