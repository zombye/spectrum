#define VOLUMETRICCLOUDS
#define VOLUMETRICCLOUDS_CQR // Significantly improves quality of distant clouds. Can be up to 5x slower!

// Performance
#define VOLUMETRICCLOUDS_QUALITY                    10 // [8 10 12 14 16]
#define VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT   1 // Using more than one sample has very little impact on actual quality
#define VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT 1 // Using more than one sample has very little impact on actual quality

#define VOLUMETRICCLOUDS_VISIBILITY_RANGE_DIRECT   500.0
#define VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT 500.0

// Visual
#define VOLUMETRICCLOUDS_ALTITUDE_MIN  500.0
#define VOLUMETRICCLOUDS_ALTITUDE_MAX 2000.0

#define VOLUMETRICCLOUDS_COVERAGE 0.43

//--// Constants

const float volumetricClouds_coeffScatter  = 0.02;
const float volumetricClouds_coeffTransmit = volumetricClouds_coeffScatter * 1.11;

//--//

float volumetricClouds_phase(float cosTheta) {
	const vec2 g    = vec2(0.25, -0.15);
	const vec2 gm2  = 2.0 * g;
	const vec2 gg   = g * g;
	const vec2 gga1 = 1.0 + gg;
	const vec2 p1   = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));

	vec2 res = p1 * (cosTheta * cosTheta + 1.0) * pow(gga1 - gm2 * cosTheta, vec2(-1.5));

	return dot(res, vec2(0.4)) + 0.2;
}

//--//

struct volumetricClouds_noiseLayer {
	vec3  mul;
	vec3  add;
	float weight;
};

float volumetricClouds_density(vec3 position, const bool hq) {
	const volumetricClouds_noiseLayer[5] layer = volumetricClouds_noiseLayer[5](
		volumetricClouds_noiseLayer(vec3(0.001, 0.001, 0.001), vec3(0.01, 0.00, 0.01), 1.0000 / 1.6496),
		volumetricClouds_noiseLayer(vec3(0.003, 0.003, 0.003), vec3(0.05, 0.00, 0.05), 0.4000 / 1.6496),
		volumetricClouds_noiseLayer(vec3(0.009, 0.009, 0.009), vec3(0.25, 0.00, 0.25), 0.1600 / 1.6496),
		volumetricClouds_noiseLayer(vec3(0.027, 0.027, 0.027), vec3(1.25, 0.00, 1.25), 0.0640 / 1.6496),
		volumetricClouds_noiseLayer(vec3(0.081, 0.081, 0.081), vec3(6.28, 0.00, 6.28), 0.0256 / 1.6496)
	);

	//--//

	float density = get3DNoise(position * layer[0].mul + layer[0].add * frameTimeCounter) * layer[0].weight;
	for (int i = 1; i < (hq ? 5 : 3); i++) {
		density += get3DNoise(position * layer[i].mul + layer[i].add * frameTimeCounter) * layer[i].weight;
	}

	float falloff = clamp01((position.y - VOLUMETRICCLOUDS_ALTITUDE_MIN) / (VOLUMETRICCLOUDS_ALTITUDE_MAX - VOLUMETRICCLOUDS_ALTITUDE_MIN));
	      falloff = 6.75 * falloff * pow2(1.0 - falloff);
	density *= falloff * VOLUMETRICCLOUDS_COVERAGE + (1.0 - VOLUMETRICCLOUDS_COVERAGE);

	const float densityFactor  = 1.0 / VOLUMETRICCLOUDS_COVERAGE;
	const float coverageFactor = VOLUMETRICCLOUDS_COVERAGE * densityFactor - densityFactor;
	density  = clamp01(density * densityFactor + coverageFactor);
	density *= density * (-2.0 * density + 3.0);

	return density;
}

float volumetricClouds_sunVisibility(vec3 position, float odStartPos) {
	const float stepSize = VOLUMETRICCLOUDS_VISIBILITY_RANGE_DIRECT / (VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT + 0.5);

	vec3 direction = mat3(modelViewInverse) * shadowLightVector;

	vec3 increment = direction * stepSize;// / direction.y;
	position += increment * 0.75;

	float od = -0.5 * odStartPos;
	for (float i = 0.0; i < VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT; i++, position += increment) {
		od -= volumetricClouds_density(position, true);
	}
	return exp(volumetricClouds_coeffTransmit * stepSize * od);
}
float volumetricClouds_skyVisibility(vec3 position, float odStartPos) {
	const float stepSize = VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT / (VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT + 0.5);

	const vec3 increment = vec3(0.0, 1.0, 0.0) * stepSize;
	position += increment * 0.75;

	float od = -0.5 * odStartPos;
	for (float i = 0.0; i < VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT; i++, position += increment) {
		od -= volumetricClouds_density(position, true);
	}
	return exp(volumetricClouds_coeffTransmit * stepSize * od);
}

vec4 volumetricClouds_calculate(vec3 startPosition, vec3 endPosition, vec3 viewDirection, bool sky) {
	vec3 worldStart = mat3(modelViewInverse) * startPosition + modelViewInverse[3].xyz + cameraPosition;
	vec3 direction  = mat3(modelViewInverse) * viewDirection;

	#ifdef VOLUMETRICCLOUDS_CQR
	float samples = floor(VOLUMETRICCLOUDS_QUALITY / max(abs(direction.y), 0.2));
	#else
	const float samples = VOLUMETRICCLOUDS_QUALITY;
	#endif

	// .x = start, .y = end
	vec2 distances = vec2(VOLUMETRICCLOUDS_ALTITUDE_MIN, VOLUMETRICCLOUDS_ALTITUDE_MAX); // top of clouds is y by default
	distances = (distances - worldStart.y) / direction.y;                                // get distance to the upper and lower bounds
	if (distances.y < distances.x) distances = distances.yx;                             // y less than x? we're looking downwards, so swap them
	distances.x = max(distances.x, 0.0);                                                 // start can never be closer than 0
	if (!sky) distances.y = min(distances.y, distance(startPosition, endPosition));      // end can never be closer than the background
	if (distances.y < distances.x) return vec4(0.0, 0.0, 0.0, 1.0);                      // y still less than x? no clouds visible then

	float stepSize = (distances.y - distances.x) / samples;

	float phase = volumetricClouds_phase(dot(viewDirection, shadowLightVector));

	vec3 increment = direction * stepSize;
	vec3 position = increment * bayer8(gl_FragCoord.st) + (direction * distances.x + worldStart);

	vec4 clouds = vec4(vec3(0.0), 1.0);
	for (int i = 0; i < samples; i++, position += increment) {
		float od = volumetricClouds_density(position, true);
		vec3 sampleLighting  = volumetricClouds_sunVisibility(position, od) * shadowLightColor * phase;
		     sampleLighting += volumetricClouds_skyVisibility(position, od) * skyLightColor    * 0.5;
		od *= stepSize;

		clouds.rgb += sampleLighting * transmittedScatteringIntegral(od, volumetricClouds_coeffTransmit) * clouds.a;
		clouds.a   *= exp(-volumetricClouds_coeffTransmit * od);
	}
	clouds.rgb *= volumetricClouds_coeffScatter;

	clouds = mix(vec4(vec3(0.0), 1.0), clouds, smoothstep(0.0, 0.1, abs(dot(viewDirection, upVector))));

	return clouds;
}