#define VOLUMETRICCLOUDS_SAMPLES 7 // [0 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]

#define VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT   1 // Strongly recommended to use at least one sample.
#define VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT 0

#define VOLUMETRICCLOUDS_VISIBILITY_RANGE_DIRECT   750.0
#define VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT 375.0

#define VOLUMETRICCLOUDS_ALTITUDE_MIN  500.0
#define VOLUMETRICCLOUDS_ALTITUDE_MAX 2000.0

#define VOLUMETRICCLOUDS_COVERAGE 0.37

//--// Constants

const float volumetricClouds_coeff  = 0.05; // range for cumulus is approximately 0.05-0.12

//--//

struct volumetricClouds_noiseLayer {
	vec3  mul;
	vec3  add;
	float weight;
};

float volumetricClouds_density(vec3 position) {
	const volumetricClouds_noiseLayer[6] layer = volumetricClouds_noiseLayer[6](
		volumetricClouds_noiseLayer(vec3(0.0005, 0.0005, 0.0005), vec3(0.003, 0.000, 0.003), 1.00000 / 1.96875),
		volumetricClouds_noiseLayer(vec3(0.0010, 0.0010, 0.0010), vec3(0.006, 0.000, 0.006), 0.50000 / 1.96875),
		volumetricClouds_noiseLayer(vec3(0.0030, 0.0030, 0.0030), vec3(0.030, 0.000, 0.030), 0.25000 / 1.96875),
		volumetricClouds_noiseLayer(vec3(0.0090, 0.0090, 0.0090), vec3(0.075, 0.000, 0.075), 0.12500 / 1.96875),
		volumetricClouds_noiseLayer(vec3(0.0270, 0.0270, 0.0270), vec3(0.375, 0.000, 0.375), 0.06250 / 1.96875),
		volumetricClouds_noiseLayer(vec3(0.0810, 0.0810, 0.0810), vec3(0.875, 0.000, 0.875), 0.03125 / 1.96875)
	);

	float density = get3DNoise(position * layer[0].mul + layer[0].add * frameTimeCounter) * layer[0].weight;
	for (int i = 1; i < layer.length(); i++) {
		density += get3DNoise(position * layer[i].mul + layer[i].add * frameTimeCounter) * layer[i].weight;
	}

	float falloff = clamp01((position.y - VOLUMETRICCLOUDS_ALTITUDE_MIN) / (VOLUMETRICCLOUDS_ALTITUDE_MAX - VOLUMETRICCLOUDS_ALTITUDE_MIN));
	      falloff = 6.75 * falloff * pow2(1.0 - falloff);
	density *= falloff * VOLUMETRICCLOUDS_COVERAGE + (1.0 - VOLUMETRICCLOUDS_COVERAGE);

	float coverage       = mix(VOLUMETRICCLOUDS_COVERAGE, 1.4, rainStrength);
	float densityFactor  = 1.0 / coverage;
	float coverageFactor = 1.0 - densityFactor;
	density  = clamp01(density * densityFactor + coverageFactor);
	density *= density * (-2.0 * density + 3.0);

	return density;
}

float volumetricClouds_shadow(vec3 position) {
	#if VOLUMETRICCLOUDS_SAMPLES == 0
	return mix(0.0, 1.0, pow3(1.0 - rainStrength));
	#endif

	vec3 worldStart = position + cameraPosition;
	vec3 direction  = mat3(gbufferModelViewInverse) * shadowLightVector;

	// .x = start, .y = end
	vec2 distances = vec2(VOLUMETRICCLOUDS_ALTITUDE_MIN, VOLUMETRICCLOUDS_ALTITUDE_MAX); // top of clouds is y by default
	distances = (distances - worldStart.y) / direction.y;                                // get distance to the upper and lower bounds
	if (distances.y < distances.x) distances = distances.yx;                             // y less than x? we're looking downwards, so swap them
	distances.x = max(distances.x, 0.0);                                                 // start can never be closer than 0
	if (distances.y < distances.x) return 1.0;                                           // y still less than x? no clouds visible then

	const float samples = 10.0;
	float stepSize = (distances.y - distances.x) / samples;

	vec3 increment = direction * stepSize;
	position = increment * 0.5 + (direction * distances.x + worldStart);

	float od = 0.0;
	for (int i = 0; i < samples; i++, position += increment) {
		od -= volumetricClouds_density(position);
	}
	return exp(volumetricClouds_coeff * stepSize * od);
}

#if PROGRAM != PROGRAM_DEFERRED
float volumetricClouds_phase(float cosTheta) {
	const vec2 g    = vec2(0.25, -0.15);
	const vec2 gm2  = 2.0 * g;
	const vec2 gg   = g * g;
	const vec2 gga1 = 1.0 + gg;
	const vec2 p1   = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));

	vec2 res = p1 * (cosTheta * cosTheta + 1.0) * pow(gga1 - gm2 * cosTheta, vec2(-1.5));

	return dot(res, vec2(0.4)) + 0.2;
}

float volumetricClouds_odDirection(vec3 position, vec3 direction, float startDensity, const float range, const float samples) {
	const float stepSize = range / (samples + 0.5);

	direction *= stepSize;
	position += direction * 0.75;

	float od = -0.5 * startDensity;
	for (float i = 0.0; i < samples; i++, position += direction) {
		od -= volumetricClouds_density(position);
	}
	return stepSize * od;
}

vec4 volumetricClouds_calculate(vec3 startPosition, vec3 endPosition, vec3 viewDirection, bool sky, float dither) {
	#if VOLUMETRICCLOUDS_SAMPLES == 0
	return vec4(0.0, 0.0, 0.0, 1.0);
	#endif

	// world space ray start and direction
	vec3 worldStart = mat3(gbufferModelViewInverse) * startPosition + gbufferModelViewInverse[3].xyz + cameraPosition;
	vec3 direction  = mat3(gbufferModelViewInverse) * viewDirection;

	// distance to start and end of cloud layer - .x = start, .y = end
	vec2 distances = vec2(VOLUMETRICCLOUDS_ALTITUDE_MIN, VOLUMETRICCLOUDS_ALTITUDE_MAX); // top of clouds is y by default
	distances = (distances - worldStart.y) / direction.y;                                // get distance to the upper and lower bounds
	if (distances.y < distances.x) distances = distances.yx;                             // y less than x? we're looking downwards, so swap them
	distances.x = max(distances.x, 0.0);                                                 // start can never be closer than 0
	if (!sky) distances.y = min(distances.y, distance(startPosition, endPosition));      // end can never be closer than the background
	if (distances.y < distances.x) return vec4(0.0, 0.0, 0.0, 1.0);                      // y still less than x? no clouds visible then

	// increse step count towords the horizon, set step size
	float samples = floor(VOLUMETRICCLOUDS_SAMPLES * min((distances.y - distances.x) / (VOLUMETRICCLOUDS_ALTITUDE_MAX - VOLUMETRICCLOUDS_ALTITUDE_MIN), 10.0));
	float stepSize = (distances.y - distances.x) / samples;

	// set increment and initialize position
	vec3 increment = direction * stepSize;
	vec3 position = increment * dither + (direction * distances.x + worldStart);

	// directions for each light source
	      vec3 shadowDirection  = mat3(gbufferModelViewInverse) * shadowLightVector;
	const vec3 skyDirection     = vec3(0.0, 1.0, 0.0);
	const vec3 bouncedDirection = vec3(0.0, -1.0, 0.0);

	// multipliers for each light source
	const vec3 bouncedLightColor = vec3(0.31, 0.34, 0.31); // wish I had an average sunlit color for 1-2 km around the player, a grey with subtle green tint looks natural enough so that will have to do

	vec3 directMul = shadowLightColor * volumetricClouds_phase(dot(viewDirection, shadowLightVector));
	vec3 indirectScatterMul = skyLightColor * 0.5;
	vec3 indirectBouncedMul = dot(shadowLightVector, upVector) * bouncedLightColor * shadowLightColor * 0.5 / pi;

	// transmitted scattering integral constants
	const float tsi_a = -volumetricClouds_coeff / log(2.0);
	const float tsi_b = -1.0 / volumetricClouds_coeff;
	const float tsi_c =  1.0 / volumetricClouds_coeff;

	// multiple scattering approximation constants
	const int   msa_octaves = 2;
	const float msa_a = 0.618; // msa_a <= msa_b
	const float msa_b = 0.618;
	const float msa_c = 0.5; // TODO: Use this

	// loop
	vec4 clouds = vec4(vec3(0.0), 1.0);
	vec2 distanceAverage = vec2((distances.x + distances.y) * 0.5, 1.0) * 0.0001;
	for (int i = 0; i < samples; i++, position += increment) {
		// get density at current position
		float density = volumetricClouds_density(position);

		if (density == 0.0) continue;

		vec3 visOD = vec3( // find optical depths towards the sun, upwards, and downwards
			volumetricClouds_odDirection(position, shadowDirection,  density, VOLUMETRICCLOUDS_VISIBILITY_RANGE_DIRECT,   VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT),
			volumetricClouds_odDirection(position, skyDirection,     density, VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT, VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT),
			volumetricClouds_odDirection(position, bouncedDirection, density, VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT, VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT)
		);

		float od = density * stepSize;

		// approximate multiple scattering
		vec3 sampleScattering = vec3(0.0);
		for (int j = 1; j <= msa_octaves; j++) {
			vec2 coeffs = volumetricClouds_coeff * pow(vec2(msa_a, msa_b), vec2(j));

			vec3 msaLight = exp(coeffs.y * visOD);
			msaLight = msaLight.x * directMul + msaLight.y * indirectScatterMul + msaLight.z * indirectBouncedMul;

			sampleScattering += coeffs.x * msaLight;
		}

		// add step to result, integrate transmitted scattering
		float transmittanceStep     = exp2(tsi_a * od);
		float transmittedScattering = (transmittanceStep * tsi_b + tsi_c) * clouds.a;
		clouds.rgb += sampleScattering * transmittedScattering;
		clouds.a   *= transmittanceStep;

		// add to distance average weighted based on importance
		distanceAverage += vec2(distance(position, worldStart), 1.0) * transmittedScattering;
	}

	// fade out distant clouds based on average weighted distance
	clouds = mix(vec4(vec3(0.0), 1.0), clouds, exp(-2e-5 * distanceAverage.x / distanceAverage.y));

	return clouds;
}
#endif
