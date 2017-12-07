#define WATER_FOG_COEFFS 0

#if   WATER_FOG_COEFFS == 1 // not as blue
const vec3 water_scatteringCoefficient = vec3(1.20e-3, 7.20e-3, 8.00e-3);
const vec3 water_absorbtionCoefficient = vec3(4.00e-1, 2.20e-1, 0.90e-1);
#elif WATER_FOG_COEFFS == 2 // aquamarine-ish
const vec3 water_scatteringCoefficient = vec3(1.50e-3, 6.40e-3, 7.50e-3);
const vec3 water_absorbtionCoefficient = vec3(2.70e-1, 1.60e-1, 0.80e-1);
#else
const vec3 water_scatteringCoefficient = vec3(1.20e-3, 7.20e-3, 8.00e-3);
const vec3 water_absorbtionCoefficient = vec3(4.00e-1, 2.25e-1, 0.55e-1);
#endif

const vec3 water_transmittanceCoefficient = (water_scatteringCoefficient + water_absorbtionCoefficient) * 2.0;
