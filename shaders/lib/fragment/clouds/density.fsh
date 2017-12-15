// Partially based on Space Engine's cloud generation

float clouds_fbm(vec3 position, int octaves, float gain) {
	float amplitude = 1.0;
	float fbm       = get3DNoise(position) * amplitude;
	float invWeight = amplitude;
	for (int i = 1; i < octaves; i++) {
		amplitude *= gain;
		position  *= pi;
		fbm       += get3DNoise(position) * amplitude;
		invWeight += amplitude;
	}
	return fbm / invWeight;
}
vec3 clouds_fbm3D(vec3 position, int octaves) {
	float amplitude = 1.0;
	vec3  fbm       = vec3(get3DNoise(position), get3DNoise(position + vec3(3.33, 5.71, 1.96)), get3DNoise(position + vec3(7.77, 2.65, 4.37))) * amplitude;
	float invWeight = amplitude;
	for (int i = 1; i < octaves; i++) {
		amplitude *= 1.0 / 3.0;
		position  *= pi;
		fbm       += vec3(get3DNoise(position), get3DNoise(position + vec3(3.33, 5.71, 1.96)), get3DNoise(position + vec3(7.77, 2.65, 4.37))) * amplitude;
		invWeight += amplitude;
	}
	return fbm / invWeight;
}

float clouds_density(vec3 position, cloudLayerParameters params) {
	// Get initial point
	vec3 point = position / PLANET_RADIUS;
	     point = normalize(vec3(point.xz, 1.0)) * (point.y + 1.0);

	point = point * params.frequency + frameTimeCounter / 3600.0;

	// Distortion to make it look more like it's flowing
	point = point * params.frequency2;
	vec3 distortedPoint = clouds_fbm3D(point, params.distortOctaves) * params.distortAmplitude + point;
	     distortedPoint = clouds_fbm3D(distortedPoint, params.distortOctaves2) * params.distortAmplitude2 + point;
	float density = clouds_fbm(distortedPoint, params.octaves, params.gain);

	// Vertical falloff
	float falloff = clamp01((position.y - params.altitudeMin) / (params.altitudeMax - params.altitudeMin));
	      falloff = 6.75 * falloff * pow2(1.0 - falloff);
	density *= falloff * params.coverage + (1.0 - params.coverage);

	// Apply coverage
	float densityFactor  = 1.0 / params.coverage;
	float coverageFactor = 1.0 - densityFactor;
	density = clamp01(density * densityFactor + coverageFactor);

	return density;
}
