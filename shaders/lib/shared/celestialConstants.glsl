#if !defined INCLUDE_SHARED_CELESTIALCONSTANTS
#define INCLUDE_SHARED_CELESTIALCONSTANTS

const float sunAngularDiameter = radians(0.535);
const float sunAngularRadius   = 0.5 * sunAngularDiameter;
const vec3  sunIlluminance     = vec3(1.0, 0.949, 0.937) * 128e3;
const vec3  sunLuminance       = sunIlluminance / ConeAngleToSolidAngle(sunAngularRadius);

const float moonAngularDiameter = radians(0.528);
const float moonAngularRadius   = 0.5 * moonAngularDiameter;
const vec3  moonAlbedo          = vec3(0.136);
const vec3  moonLuminance       = moonAlbedo * sunIlluminance / pi;
const vec3  moonIlluminance     = moonLuminance * ConeAngleToSolidAngle(moonAngularRadius);

#endif
