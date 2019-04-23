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
	vec4 weights    = (coord - floored).xxyy;
	     weights.yw = 1.0 - weights.yw;
	     weights   *= weights * (-2.0 * weights + 3.0);
	return dot(samples, weights.yxxy * weights.zzww);
}

float CalculateWaterWave(float phase, float height, float sharpness) {
	// Trochoidal wave approximation
	// Has peaks at 0 and throughs at height.
	float power = 1.0 - 0.72 * pow(sharpness, 0.75);
	return height * pow(cos(phase) * 0.5 + 0.5, power);
}
float CalculateWaterWave(vec2 position, vec2 direction, float phaseOffset, float height, float wavelength, float sharpness, float time) {
	const float g = 9.81;

	float k = tau / wavelength; // angular wavenumber (radians per metre)
	float w = sqrt(g * k);      // angular frequency (radians per second)

	float phase = k * (dot(direction, position) + phaseOffset) - w * time;
	return CalculateWaterWave(phase, height, sharpness);
}

float CalculateWaterWaves(vec3 position) {
	position += cameraPosition;

	float waveTime = frameTimeCounter * WATER_WAVES_SPEED;

	const int   iterations = WATER_WAVES_COUNT;
	const float g          = WATER_WAVES_G;
	      float wavelength = WATER_WAVES_WAVELENGTH;
	const float wlGain     = WATER_WAVES_WAVELENGTH_GAIN;
	      float height     = WATER_WAVES_WAVELENGTH * WATER_WAVES_WAVE_HEIGHT_RATIO / pi;
	const float gain       = WATER_WAVES_WAVE_HEIGHT_GAIN * WATER_WAVES_WAVELENGTH_GAIN;

	const float angle = 2.6;
	const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

	float waves = 0.0;
	for (int i = 0; i < iterations; ++i) {
		float k = tau / wavelength; // angular wavenumber (radians per metre)
		float w = sqrt(g * k);      // angular frequency  (radians per second)

		float phaseNoise = GetSmoothNoise(vec2(position.x, position.z - w * waveTime * 0.7) / wavelength) * wavelength * 0.8;
		float phase = k * (position.z + phaseNoise) - w * waveTime;

		float sharpness = pow(pi * height / wavelength, 1.0 - WATER_WAVES_SHARPENING);
		float wave = CalculateWaterWave(phase, height, sharpness);

		waves -= wave;

		wavelength *= wlGain;
		height     *= gain;
		position.xz = rotation * position.xz;
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
