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
vec3 taa_getClosestFragment() {
	vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

	vec3 closestFragment = vec3(screenCoord, 1.0);

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 currentCoord = vec2(x, y) * pixel + screenCoord;
			vec3 currentFragment = vec3(currentCoord, texture2D(depthtex0, currentCoord).r);

			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;
		}
	}

	return closestFragment;
}
vec3 taa_velocity(vec3 position) {
	vec3 currentPosition = position;
	position  = screenSpaceToViewSpace(position, gbufferProjectionInverse);
	position  = viewSpaceToSceneSpace(position, gbufferModelViewInverse);
	position += cameraPosition - previousCameraPosition;
	position  = sceneSpaceToViewSpace(position, gbufferPreviousModelView);
	position  = viewSpaceToScreenSpace(position, gbufferPreviousProjection);

	return position - currentPosition;
}

vec3 taa_apply() {
	vec2 resolution = vec2(viewWidth, viewHeight);
	vec2 pixel = 1.0 / resolution;
	vec3 position = vec3(screenCoord, texture2D(depthtex0, screenCoord).r);
	float blendWeight = 0.85; // Base blend weight

	// Get velocity from closest fragment in 3x3 to camera rather than current fragment, gives nicer edges in motion.
	vec3 closestFragment = taa_getClosestFragment();
	vec3 velocity = taa_velocity(closestFragment);

	// Calculate reprojected position using velocity
	vec3 reprojectedPosition = position + velocity;

	// Offscreen fragments should be ignored
	if (floor(reprojectedPosition.xy) != vec2(0.0)) blendWeight = 0.0;

	// Reduce weight when further from a texel center, reduces blurring
	blendWeight *= sqrt(dot(0.5 - abs(fract(reprojectedPosition.xy * resolution) - 0.5), vec2(1.0)));

	// Get color values in 3x3 around current fragment
	vec3 centerColor, minColor, maxColor;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec3 sampleColor = texture2D(colortex4, vec2(x, y) * pixel + screenCoord).rgb;

			if (x == -1 && y == -1) { // Initialize min & max color values
				minColor = sampleColor;
				maxColor = sampleColor;
				continue;
			}

			if (x == 0 && y == 0) centerColor = sampleColor;

			minColor = min(sampleColor, minColor);
			maxColor = max(sampleColor, maxColor);
		}
	}

	// Get reprojected previous frame color, clamped with min & max around current frame fragment to prevent ghosting
	vec3 prevColor = clamp(texture2D(colortex3, reprojectedPosition.st).rgb, minColor, maxColor);

	// Apply a simple tonemap, blend, reverse tonemap, and return.
	centerColor /= 1.0 + centerColor;
	prevColor   /= 1.0 + prevColor;

	vec3 antiAliased = mix(centerColor, prevColor, blendWeight);

	return antiAliased / (1.0 - antiAliased);
}
#endif
