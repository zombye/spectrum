vec2 taa_offset() {
	vec2 scale = 2.0 / vec2(viewWidth, viewHeight);

	const vec2[16] frameOffsets = vec2[16](
		vec2(0.5, 0.5) * 0.25, // 1
		vec2(2.5, 2.5) * 0.25, // 11
		vec2(0.5, 2.5) * 0.25, // 9
		vec2(2.5, 0.5) * 0.25, // 3
		vec2(1.5, 1.5) * 0.25, // 6
		vec2(3.5, 3.5) * 0.25, // 16
		vec2(1.5, 3.5) * 0.25, // 14
		vec2(3.5, 1.5) * 0.25, // 8
		vec2(0.5, 1.5) * 0.25, // 5
		vec2(2.5, 3.5) * 0.25, // 15
		vec2(0.5, 3.5) * 0.25, // 13
		vec2(2.5, 1.5) * 0.25, // 7
		vec2(1.5, 0.5) * 0.25, // 2
		vec2(3.5, 2.5) * 0.25, // 12
		vec2(1.5, 2.5) * 0.25, // 10
		vec2(3.5, 0.5) * 0.25  // 4
	);

	return frameOffsets[frameCounter % 16] * scale + (-0.5 * scale);
}

#if STAGE == STAGE_FRAGMENT
vec3 taa_reproject(vec3 position) {
	position  = screenSpaceToViewSpace(position, gbufferProjectionInverse);
	position  = viewSpaceToSceneSpace(position, gbufferModelViewInverse);
	position += cameraPosition - previousCameraPosition;
	position  = sceneSpaceToViewSpace(position, gbufferPreviousModelView);
	position  = viewSpaceToScreenSpace(position, gbufferPreviousProjection);
	return position;
}
#endif
