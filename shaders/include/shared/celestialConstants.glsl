#if !defined INCLUDE_SHARED_CELESTIALCONSTANTS
#define INCLUDE_SHARED_CELESTIALCONSTANTS

/*
solar constant at solar minimum -> 1360.8(+-0.5) W/m^2 [Kopp, G.; Lean, J. L. (2011)]
at solar maximum, _supposedly_ around 0.1% higher, but i don't have a proper source for that (wikipedia isn't one)
so, for my purposes, i consider the solar constant to be approximately 1361.5 W/m^2

luminous efficacy is around 93 lm/W for a 5800 K blackbody, which is roughly representative of the sun
i also found a value of 98 lm/W specifically for the sun, but nothing about how that was obtained so for now i'm ignoring that

this comes out to approximately 126600 lm/m^2 at 1 AU

(also i should really start including my sources for things more often, that'd probably be quite helpful)
*/

#define SUN_ANGULAR_DIAMETER  0.535 // [0.535 1 2 5 10]
#define MOON_ANGULAR_DIAMETER 0.528 // [0.528 1 2 5 10]

const float sunAngularDiameter = radians(SUN_ANGULAR_DIAMETER);
const float sunAngularRadius   = 0.5 * sunAngularDiameter;
const vec3  sunColor           = vec3(1.0, 0.949, 0.937);// * R709ToRgb;
const vec3  sunIlluminance     = 126.6e3 * (sunColor / dot(sunColor, RgbToXyz[1]));
const vec3  sunLuminance       = sunIlluminance / ConeAngleToSolidAngle(sunAngularRadius);

const float moonAngularDiameter = radians(MOON_ANGULAR_DIAMETER);
const float moonAngularRadius   = 0.5 * moonAngularDiameter;
const vec3  moonAlbedo          = vec3(0.136);// * R709ToRgb_unlit;
const vec3  moonLuminance       = sunIlluminance * moonAlbedo / pi;
const vec3  moonIlluminance     = moonLuminance * ConeAngleToSolidAngle(moonAngularRadius);

#endif
