#if !defined INCLUDE_SHARED_ATMOSPHERE_CONSTANTS
#define INCLUDE_SHARED_ATMOSPHERE_CONSTANTS

const float atmosphere_MuS_min = -0.4;

const int resMu  = 128;
const int resV   = 8;
const int resR   = 32;
const int resMuS = 32;

const ivec4 res4D = ivec4(resMu, resV, resR, resMuS);
const ivec2 res2D = ivec2(resMu * resR, resV * resMuS);

//----------------------------------------------------------------------------//

const float atmosphere_planetRadius = 6731e3; // m^1

const float atmosphere_mieg = 0.77; // unitless

// Limits
const float atmosphere_lowerLimitAltitude = -10e3; // m^1
const float atmosphere_upperLimitAltitude = 110e3; // m^1

// Distribution
const vec2 atmosphere_scaleHeights = vec2(8.0e3, 1.2e3); // m^1

// Coefficients
const float airNumberDensity       = 2.5035422e25; // m^3
const float ozoneConcentrationPeak = 8e-6; // unitless
const float ozoneNumberDensity     = airNumberDensity * exp(-35e3 / 8e3) * ozoneConcentrationPeak; // m^3 | airNumberDensity ASL * relative density at altitude of peak ozone concentration * peak ozone concentration
const vec3  ozoneCrossSection      = vec3(4.51103766177301E-21, 3.2854797958699E-21, 1.96774621921165E-22) * 0.0001; // cm^2 -> m^2 | single-wavelength values.

const vec3 atmosphere_coefficientRayleigh = vec3(5.8000e-6, 1.3500e-5, 3.3100e-5);  // m^3 | Want to calculate this myself at some point.
const vec3 atmosphere_coefficientOzone    = ozoneCrossSection * ozoneNumberDensity; // m^3 | ozone cross section * ozone number density
const vec3 atmosphere_coefficientMie      = vec3(8.6000e-6, 8.6000e-6, 8.6000e-6);  // m^3 | Should be >= 2e-6, depends heavily on conditions. Current value is just one that looks good.

//--// The rest are set from the above constants //---------------------------//

// Limits
const float atmosphere_lowerLimitRadius = atmosphere_planetRadius + atmosphere_lowerLimitAltitude;
const float atmosphere_upperLimitRadius = atmosphere_planetRadius + atmosphere_upperLimitAltitude;

const float atmosphere_lowerLimitRadiusSquared = atmosphere_lowerLimitRadius * atmosphere_lowerLimitRadius;
const float atmosphere_upperLimitRadiusSquared = atmosphere_upperLimitRadius * atmosphere_upperLimitRadius;

// Distribution
const vec2 atmosphere_inverseScaleHeights = 1.0 / atmosphere_scaleHeights;
const vec2 atmosphere_scaledPlanetRadius  = atmosphere_planetRadius / atmosphere_scaleHeights;

// Coefficients
const mat2x3 atmosphere_coefficientsScattering  = mat2x3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie);
const mat3   atmosphere_coefficientsAttenuation = mat3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie * 1.11, atmosphere_coefficientOzone); // commonly called the extinction coefficient

#endif
