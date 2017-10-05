vec3 water_calculateFog(vec3 background, float waterDepth, float skylight) {
	const vec3 scatterCoeff = vec3(0.3e-2, 1.8e-2, 2.0e-2);
	const vec3 absorbCoeff  = vec3(0.8, 0.45, 0.11);
	const vec3 attenCoeff   = scatterCoeff + absorbCoeff;

	vec3 transmittance = exp(-attenCoeff * waterDepth);
	vec3 scattered  = skyLightColor * skylight * scatterCoeff * (1.0 - transmittance) / attenCoeff;

	return background * transmittance + scattered;
}
