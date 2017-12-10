#define CREPUSCULAR_RAYS 2 // [0 1 2]
//#define CREPUSCULAR_RAYS_CAUSTICS

//--//

vec3 fog(vec3 background, vec3 startPosition, vec3 endPosition, vec2 lightmap, float dither, bool sky) {
	vec3 direction = endPosition - startPosition;
	if (sky) { direction = normalize(direction) * 2000.0; }

	float stepSize = length(direction);
	if (stepSize == 0.0) return background; // Prevent divide by 0
	direction /= stepSize;

	#if CREPUSCULAR_RAYS == 2
	vec3 skylightBrightness = skyLightColor * max(eyeBrightness.y / 240.0, lightmap.y);

	const float steps = 6.0;

	stepSize /= steps;

	vec4 phase = vec4(dot(direction, shadowLightVector));
	     phase = vec4(sky_rayleighPhase(phase.x), sky_miePhase(phase.x, 0.8), sky_miePhase(phase.x, 0.3), 0.5);

	vec3 worldPos = transformPosition(startPosition, gbufferModelViewInverse) + cameraPosition;
	vec3 worldIncrement = mat3(gbufferModelViewInverse) * direction * stepSize;
	vec3 shadowPos = transformPosition(transformPosition(worldPos - cameraPosition, shadowModelView), projectionShadow);
	vec3 shadowIncrement = mat3(projectionShadow) * mat3(shadowModelView) * worldIncrement;

	worldPos  += worldIncrement  * dither;
	shadowPos += shadowIncrement * dither;

	float mistFactor = pow5(dot(sunVector, gbufferModelView[0].xyz) * 0.5 + 0.5);
	float mistScaleHeight = mix(500.0, mix(200.0, 8.0, mistFactor), pow3(1.0 - rainStrength));
	float mistDensity = mix(0.003, 0.02 / mistScaleHeight, pow3(1.0 - rainStrength));
	vec3 ish = vec3(inverseScaleHeights, 1.0 / mistScaleHeight);
	mat3 transmittanceMatrix = mat3(transmittanceCoefficients[0], transmittanceCoefficients[1], vec3(1.0));

	vec3 transmittance = vec3(1.0);
	vec3 scattering    = vec3(0.0);

	for (float i = 0.0; i < steps; i++, worldPos += worldIncrement, shadowPos += shadowIncrement) {
		vec3 opticalDepth    = vec3(worldPos.y - 63.0);
		     opticalDepth.z  = max(opticalDepth.z, 0.0);
		     opticalDepth    = exp(-ish * opticalDepth);
		     opticalDepth   *= stepSize;
		     opticalDepth.z *= mistDensity;

		mat3 scatterCoeffs = mat3(
			scatteringCoefficients[0] * transmittedScatteringIntegral(opticalDepth.x, transmittanceCoefficients[0]),
			scatteringCoefficients[1] * transmittedScatteringIntegral(opticalDepth.y, transmittanceCoefficients[1]),
			vec3(1.0) * transmittedScatteringIntegral(opticalDepth.z, vec3(1.0))
		);

		vec3 shadowCoord = shadows_distortShadowSpace(shadowPos) * 0.5 + 0.5;
		vec3 sunlight  = (scatterCoeffs * phase.xyz) * shadowLightColor * textureShadow(shadowtex0, shadowCoord);
		     sunlight *= texture2D(gaux2, shadowCoord.st).a;
		vec3 skylight  = (scatterCoeffs * phase.www) * skylightBrightness;

		scattering += (sunlight + skylight) * transmittance;
		transmittance *= exp(-transmittanceMatrix * opticalDepth);
	}
	#else
	float phase = sky_rayleighPhase(dot(direction, shadowLightVector));

	vec3 lighting = (shadowLightColor * pow3(1.0 - rainStrength) + skyLightColor) * max(eyeBrightness.y / 240.0, lightmap.y);

	vec3 transmittance = exp(-(transmittanceCoefficients[0] + rainStrength * 0.003) * stepSize);
	vec3 scattering    = lighting * (scatteringCoefficients[0] + rainStrength * 0.003) * phase * transmittedScatteringIntegral(stepSize, transmittanceCoefficients[0]);
	#endif

	return background * transmittance + scattering;
}

#if PROGRAM != PROGRAM_WATER
vec3 fakeCrepuscularRays(vec3 viewVector, float dither) {
	#if CREPUSCULAR_RAYS != 1
	return vec3(0.0);
	#endif

	float mistFactor = pow5(dot(sunVector, gbufferModelView[0].xyz) * 0.5 + 0.5);
	float mistScaleHeight = mix(200.0, 8.0, mistFactor);
	float mistDensity = mix(0.0, 0.02 / mistScaleHeight, pow3(1.0 - rainStrength));

	const float steps = 6.0;

	vec4 lightPosition = projection * vec4(shadowLightVector, 1.0);
	lightPosition = (lightPosition / lightPosition.w) * 0.5 + 0.5;

	vec2 increment = (lightPosition.xy - screenCoord) / steps;
	vec2 sampleCoord = increment * dither + screenCoord;

	float result = 0.0;
	for (float i = 0.0; i < steps && floor(sampleCoord) == vec2(0.0); i++, sampleCoord += increment) {
		result += step(1.0, texture2D(depthtex1, sampleCoord).r);
	}

	float directionalMult = clamp01(dot(viewVector, shadowLightVector)); directionalMult *= directionalMult;

	return result * directionalMult * 10.0 * mistDensity * shadowLightColor / steps;
}
#endif

vec3 waterFog(vec3 background, vec3 startPosition, vec3 endPosition, float skylight, float dither) {
	skylight = lightmapCurve(skylight, LIGHTMAP_FALLOFF_SKY);

	#if CREPUSCULAR_RAYS == 2
	const float steps = 6.0;

	vec3 increment = (endPosition - startPosition) / steps;

	float stepSize = length(increment);
	vec3 stepIntegral = transmittedScatteringIntegral(stepSize, water_transmittanceCoefficient);

	increment = mat3(projectionShadow) * mat3(shadowModelView) * mat3(gbufferModelViewInverse) * increment;
	vec3 position = transformPosition(transformPosition(transformPosition(startPosition, gbufferModelViewInverse), shadowModelView), projectionShadow);

	position += increment * dither;

	vec3 transmittance = vec3(1.0);
	vec3 scattering    = vec3(0.0);

	for (float i = 0.0; i < steps; i++, position += increment) {
		vec3 shadowCoord = shadows_distortShadowSpace(position) * 0.5 + 0.5;
		vec3 sunlight  = water_scatteringCoefficient * (0.25/pi) * shadowLightColor * textureShadow(shadowtex1, shadowCoord);
		     sunlight *= texture2D(gaux2, shadowCoord.st).a;
		#ifdef CREPUSCULAR_RAYS_CAUSTICS
		#if CAUSTICS_SAMPLES > 0
		if (sunlight != vec3(0.0)) {
			vec3 shadowPosition = transformPosition(position, projectionShadowInverse);
			sunlight *= waterCaustics(transformPosition(shadowPosition, shadowModelViewInverse), shadowPosition, shadowCoord);
		}
		#endif
		#endif
		vec3 skylight  = water_scatteringCoefficient * 0.5 * skyLightColor * skylight;

		scattering    += (sunlight + skylight) * stepIntegral * transmittance;
		transmittance *= exp(-water_transmittanceCoefficient * stepSize);
	}
	#else
	float waterDepth = distance(startPosition, endPosition);

	vec3 transmittance = exp(-water_transmittanceCoefficient * waterDepth);
	vec3 scattering    = ((shadowLightColor * 0.25 / pi * pow3(1.0 - rainStrength)) + (skyLightColor * 0.5)) * skylight * water_scatteringCoefficient * (1.0 - transmittance) / water_transmittanceCoefficient;
	#endif

	return background * transmittance + scattering;
}
