#define VOLUMETRICCLOUDS_SAMPLES 7 // [0 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]

#define VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT   1 // Strongly recommended to use at least one sample.
#define VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT 0

#define VOLUMETRICCLOUDS_VISIBILITY_RANGE_DIRECT   750.0
#define VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT 375.0

#define VOLUMETRICCLOUDS_ALTITUDE_MIN  500.0
#define VOLUMETRICCLOUDS_ALTITUDE_MAX 2000.0

#define VOLUMETRICCLOUDS_COVERAGE 0.43

//--// Constants

const float volumetricClouds_coeffScatter  = 0.050;
const float volumetricClouds_coeffTransmit = volumetricClouds_coeffScatter * 1.11; // range for cumulus is approximately 0.05-0.12

const float volumetricClouds_visibilityMult = 0.5; // unrealisic, only exists because there isn't a multiple scattering approximation

const vec3 volumetricClouds_bouncedLightColor = vec3(0.31, 0.34, 0.31); // wish I had an average sunlit color for 1-2 km around the player, a grey with subtle green tint looks natural enough so that will have to do

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
	const float coverageFactor = 1.0 - densityFactor;
	density  = clamp01(density * densityFactor + coverageFactor);
	density *= density * (-2.0 * density + 3.0);

	return density;
}

float volumetricClouds_visibility(vec3 position, vec3 direction, float odAtStart, const float range, const float samples, const bool hq) {
	const float stepSize = range / (samples + 0.5);

	direction *= stepSize;
	position += direction * 0.75;

	float od = -0.5 * odAtStart;
	for (float i = 0.0; i < samples; i++, position += direction) {
		od -= volumetricClouds_density(position, hq);
	}
	return exp(volumetricClouds_coeffTransmit * stepSize * od * volumetricClouds_visibilityMult);
}
/*
vec3 volumetricClouds_basicIndirect(vec3 position) {
	vec3 skyLighting = skyLightColor * 0.5;
	vec3 bouncedLighting = volumetricClouds_bouncedLightColor * dot(shadowLightVector, upVector) * shadowLightColor * 0.5 / pi;

	float fade = (position.y - VOLUMETRICCLOUDS_ALTITUDE_MIN) / (VOLUMETRICCLOUDS_ALTITUDE_MAX - VOLUMETRICCLOUDS_ALTITUDE_MIN);
	return mix(bouncedLighting, skyLighting, fade);
}
*/

float volumetricClouds_shadow(vec3 position) {
	#if VOLUMETRICCLOUDS_SAMPLES == 0
	return 1.0;
	#endif

	const float samples = 10.0;

	vec3 worldStart = position + cameraPosition;
	vec3 direction  = mat3(gbufferModelViewInverse) * shadowLightVector;

	// .x = start, .y = end
	vec2 distances = vec2(VOLUMETRICCLOUDS_ALTITUDE_MIN, VOLUMETRICCLOUDS_ALTITUDE_MAX); // top of clouds is y by default
	distances = (distances - worldStart.y) / direction.y;                                // get distance to the upper and lower bounds
	if (distances.y < distances.x) distances = distances.yx;                             // y less than x? we're looking downwards, so swap them
	distances.x = max(distances.x, 0.0);                                                 // start can never be closer than 0
	if (distances.y < distances.x) return 1.0;                                           // y still less than x? no clouds visible then

	float stepSize = (distances.y - distances.x) / samples;

	vec3 increment = direction * stepSize;
	position = increment * bayer8(gl_FragCoord.st) + (direction * distances.x + worldStart);

	float od = 0.0;
	for (int i = 0; i < samples; i++, position += increment) {
		od -= volumetricClouds_density(position, true);
	}
	return exp(volumetricClouds_coeffTransmit * stepSize * od);
}

vec4 volumetricClouds_calculate(vec3 startPosition, vec3 endPosition, vec3 viewDirection, bool sky) {
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
	float samples = floor(VOLUMETRICCLOUDS_SAMPLES / max(abs(direction.y), 0.1));
	float stepSize = (distances.y - distances.x) / samples;

	// set increment and initialize position
	vec3 increment = direction * stepSize;
	vec3 position = increment * bayer8(gl_FragCoord.st) + (direction * distances.x + worldStart);

	// directions for each light source
	      vec3 shadowDirection  = mat3(gbufferModelViewInverse) * shadowLightVector;
	const vec3 skyDirection     = vec3(0.0, 1.0, 0.0);
	const vec3 bouncedDirection = vec3(0.0, -1.0, 0.0);

	// multipliers for each light source
	vec3 directMul = shadowLightColor * volumetricClouds_phase(dot(viewDirection, shadowLightVector));
	vec3 indirectScatterMul = skyLightColor * 0.5;
	vec3 indirectBouncedMul = dot(shadowLightVector, upVector) * volumetricClouds_bouncedLightColor * shadowLightColor * 0.5 / pi;

	// transmitted scattering integral constants
	const float a = -volumetricClouds_coeffTransmit / log(2.0);
	const float b = -1.0 / volumetricClouds_coeffTransmit;
	const float c =  1.0 / volumetricClouds_coeffTransmit;

	// loop
	vec4 clouds = vec4(vec3(0.0), 1.0);
	for (int i = 0; i < samples; i++, position += increment) {
		// get density at current position
		float od = volumetricClouds_density(position, true);

		if (od == 0.0) continue;

		vec3 // density for step is input to these, essentially gives half a visibility step for free
		sampleLighting  = volumetricClouds_visibility(position, shadowDirection,  od, VOLUMETRICCLOUDS_VISIBILITY_RANGE_DIRECT,   VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_DIRECT,   true) * directMul;
		sampleLighting += volumetricClouds_visibility(position, skyDirection,     od, VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT, VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT, true) * indirectScatterMul;
		sampleLighting += volumetricClouds_visibility(position, bouncedDirection, od, VOLUMETRICCLOUDS_VISIBILITY_RANGE_INDIRECT, VOLUMETRICCLOUDS_VISIBILITY_SAMPLES_INDIRECT, true) * indirectBouncedMul;

		// now go from density to optical depth
		od *= stepSize;

		// add step to result, integrate transmitted scattering
		float transmittanceStep = exp2(a * od);
		clouds.rgb += sampleLighting * (transmittanceStep * b + c) * clouds.a;
		clouds.a   *= transmittanceStep;
	} clouds.rgb *= volumetricClouds_coeffScatter;

	// fade out towards horizon
	clouds = mix(vec4(vec3(0.0), 1.0), clouds, smoothstep(0.0, 0.1, abs(dot(viewDirection, upVector))));

	return clouds;
}
