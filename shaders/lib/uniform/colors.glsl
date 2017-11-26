flat varying vec3 shadowLightColor;
flat varying vec3 blockLightColor;
flat varying vec3 skyLightColor;

const float sunAngularDiameter = radians(2.5); // earth-like: 0.536
const float sunAngularRadius   = sunAngularDiameter / 2.0;
const float sunBrightness      = 6.4e3; // earth-like: 128e3
const vec3  sunColor           = vec3(1.0, 0.96, 0.95);
const vec3  sunIlluminance     = sunBrightness * sunColor;
const vec3  sunLuminance       = sunIlluminance / (tau * (1.0 - cos(sunAngularRadius)));

const float moonAngularDiameter = radians(2.5); // earth-like: 0.528
const float moonAngularRadius   = moonAngularDiameter / 2.0;
const vec3  moonColor           = vec3(0.136, 0.136, 0.136);
const vec3  moonLuminance       = sunIlluminance * moonColor;
const vec3  moonIlluminance     = moonLuminance * (tau * (1.0 - cos(moonAngularRadius)));

#if STAGE == STAGE_VERTEX
#include "/lib/sky/main.glsl"

void calculateColors() {
	vec3 viewPosition = upVector * PLANET_RADIUS;
	vec2 sunOD = sky_opticalDepth(viewPosition, shadowLightVector, 50.0);
	vec3 sunTransmittance = exp(-transmittanceCoefficients * sunOD);

	shadowLightColor = mix(moonIlluminance, sunIlluminance, smoothstep(-0.01, 0.01, dot(sunVector, upVector))) * sunTransmittance;
	blockLightColor  = vec3(1.00, 0.70, 0.35) * 1.0e2;
	skyLightColor    = sky_atmosphere(vec3(0.0), upVector);
}
#endif
