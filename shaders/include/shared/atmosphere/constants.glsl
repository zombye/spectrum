#if !defined INCLUDE_SHARED_ATMOSPHERE_CONSTANTS
#define INCLUDE_SHARED_ATMOSPHERE_CONSTANTS

const float atmosphere_MuS_min = -0.35;

const int resMu  = 64;
const int resV   = 16;
const int resR   = 32;
const int resMuS = 32;

const ivec4 res4D = ivec4(resMu, resV, resR, resMuS);
const ivec2 res2D = ivec2(resMu * resR, resV * resMuS);

//----------------------------------------------------------------------------//

const float atmosphere_planetRadius = 6731e3; // m

const float atmosphere_mieg = 0.77; // unitless

// Limits
const float atmosphere_lowerLimitAltitude = -10e3; // m
const float atmosphere_upperLimitAltitude = 110e3; // m

// Distribution
const vec2 atmosphere_scaleHeights = vec2(8e3, 1.2e3); // m

// Coefficients
const float airNumberDensity       = 2.5035422e25; // m^3
const float ozoneConcentrationPeak = 8e-6; // unitless
const float ozoneNumberDensity     = airNumberDensity * exp(-35e3 / 8e3) * ozoneConcentrationPeak; // m^3 | airNumberDensity ASL * approximate relative density at altitude of peak ozone concentration * peak ozone concentration
const vec3  ozoneCrossSection      = vec3(4.51103766177301E-21, 3.2854797958699E-21, 1.96774621921165E-22) * 0.0001; // mul by 0.0001 to convert from cm^2 to m^2 | single-wavelength values.

// If my intuition is correct, rayleigh scattering can be split into two parts:
// One is wavelength dependent but is the same for any and all atmospheres. Here this part is named `rayleighColor`.
// The other is not wavelength dependent but can vary between different atmospheres. Here this part is named `rayleighK`.
// I'm not sure how accurate either of these are here, but I don't think they'll be too far off.
const vec3  rayleighColor = vec3(6.433377384678407e+24, 1.0873673940138444e+25, 2.4861429602679963e+25);
const float rayleighK     = 9.993284137187039e-31; // Set for an earth-like atmosphere.

// m^3 coefficients
const vec3 atmosphere_coefficientRayleigh = rayleighK * rayleighColor;
const vec3 atmosphere_coefficientOzone    = ozoneCrossSection * ozoneNumberDensity;
const vec3 atmosphere_coefficientMie      = vec3(4e-6); // Should usually be >= 2e-6, depends heavily on conditions. Current value is just one that looks good.

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
