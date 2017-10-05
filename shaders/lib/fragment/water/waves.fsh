struct waveParams {
	vec2 scale;
	vec2 translation;
	vec2 skew;
	float height;
	bool sharpen;
	float sharpenThreshold;
	float sharpenMin;
};

float water_calculateWave(vec2 pos, const waveParams params) {
	pos += frameTimeCounter * params.translation;
	pos /= params.scale * 64.0;
	pos += pos.yx * params.skew;
	float wave = textureSmooth(noisetex, pos).r;
	if (params.sharpen)
		wave = 1.0 - almostIdentity(abs(wave * 2.0 - 1.0), params.sharpenThreshold, params.sharpenMin);
	return wave * params.height;
}

float water_calculateWaves(vec3 pos) {
	const waveParams[3] params = waveParams[3](
		waveParams(vec2(2.50, 3.33), vec2(-2.40,-0.43), vec2(0.2, 1.3), 0.250,  true, 0.2, 0.1),
		waveParams(vec2(0.71, 1.11), vec2(-0.91, 0.71), vec2(0.0,-1.2), 0.120, false, 0.2, 0.1),
		waveParams(vec2(0.26, 0.40), vec2(-0.62,-0.26), vec2(0.0, 1.0), 0.020, false, 0.2, 0.1)
	);

	float waves = 0.0;
	for (int i = 0; i < params.length(); i++) {
		waves += water_calculateWave(pos.xz, params[i]) - params[i].height;
	}

	return waves;
}
