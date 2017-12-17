float clouds_phase(float cosTheta, vec2 g, float b) {
	vec2 gmn2 = -2.0 * g;
	vec2 gg   = g * g;
	vec2 gga1 = 1.0 + gg;
	vec2 p1   = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));

	vec2 res = p1 * (cosTheta * cosTheta + 1.0) * pow(gmn2 * cosTheta + gga1, vec2(-1.5));

	return mix(res.x, res.y, b) * 0.7 + 0.075/pi;
}

float clouds_odDirection(vec3 position, vec3 direction, float startDensity, const float range, const float samples, cloudLayerParameters params) {
	const float stepSize = range / (samples + 0.5);

	direction *= stepSize;
	position += direction * 0.75;

	float od = -0.5 * startDensity;
	for (float i = 0.0; i < samples; i++, position += direction) {
		od -= clouds_density(position, params);
	}
	return stepSize * od;
}

mat2x3 clouds_layer(vec3 startPosition, vec3 direction, vec3 directionShadow, float dither, out float layerDistance, cloudLayerParameters params) {
	layerDistance = 0.0;
	mat2x3 layer = mat2x3(vec3(0.0), vec3(1.0));

	// distance to start and end of cloud layer - .x = start, .y = end
	vec2 distances = vec2(params.altitudeMin, params.altitudeMax); // top of clouds is y by default
	distances = (distances - startPosition.y) / direction.y;       // get distance to the upper and lower bounds
	if (distances.y < distances.x) distances = distances.yx;       // y less than x? we're looking downwards, so swap them
	distances.x = max(distances.x, 0.0);                           // start can never be closer than 0
	if (distances.y < distances.x) return layer;                   // y now less than x again? layer is not visible, so return

	// increse step count based on distance trough clouds, set step size
	float samples  = floor(params.baseSamples * min((distances.y - distances.x) / (params.altitudeMax - params.altitudeMin), params.maxSamplesScale));
	float stepSize = (distances.y - distances.x) / samples;

	// set increment and initialize position
	vec3 increment = direction * stepSize;
	vec3 position  = increment * dither + (direction * distances.x + startPosition);

	// light source directions and illuminances
	const vec3 directionSky     = vec3(0.0, 1.0, 0.0);
	const vec3 directionBounced = vec3(0.0,-1.0, 0.0);

	const vec3 bouncedLightColor = vec3(0.31, 0.34, 0.31); // wish I had an average sunlit color for 1-2 km around the player, a grey with subtle green tint looks natural enough so that will have to do

	vec3 illuminanceShadow  = shadowLightColor * clouds_phase(dot(direction, directionShadow), vec2(0.6, -0.15), 0.5);
	vec3 illuminanceSky     = skyLightColor * 0.5;
	vec3 illuminanceBounced = dot(shadowLightVector, upVector) * bouncedLightColor * shadowLightColor * 0.5 / pi;

	// transmitted scattering integral constants
	float tsi_a = -params.coeff / log(2.0);
	float tsi_b = -1.0 / params.coeff;
	float tsi_c =  1.0 / params.coeff;

	// loop
	vec2 distanceAverage = vec2((distances.x + distances.y) * 0.5, 1.0) * 0.0001;
	for (int i = 0; i < samples; i++, position += increment) {
		float density = clouds_density(position, params);
		if (density == 0.0) continue;

		vec3 visOD = vec3( // Find optical depths towards each light source
			clouds_odDirection(position, directionShadow,  density, params.visRangeShadow,  params.visSamplesShadow,  params),
			clouds_odDirection(position, directionSky,     density, params.visRangeSky,     params.visSamplesSky,     params),
			clouds_odDirection(position, directionBounced, density, params.visRangeBounced, params.visSamplesBounced, params)
		);

		float od = density * stepSize;

		// Approximate multiple scattering
		vec3 sampleScattering = vec3(0.0);
		for (int j = 1; j <= params.msa_octaves; j++) {
			vec2 coeffs = params.coeff * pow(vec2(params.msa_a, params.msa_b), vec2(j));

			vec3 msaLight = exp(coeffs.y * visOD);
			msaLight = msaLight.x * illuminanceShadow + msaLight.y * illuminanceSky + msaLight.z * illuminanceBounced;

			sampleScattering += coeffs.x * msaLight;
		}

		// add step to result, integrate transmitted scattering
		float transmittanceStep     = exp2(tsi_a * od);
		float transmittedScattering = (transmittanceStep * tsi_b + tsi_c) * layer[1].x;
		layer[0] += sampleScattering * transmittedScattering;
		layer[1] *= transmittanceStep;

		// add to distance average weighted based on importance
		distanceAverage += vec2(distance(position, startPosition), 1.0) * transmittedScattering;
	}

	layerDistance = distanceAverage.x / distanceAverage.y;

	return layer;
}

mat2x3 clouds_main(vec3 position, vec3 direction, float dither) {
	vec3 viewDirection = direction;

	position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
	direction = mat3(gbufferModelViewInverse) * direction;
	vec3 startPosition = position + cameraPosition;
	vec3 shadowDirection = mat3(gbufferModelViewInverse) * shadowLightVector;

	mat2x3 clouds = mat2x3(vec3(0.0), vec3(1.0));
	float layerDistancePrevious;
	float layerDistance;
	for (int i = 0; i < clouds_layers.length(); i++) {
		#ifndef CLOUDS_LOWER_LAYER
		if (i == 1) break;
		#endif

		// Calculate current cloud layer
		mat2x3 layer = clouds_layer(startPosition, direction, shadowDirection, dither, layerDistance, clouds_layers[i]);

		// Fog between current and previous layer
		if (i > 0) {
			float atmosphereDist = abs(layerDistance - layerDistancePrevious);
			vec2 atmosphereOD = scaleHeights * (1.0 - exp(atmosphereDist * direction.y * -inverseScaleHeights)) / direction.y;
			vec2 atmospherePhase = vec2(sky_rayleighPhase(dot(viewDirection, shadowLightVector)),  sky_miePhase(dot(viewDirection, shadowLightVector), 0.8));

			vec3 atmosphereTransmittance = exp(-transmittanceCoefficients * atmosphereOD);
			vec3 transmittedScattering = (1.0 - atmosphereTransmittance) / (transmittanceCoefficients[0] + transmittanceCoefficients[1]); // this is definitely not correct but it works
			clouds[0] *= atmosphereTransmittance;
			clouds[0] += shadowLightColor * (scatteringCoefficients * atmospherePhase) * transmittedScattering * (1.0 - clouds[1]);
		}

		// Apply the layer to the full clouds
		clouds[1] *= layer[1];
		clouds[0] *= layer[1];
		clouds[0] += layer[0] * 1.5; // *2.0 to make clouds brighter, looks better but is unrealistic

		layerDistancePrevious = layerDistance;
	}

	// fog up to final layer
	vec2 atmosphereOD = scaleHeights * (1.0 - exp(layerDistance * direction.y * -inverseScaleHeights)) / direction.y;
	vec2 atmospherePhase = vec2(sky_rayleighPhase(dot(viewDirection, shadowLightVector)),  sky_miePhase(dot(viewDirection, shadowLightVector), 0.8));

	vec3 atmosphereTransmittance = exp(-transmittanceCoefficients * atmosphereOD);
	vec3 transmittedScattering = (1.0 - atmosphereTransmittance) / (transmittanceCoefficients[0] + transmittanceCoefficients[1]); // again, this is definitely not correct but it works
	clouds[0] *= atmosphereTransmittance;
	clouds[0] += shadowLightColor * (scatteringCoefficients * atmospherePhase) * transmittedScattering * (1.0 - clouds[1]);

	return clouds;
}

vec3 clouds_main(vec3 background, vec3 position, vec3 direction, float dither) {
	mat2x3 clouds = clouds_main(position, direction, dither);
	return background * clouds[1] + clouds[0];
}
