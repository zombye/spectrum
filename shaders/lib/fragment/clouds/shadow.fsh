float clouds_shadowLayer(vec3 startPosition, vec3 direction, vec3 shadowDirection, cloudLayerParameters params) {
	float transmittance = 1.0;

	// distance to start and end of cloud layer - .x = start, .y = end
	vec2 distances = vec2(params.altitudeMin, params.altitudeMax); // top of clouds is y by default
	distances = (distances - startPosition.y) / direction.y;       // get distance to the upper and lower bounds
	if (distances.y < distances.x) distances = distances.yx;       // y less than x? we're looking downwards, so swap them

	// increse step count based on distance trough clouds, set step size
	float stepSize = (distances.y - distances.x) / params.baseSamples;

	// set increment and initialize position
	vec3 increment = direction * stepSize;
	vec3 position = increment * 0.5 + (direction * distances.x + startPosition);

	// transmitted scattering integral constants
	float tsi_a = -params.coeff / log(2.0);

	// loop
	for (int i = 0; i < params.baseSamples; i++, position += increment) {
		transmittance *= exp2(tsi_a * clouds_density(position, params) * stepSize);
	}

	return transmittance;
}

float clouds_shadow(vec3 position, vec3 direction) {
	direction = mat3(gbufferModelViewInverse) * direction;
	vec3 startPosition = position + cameraPosition;
	vec3 shadowDirection = mat3(gbufferModelViewInverse) * shadowLightVector;

	float transmittance = 1.0;
	for (int i = 0; i < clouds_layers.length(); i++) {
		#ifndef CLOUDS_LOWER_LAYER
		if (i == 1) break;
		#endif
		transmittance *= clouds_shadowLayer(startPosition, direction, shadowDirection, clouds_layers[i]);
	}

	return transmittance;
}
