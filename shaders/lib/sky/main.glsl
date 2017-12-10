vec3 sky_atmosphereRainOverlay(vec3 atmosphere) {
	return mix(atmosphere * (-0.98 * rainStrength + 1.0), vec3(0.012, 0.014, 0.02), rainStrength * 0.6);
}

vec2 sky_opticalDepth(vec3 position, vec3 dir, const float steps) {
	float stepSize  = dot(position, dir);
	      stepSize  = sqrt(max0((stepSize * stepSize) + atmosphereRadiusSquared - dot(position, position))) - stepSize;
	      stepSize /= steps;
	vec3  increment = dir * stepSize;
	position += increment * 0.5;

	vec2 od = vec2(0.0);
	for (float i = 0.0; i < steps; i++, position += increment) {
		od += exp(length(position) * -inverseScaleHeights + scaledPlanetRadius);
	}

	return od * stepSize;
}

#if SKY_ATMOSPHERE_MODE == 1
vec3 sky_atmosphere(vec3 background, vec3 viewVector) {
	const float iSteps = 50.0; // Requires a ridiculous amount of steps before the difference is even rarely noticable. It's somewhere beyond 2000, comparing 2000 with 3000 is where it starts to get hard to notice when comparing side-by-side.
	const float jSteps = 3.0;  // Difference is rarely noticable beyond 6 where you only notice it below the horizon and so is not normally visible, and almost imperceptible beyond ~25 where you notice it because of the dithering done in final

	#if STAGE == STAGE_VERTEX
	float dither = 0.5;
	#else
	float dither = bayer8(gl_FragCoord.st);
	#endif

	vec3 viewPosition = upVector * (PLANET_RADIUS + cameraPosition.y - 63.0);

	float iStepSize  = dot(viewPosition, viewVector);
	      iStepSize  = sqrt((iStepSize * iStepSize) + atmosphereRadiusSquared - dot(viewPosition, viewPosition)) - iStepSize;
	      iStepSize /= iSteps;
	      iStepSize *= pow(0.01 * min(dot(viewVector, upVector), 0.0) + 1.0, 900.0); // stop before getting to regions that would have little to no impact on the result
	vec3  iIncrement = viewVector * iStepSize;
	vec3  iPosition  = iIncrement * dither + viewPosition;

	float sunVoL    = dot(viewVector, sunVector);
	float moonVoL   = dot(viewVector, moonVector);
	vec2  sunPhase  = vec2(sky_rayleighPhase(sunVoL),  sky_miePhase(sunVoL, 0.8));
	vec2  moonPhase = vec2(sky_rayleighPhase(moonVoL), sky_miePhase(moonVoL, 0.8));

	vec3 scatteringSun  = vec3(0.0);
	vec3 scatteringMoon = vec3(0.0);
	vec3 transmittance  = vec3(1.0);
	for (float i = 0.0; i < iSteps; i++, iPosition += iIncrement) {
		vec2 odIStep = exp(length(iPosition) * -inverseScaleHeights + scaledPlanetRadius) * iStepSize;

		mat2x3 scatteringScale = mat2x3( // This is wrong, but it's more correct than not having it.
			scatteringCoefficients[0] * transmittedScatteringIntegral(odIStep.x, transmittanceCoefficients[0]),
			scatteringCoefficients[1] * transmittedScatteringIntegral(odIStep.y, transmittanceCoefficients[1])
		);

		scatteringSun  += (scatteringScale * sunPhase)  * exp(transmittanceCoefficients * -sky_opticalDepth(iPosition, sunVector,  jSteps)) * transmittance;
		scatteringMoon += (scatteringScale * moonPhase) * exp(transmittanceCoefficients * -sky_opticalDepth(iPosition, moonVector, jSteps)) * transmittance;
		transmittance  *= exp(transmittanceCoefficients * -odIStep);
	}

	scatteringSun  *= sunIlluminance;
	scatteringMoon *= moonIlluminance;

	vec3 scattering = scatteringSun + scatteringMoon;

	return sky_atmosphereRainOverlay(background * transmittance + scattering);
}
#else
vec2 sky_opticalDepthApprox(vec3 position, vec3 direction) {
	const vec2 sr = (PLANET_RADIUS + scaleHeights) * (PLANET_RADIUS + scaleHeights);
	vec2 od = vec2(dot(position, direction));
	     od = sqrt(od * od + sr - dot(position, position)) - od;
	return od;
}

vec3 sky_atmosphere(vec3 bg, vec3 viewVector) {
	vec3 viewPosition = upVector * PLANET_RADIUS;

	vec2 opticalDepth  = sky_opticalDepthApprox(viewPosition, viewVector);
	vec3 transmittance = exp(transmittanceCoefficients * -opticalDepth);

	vec3 baseRayleigh = rayleighCoeff * transmittedScatteringIntegral(opticalDepth.x, transmittanceCoefficients[0]);
	vec3 baseMie      = mieCoeff      * transmittedScatteringIntegral(opticalDepth.y, transmittanceCoefficients[1]);

	vec3 sunTransmittance  = max0(exp(transmittanceCoefficients * -sky_opticalDepthApprox(viewPosition, sunVector)));
	vec3 sunScattering     = baseRayleigh * sky_rayleighPhase(dot(viewVector, sunVector)) * mix(sunTransmittance.ggg, sunTransmittance, sunTransmittance.g);
	     sunScattering    += baseMie      * sky_miePhase(dot(viewVector, sunVector), 0.8) * sunTransmittance;
	     sunScattering    *= sunIlluminance;

	vec3 moonTransmittance = max0(exp(transmittanceCoefficients * -sky_opticalDepthApprox(viewPosition, moonVector)));
	vec3 moonScattering    = baseRayleigh * sky_rayleighPhase(dot(viewVector, moonVector)) * mix(moonTransmittance.ggg, moonTransmittance, moonTransmittance.g);
	     moonScattering   += baseMie      * sky_miePhase(dot(viewVector, moonVector), 0.8) * moonTransmittance;
	     moonScattering   *= moonIlluminance;

	return sky_atmosphereRainOverlay(bg * transmittance + sunScattering + moonScattering);
}
#endif

vec3 sky_sun(vec3 bg, vec3 viewVector) {
	return mix(bg, sunLuminance, float(dot(viewVector, sunVector) >= cos(sunAngularRadius)) * pow5(1.0 - rainStrength));
}
vec3 sky_moon(vec3 bg, vec3 viewVector) {
	return mix(bg, moonLuminance, float(dot(viewVector, moonVector) >= cos(moonAngularRadius)) * pow5(1.0 - rainStrength));
}

vec3 sky_render(vec3 bg, vec3 viewVector) {
	bg = sky_sun(bg, viewVector);
	bg = sky_moon(bg, viewVector);
	bg = sky_atmosphere(bg, viewVector);
	return bg;
}
