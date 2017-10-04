flat varying vec3 shadowLightColor;
flat varying vec3 blockLightColor;
flat varying vec3 skyLightColor;

#define SUN_ANGULAR_DIAMETER  2.510 // [0.536]
#define MOON_ANGULAR_DIAMETER 2.500 // [0.528]

const float sunAngularDiameter = radians(SUN_ANGULAR_DIAMETER);
const float sunAngularRadius   = sunAngularDiameter / 2.0;
const float sunBrightness      = 128e3;
const vec3  sunColor           = vec3(1.0, 0.96, 0.95);
const vec3  sunIlluminance     = sunBrightness * sunColor;
const vec3  sunLuminance       = sunIlluminance / (tau * (1.0 - cos(sunAngularRadius)));

const float moonAngularDiameter = radians(MOON_ANGULAR_DIAMETER);
const float moonAngularRadius   = moonAngularDiameter / 2.0;
const vec3  moonColor           = vec3(0.136, 0.136, 0.136);
const vec3  moonLuminance       = sunIlluminance * moonColor;
const vec3  moonIlluminance     = moonLuminance * (tau * (1.0 - cos(sunAngularRadius)));

#if STAGE == STAGE_VERTEX
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

vec2 sky_opticalDepth(vec3 position, vec3 dir) {
	const float steps = 50.0;

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

//--//

void calculateColors() {
	vec3 viewPosition = upVector * (planetRadius + 23e3);
	vec2 sunOD = sky_opticalDepth(viewPosition, shadowLightVector);
	vec3 sunTransmittance = exp(-transmittanceCoefficients * sunOD.xy);

	shadowLightColor = mix(moonIlluminance, sunIlluminance, smoothstep(-0.01, 0.01, dot(sunVector, upVector))) * sunTransmittance;
	blockLightColor  = vec3(1.00, 0.70, 0.35) * 1.0e2;
	skyLightColor    = vec3(0.55, 0.65, 1.00) * 0.1 * shadowLightColor.b;
}
#endif
