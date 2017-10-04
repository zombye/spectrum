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

const float planetRadius     = 6731e3;
const float atmosphereHeight =  100e3;
const float atmosphereRadius = planetRadius + atmosphereHeight;

const vec2 scaleHeights = vec2(8e3, 1.2e3);

const vec2  inverseScaleHeights     = 1.0 / scaleHeights;
const vec2  scaledPlanetRadius      = planetRadius * inverseScaleHeights;
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

#ifdef PHYSICAL_ATMOSPHERE
vec3 sky_atmosphere(vec3 background, vec3 viewVector) {
	const float iSteps = 50.0;
	const float jSteps = 3.0;
	
	vec3 viewPosition = upVector * (planetRadius + cameraPosition.y - 63.0);

	float iStepSize  = dot(viewPosition, viewVector);
	      iStepSize  = sqrt((iStepSize * iStepSize) + atmosphereRadiusSquared - dot(viewPosition, viewPosition)) - iStepSize;
	      iStepSize /= iSteps;
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

		{ // Sun
			float jStepSize  = dot(iPosition, sunVector);
			      jStepSize  = sqrt((jStepSize * jStepSize) + atmosphereRadiusSquared - dot(iPosition, iPosition)) - jStepSize;
			      jStepSize /= jSteps;
			vec3  jIncrement = sunVector * jStepSize;
			vec3  jPosition  = jIncrement * 0.5 + iPosition;

			vec2 jOpticalDepth = vec2(0.0);
			for (float j = 0.0; j < jSteps; j++, jPosition += jIncrement) {
				jOpticalDepth -= exp(length(jPosition) * -inverseScaleHeights + scaledPlanetRadius);
			}
			jOpticalDepth = jOpticalDepth * jStepSize + iOpticalDepth;

			scatteringSun += (scatteringScale * sunPhase) * exp(transmittanceCoefficients * jOpticalDepth);
		}

		{ // Moon
			float jStepSize  = dot(iPosition, moonVector);
			      jStepSize  = sqrt((jStepSize * jStepSize) + atmosphereRadiusSquared - dot(iPosition, iPosition)) - jStepSize;
			      jStepSize /= jSteps;
			vec3  jIncrement = moonVector * jStepSize;
			vec3  jPosition  = jIncrement * 0.5 + iPosition;

			vec2 jOpticalDepth = vec2(0.0);
			for (float j = 0.0; j < jSteps; j++, jPosition += jIncrement) {
				jOpticalDepth -= exp(length(jPosition) * -inverseScaleHeights + scaledPlanetRadius);
			}
			jOpticalDepth = jOpticalDepth * jStepSize + iOpticalDepth;

			scatteringMoon += (scatteringScale * moonPhase) * exp(transmittanceCoefficients * jOpticalDepth);
		}
	}

	scatteringSun  *= sunIlluminance;
	scatteringMoon *= moonIlluminance;

	vec3 scattering = scatteringSun + scatteringMoon;
	vec3 transmittance = exp(transmittanceCoefficients * iOpticalDepth);

	return background * transmittance + scattering;
}
#else
vec2 sky_opticalDepth(vec3 position, vec3 dir) {
	return 1.0 / (max(dot(dir, upVector), 0.0001) * inverseScaleHeights);

	const float steps = 16.0;

	float stepSize  = dot(position, dir);
	      stepSize  = sqrt((stepSize * stepSize) + atmosphereRadiusSquared - dot(position, position)) - stepSize;
	      stepSize /= steps;
	vec3  increment = dir * stepSize;

	vec2 od = vec2(0.0);
	for (float i = 0.0; i < steps; i++, position += increment) {
		od += exp(length(position) * -inverseScaleHeights + scaledPlanetRadius);
	}

	return od * stepSize;
}

vec3 sky_atmosphere(vec3 bg, vec3 viewVector) {
	vec3 viewPosition = upVector * planetRadius;

	vec2 sunOD = sky_opticalDepth(viewPosition, sunVector);
	vec3 sunTransmittance = max0(exp(scatteringCoefficients * -sunOD));

	vec2 od = sky_opticalDepth(viewPosition, viewVector);

	float rayleighPhase = sky_rayleighPhase(dot(viewVector, sunVector));
	float miePhase = sky_miePhase(dot(viewVector, sunVector), 0.8);

	vec3 rlgs  = rayleighCoeff * rayleighPhase * transmittedScatteringIntegral(od.x, transmittanceCoefficients[0]);
	     rlgs *= mix(sunTransmittance.ggg, sunTransmittance, sunTransmittance.g); // unrealistic but it works
	vec3 mies  = mieCoeff * miePhase * transmittedScatteringIntegral(od.y, transmittanceCoefficients[1]);
	     mies *= sqrt(sunTransmittance); // also unrealistic, but it works
	vec3 scattering = rlgs + mies;

	vec3 transmittance = exp(transmittanceCoefficients * -od);

	return bg * transmittance + scattering * sunIlluminance;
}
#endif

vec3 sky_sunSpot(vec3 bg, vec3 viewVector) {
	return dot(viewVector, sunVector) < cos(sunAngularRadius) ? bg : sunLuminance;
}

vec3 sky_render(vec3 bg, vec3 viewVector) {
	bg = sky_sunSpot(bg, viewVector);
	bg = sky_atmosphere(bg, viewVector);
	return bg;
}