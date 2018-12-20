#if !defined INCLUDE_FRAGMENT_WATERNORMAL
#define INCLUDE_FRAGMENT_WATERNORMAL

float GetSmoothNoise(vec2 coord) {
	vec2 floored = floor(coord);

	/* slightly faster but has banding artifacts
	coord -= floored;
	coord *= coord * (3.0 - 2.0 * coord);
	coord += floored - 0.5;
	return texture(noisetex, 0.015625 * coord).r;
	//*/

	vec4 samples = textureGather(noisetex, 0.015625 * floored); // textureGather is slightly offset (at least on nvidia) and this offset can change with driver versions, which is why i floor the coords
	vec4 weights = (coord - floored).xxyy * vec4(1,-1,1,-1) + vec4(0,1,0,1);
	weights *= weights * (-2.0 * weights + 3.0);
	return dot(samples, weights.yxxy * weights.zzww);
}

struct waveParams {
	vec2 inverseScale;
	vec2 scaledTranslation;
	vec2 skew;
	float height;
	bool sharpen;
	float sharpenThreshold;
	float sharpenMin;
};

float CalculateWaterWave(vec2 pos, float waveTime, const waveParams params) {
	pos = params.inverseScale * pos + params.scaledTranslation * waveTime;
	pos = pos.yx * params.skew + pos;
	float wave = GetSmoothNoise(pos);
	if (params.sharpen) {
		wave = 1.0 - AlmostIdentity(abs(wave * 2.0 - 1.0), params.sharpenThreshold, params.sharpenMin);
	}
	return wave * params.height;
}

float CalculateWaterWaves(vec3 position) {
	//return 0.0;

	float waveTime = frameTimeCounter * WATER_WAVES_SPEED;

	const waveParams[4] params = waveParams[4](
		waveParams(1.0 / vec2(2.50, 3.33), vec2(2.40, 0.43) / vec2(2.50, 3.33), vec2(0.2, 1.3), 0.070,  true, 0.16, 0.08),
		waveParams(1.0 / vec2(0.71, 1.11), vec2(0.91,-0.71) / vec2(0.71, 1.11), vec2(0.0,-1.2), 0.030, false, 0.16, 0.08),
		waveParams(1.0 / vec2(0.26, 0.40), vec2(0.62, 0.26) / vec2(0.26, 0.40), vec2(0.0, 1.0), 0.010, false, 0.16, 0.08),
		waveParams(1.0 / vec2(0.09, 0.20), vec2(0.22, 0.16) / vec2(0.09, 0.20), vec2(0.0, 0.3), 0.003, false, 0.16, 0.08)
	);

	position += cameraPosition;

	float waves = 0.0;
	for (int i = 0; i < params.length(); i++) {
		waves += CalculateWaterWave(position.xz, waveTime, params[i]) - params[i].height;
	}

	return waves;
}

vec3 CalculateWaterNormal(vec3 position) {
	const float dist = 0.001;

	vec2 diffs;
	diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0, -dist));
	diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0,  dist));
	diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0, -dist));

	vec3 normal = vec3(-2.0 * dist, 4.0 * dist * dist, -2.0 * (dist * dist + dist));
	normal.xz  *= diffs;
	normal      = normalize(normal);

	return normal;
}

#ifdef WATER_PARALLAX
	vec3 CalculateWaterParallax(vec3 position, vec3 direction) {
		const int steps = WATER_PARALLAX_STEPS;

		// Init & first step
		vec3  interval = inversesqrt(steps) * direction / -direction.y;
		float height   = CalculateWaterWaves(position);
		vec3  offset   = -height * interval;
		      height   = CalculateWaterWaves(position + vec3(offset.x, 0.0, offset.z)) * WATER_PARALLAX_DEPTH_MULTIPLIER;

		// Loop from second step to second to last step
		for (int i = 1; i < steps - 1 && height < offset.y; ++i) {
			offset = (offset.y - height) * interval + offset;
			height = CalculateWaterWaves(position + vec3(offset.x, 0.0, offset.z)) * WATER_PARALLAX_DEPTH_MULTIPLIER;
		}

		// Last step
		if (steps > 1) {
			offset.xz = (offset.y - height) * interval.xz + offset.xz;
		}

		position.xz += offset.xz;

		return position;
	}

	vec3 CalculateWaterNormal(vec3 position, vec3 tangentViewVector) {
		position = CalculateWaterParallax(position, tangentViewVector.xzy);

		return CalculateWaterNormal(position).xzy;
	}
#endif

#endif
