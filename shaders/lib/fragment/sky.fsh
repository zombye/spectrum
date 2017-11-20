/*
	TODO:
	Clean up a bit
	Make non-PBR atmosphere include moon
*/

/*
	Referenced:
	[Elek09] - http://old.cescg.org/CESCG-2009/papers/PragueCUNI-Elek-Oskar09.pdf
*/

// the distance a ray is from a point with the closest approach at distance h and x = 0
// this is effectively the curve that sky_opticalDepth runs along
// Noted here as I think I might need it at some point, like maybe for clouds.
// pDistCurve(x) { h == 0 ? abs(x) : h * sqrt(pow2(x / h) + 1.0); }

//--//

//#define PHYSICAL_ATMOSPHERE // Physically based atmosphere model. Much more realistic, but also much slower.

const float atmosphereHeight = 100e3;
const float atmosphereRadius = PLANET_RADIUS + atmosphereHeight;

const vec2 scaleHeights = vec2(8e3, 1.2e3);

const vec2  inverseScaleHeights     = 1.0 / scaleHeights;
const vec2  scaledPlanetRadius      = PLANET_RADIUS * inverseScaleHeights;
const float atmosphereRadiusSquared = atmosphereRadius * atmosphereRadius;

const vec3 rayleighCoeff = vec3(5.800e-6, 1.350e-5, 3.310e-5);
const vec3 ozoneCoeff    = vec3(3.426e-7, 8.298e-7, 0.356e-7) * 6.0;
const vec3 mieCoeff      = vec3(3e-6);

const mat2x3 scatteringCoefficients    = mat2x3(rayleighCoeff, mieCoeff);
const mat2x3 transmittanceCoefficients = mat2x3(rayleighCoeff + ozoneCoeff, mieCoeff * 1.11);

//--//

float sky_rayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / pi;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}
float sky_miePhase(float cosTheta, float g) {
	float gg = g * g;
	float p1 = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));
	float p2 = (cosTheta * cosTheta + 1.0) * pow(1.0 + gg - 2.0 * g * cosTheta, -1.5);
	return p1 * p2;
}

vec3 sky_atmosphereRainOverlay(vec3 atmosphere) {
	return mix(atmosphere * (-0.98 * rainStrength + 1.0), vec3(0.012, 0.014, 0.02), rainStrength * 0.6);
}

#ifdef PHYSICAL_ATMOSPHERE
vec2 sky_opticalDepth(vec3 position, vec3 dir, const float steps) {
	float stepSize  = dot(position, dir);
	      stepSize  = sqrt((stepSize * stepSize) + atmosphereRadiusSquared - dot(position, position)) - stepSize;
	      stepSize /= steps;
	vec3  increment = dir * stepSize;
	position += increment * 0.5;

	vec2 od = vec2(0.0);
	for (float i = 0.0; i < steps; i++, position += increment) {
		od += exp(length(position) * -inverseScaleHeights + scaledPlanetRadius);
	}

	return od * stepSize;
}

vec3 sky_atmosphere(vec3 background, vec3 viewVector) {
	const float iSteps = 50.0;
	const float jSteps = 3.0;

	vec3 viewPosition = upVector * (PLANET_RADIUS + cameraPosition.y - 63.0);

	float iStepSize  = dot(viewPosition, viewVector);
	      iStepSize  = sqrt((iStepSize * iStepSize) + atmosphereRadiusSquared - dot(viewPosition, viewPosition)) - iStepSize;
	      iStepSize /= iSteps;
	      iStepSize *= pow(0.01 * min(dot(viewVector, upVector), 0.0) + 1.0, 700.0); // stop before getting to regions that would have little to no impact on the result
	vec3  iIncrement = viewVector * iStepSize;
	vec3  iPosition  = iIncrement * bayer8(gl_FragCoord.st) + viewPosition;

	float sunVoL    = dot(viewVector, sunVector);
	float moonVoL   = dot(viewVector, moonVector);
	vec2  sunPhase  = vec2(sky_rayleighPhase(sunVoL),  sky_miePhase(sunVoL, 0.8));
	vec2  moonPhase = vec2(sky_rayleighPhase(moonVoL), sky_miePhase(moonVoL, 0.8));

	vec2 iOpticalDepth  = vec2(0.0);
	vec3 scatteringSun  = vec3(0.0);
	vec3 scatteringMoon = vec3(0.0);

	for (float i = 0.0; i < iSteps; i++, iPosition += iIncrement) {
		vec2 odIStep = exp(length(iPosition) * -inverseScaleHeights + scaledPlanetRadius) * iStepSize;

		iOpticalDepth -= odIStep;

		mat2x3 scatteringScale = mat2x3(
			scatteringCoefficients[0] * transmittedScatteringIntegral(odIStep.x, transmittanceCoefficients[0]),
		 	scatteringCoefficients[1] * transmittedScatteringIntegral(odIStep.y, transmittanceCoefficients[1])
		);

		scatteringSun  += (scatteringScale * sunPhase)  * exp(transmittanceCoefficients * (-sky_opticalDepth(iPosition, sunVector,  jSteps) + iOpticalDepth));
		scatteringMoon += (scatteringScale * moonPhase) * exp(transmittanceCoefficients * (-sky_opticalDepth(iPosition, moonVector, jSteps) + iOpticalDepth));
	}

	scatteringSun  *= sunIlluminance;
	scatteringMoon *= moonIlluminance;

	vec3 scattering = scatteringSun + scatteringMoon;
	vec3 transmittance = exp(transmittanceCoefficients * iOpticalDepth);

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
