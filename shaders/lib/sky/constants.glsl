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
