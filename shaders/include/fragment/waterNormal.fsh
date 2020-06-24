#if !defined INCLUDE_FRAGMENT_WATERNORMAL
#define INCLUDE_FRAGMENT_WATERNORMAL

#define WATER_WAVES_VERSION 2 // [0 1 2]

#if WATER_WAVES_VERSION == 3
	// currently too much of a WIP to include (also way too slow)
	//#include "/include/fragment/water/waves.glsl"
#else
	#line 9
	#define WATER_WAVES_HQ // approx. 2x more demanding, needed for projected caustics to look good (and makes it look a lot better when you don't have a lot of iterations)

	float GetSmoothNoise(vec2 coord) {
		vec2 floored = floor(coord);

		/* slightly faster but has banding artifacts
		coord -= floored;
		coord *= coord * (3.0 - 2.0 * coord);
		coord += floored - 0.5;
		return texture(noisetex, coord / 256.0).r;
		//*/

		vec4 samples = textureGather(noisetex, floored / 256.0); // textureGather is slightly offset (at least on nvidia) and this offset can change with driver versions, which is why i floor the coords
		vec4 weights    = (coord - floored).xxyy;
		     weights.yw = 1.0 - weights.yw;
		     weights   *= weights * (-2.0 * weights + 3.0);
		return dot(samples, weights.yxxy * weights.zzww);
	}
	vec4 TextureBilinearHq(sampler2D sampler, vec2 coord) {
		ivec2 res = textureSize(sampler, 0);
		coord = coord * res - 0.5;
		vec2 floored = floor(coord) / res;

		vec4 samples0 = textureGather(sampler, floored, 0);
		vec4 samples1 = textureGather(sampler, floored, 1);
		vec4 samples2 = textureGather(sampler, floored, 2);
		vec4 samples3 = textureGather(sampler, floored, 3);

		vec4 weights    = fract(coord).xxyy;
		     weights.yw = 1.0 - weights.yw;
		     weights = weights.yxxy * weights.zzww;

		return vec4(
			dot(samples0, weights),
			dot(samples1, weights),
			dot(samples2, weights),
			dot(samples3, weights)
		);
	}
	vec4 TextureBicubicHq(sampler2D sampler, vec2 coord) {
		ivec2 res = textureSize(sampler, 0);

		coord = coord * res - 0.5;

		vec4 c; vec2 m;
		FastBicubicCM(coord, c, m);

		c = (c + 0.5) / res.xyxy;

		return mix(
			mix(TextureBilinearHq(sampler, c.xy), TextureBilinearHq(sampler, c.zy), m.x),
			mix(TextureBilinearHq(sampler, c.xw), TextureBilinearHq(sampler, c.zw), m.x),
			m.y
		);
	}

	#if WATER_WAVES_VERSION == 2
	float CalculateWaterWaves(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		const int   iterations = WATER_WAVES_COUNT;
		const float g          = WATER_WAVES_G;
		      float wavelength = WATER_WAVES_WAVELENGTH;
		const float wlGain     = WATER_WAVES_WAVELENGTH_GAIN;
		      float height     = WATER_WAVES_WAVELENGTH * WATER_WAVES_WAVE_HEIGHT_RATIO / pi;
		const float gain       = WATER_WAVES_WAVE_HEIGHT_GAIN * WATER_WAVES_WAVELENGTH_GAIN;

		const float windScale = 2.0;

		vec2 camPos = cameraPosition.xz;

		vec2 windNoisePos = (position.xz + camPos) / 12.0;
		vec2 windDir = TextureBicubicHq(noisetex, windNoisePos / 256.0).xy * 4.0 - 2.0;

		float waves = 0.0;
		const float waveWidthRatio = 2.0;
		for (int i = 0; i < iterations; ++i) {
			float k = tau / wavelength; // angular wavenumber (radians per metre)
			float w = sqrt(g * k); // angular frequency (radians per second)

			// as it turns out, projected caustics need a lot of precision to work right
			// this part can get pretty bad in that regard if you don't modulo the camera position and time like this
			float pMul = 2.0 / wavelength;
			float tMul = (2.0 / tau) * (w / wavelength);
			#ifdef WATER_WAVES_HQ
			vec2 np = pMul * position.xz + mod(pMul * camPos, vec2(waveWidthRatio, 1.0) * 256.0 / 2.0);
			np.y -= mod(tMul * time, 256.0 / 2.0);
			#else
			vec2 np = pMul * position.xz + mod(pMul * camPos, vec2(waveWidthRatio, 1.0) * 256.0 / 1.333);
			np.y -= mod(tMul * time, 256.0 / 1.333);
			#endif

			np.x /= waveWidthRatio;

			float waveHeight = height * exp(windDir.y * windScale);
			#ifdef WATER_WAVES_HQ
			np *= 2.0; // seems to give "correct" results vs old sine based waves
			float wave = waveHeight * TextureBicubicHq(noisetex, np / 256.0).x;
			wave *= 3.0; // seems to give "correct" results vs old sine based waves
			#else
			np *= 1.333; // seems to give "correct" results vs old sine based waves
			float wave = waveHeight * GetSmoothNoise(np);
			wave *= 2.0; // seems to give "correct" results vs old sine based waves
			#endif

			waves -= wave;

			wavelength  *= wlGain;
			height      *= gain;
			position.xz *= rotateGoldenAngle;
			camPos      *= rotateGoldenAngle;
			windDir = rotateGoldenAngle * windDir;
		}

		return waves;
	}

	vec3 CalculateWaterNormal(vec3 position) {
		const float dist = 0.001;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		const float dist = 0.001;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));
		diffs *= strength;

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	#elif WATER_WAVES_VERSION == 1
	float CalculateWaterWave(float phase, float height, float sharpness) {
		// Trochoidal wave approximation
		// Has peaks at 0 and throughs at height.
		float power = 1.0 - 0.72 * pow(sharpness, 0.75);
		return height * pow(cos(phase) * 0.5 + 0.5, power);
	}
	float CalculateWaterWave(vec2 position, vec2 direction, float phaseOffset, float height, float wavelength, float sharpness, float time) {
		const float g = WATER_WAVES_G;

		float k = tau / wavelength; // angular wavenumber (radians per metre)
		float w = sqrt(g * k);      // angular frequency (radians per second)

		float phase = k * (dot(direction, position) + phaseOffset) - w * time;
		return CalculateWaterWave(phase, height, sharpness);
	}

	float CalculateWaterWaves(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		const int   iterations      = 6;
		const float g               = 9.8;
		const float baseWavelength  = 3.0;
		const float heightRatio     = 0.03;
		const float wavelengthGain  = 0.7;
		const float heightRatioGain = 0.85;
		const float sharpening      = 0.0;

		float wavelength = baseWavelength;
		float height     = baseWavelength * heightRatio / pi;
		float heightGain = heightRatioGain * wavelengthGain;

		const float windScale = 2.0;

		vec2 camPos = cameraPosition.xz;

		const float angle = 2.6;
		const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

		float waves = 0.0;
		for (int i = 0; i < iterations; ++i) {
			vec2 noiseUv = (position.xz + camPos) * vec2(1.0, 1.0) / wavelength;
			float phaseOffset = 2.0 * wavelength * TextureBicubicHq(noisetex, noiseUv / textureSize(noisetex, 0)).x;

			float sharpness = pow(height * pi / wavelength, 1.0 - sharpening);
			float wave = CalculateWaterWave(position.xz + camPos, vec2(0.0, 1.0), phaseOffset, height, wavelength, sharpness, time);

			waves -= wave;

			wavelength  *= wavelengthGain;
			height      *= heightGain;
			position.xz *= rotation;
			camPos      *= rotation;
		}

		return waves;
	}

	vec3 CalculateWaterNormal(vec3 position) {
		const float dist = 0.001;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		const float dist = 0.001;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));
		diffs *= strength;

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	#else
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
		float waveTime = frameTimeCounter * TIME_SCALE;

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
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		const float dist = 0.001;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));
		diffs *= strength;

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	#endif

	#ifdef WATER_PARALLAX
		vec3 CalculateWaterParallax(vec3 position, vec3 direction) {
			const int steps = WATER_PARALLAX_STEPS;

			// Init & first step
			vec3  interval = inversesqrt(steps) * direction / -direction.y;
			float height   = CalculateWaterWaves(position) * WATER_PARALLAX_DEPTH_MULTIPLIER;
			float stepSize = -height;
			position.xz += stepSize * interval.xz;

			if (steps > 1) {
				float offset = stepSize * interval.y;
				height = CalculateWaterWaves(position) * WATER_PARALLAX_DEPTH_MULTIPLIER;

				// Loop from second step to second to last step
				for (int i = 1; i < steps - 1 && height < offset; ++i) {
					stepSize = offset - height;
					position.xz += stepSize * interval.xz;

					offset += stepSize * interval.y;
					height = CalculateWaterWaves(position) * WATER_PARALLAX_DEPTH_MULTIPLIER;
				}

				// Last step
				if (height < offset) {
					stepSize = offset - height;
					position.xz += stepSize * interval.xz;
				}
			}

			return position;
		}

		vec3 CalculateWaterNormal(vec3 position, vec3 tangentViewVector) {
			position = CalculateWaterParallax(position, tangentViewVector.xzy);

			return CalculateWaterNormal(position).xzy;
			//return CalculateWaterNormal(position, sqrt(1.0 - Pow4(1.0 - abs(normalize(tangentViewVector).z)))).xzy;
		}
	#endif
#endif

#endif
