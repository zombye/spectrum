#if !defined INCLUDE_FRAGMENT_WATERNORMAL
#define INCLUDE_FRAGMENT_WATERNORMAL

#define WATER_WAVES_VERSION 4 // [0 1 2 3 4]

#if WATER_WAVES_VERSION == 4
	#define WAVES_LOD_SUPPORT

	vec2 GetWind(vec2 p) {
		vec2 noise = TextureCubic(noisetex, p * 0.05 / 256.0).xy * 2.0 - 1.0;
		const float c = 0.5;
		noise /= c * length(noise) + 1.0;
		return 4.0 * noise;
	}

	vec2 CalcWaveAmplitude(
		vec2 wave_speed,
		float wind_speed,
		vec2 wave_length
	) {
		const float p = 9.0;

		vec2 ratio = wave_speed / wind_speed;
		return pow(wave_speed, vec2(4.0)) * (0.002 / (wave_speed + 1.0) + 0.004 * exp(-(4.0 / p) * pow(ratio, vec2(p))));
	}

	vec2 rot(vec2 v, float a) {
		float c = cos(a);
		float s = sin(a);
		return vec2(
			v.x * c - v.y * s,
			v.x * s + v.y * c
		);
	}

	vec2 distribute_wave(vec2 wind_dir, float wind_speed, float u) {
		float anisotropy = wind_speed * 3.0;

		float rand_theta = tau * u;
		vec2 rand_dir = vec2(cos(rand_theta), sin(rand_theta));
		vec2 par = wind_dir * dot(rand_dir, wind_dir);
		vec2 per = rand_dir - par;
		return normalize(wind_dir * anisotropy + par * sqrt(anisotropy * anisotropy + 1.0) + per);
	}
	// probability density of a wave having a given direction
	float wave_direction_distribution(vec2 wind_dir, float wind_speed, vec2 direction) {
		float anisotropy = wind_speed * 3.0;
		return 1.0 / (2.0 * pi * (sqrt(anisotropy * anisotropy + 1.0) - dot(direction, wind_dir) * anisotropy));
	}

	void ellipoid_axis_lengths(
		mat2 A,
		out float semi_minor_axis_length,
		out float semi_major_axis_length
	) {
		float M = dot(A[0], A[0]) + dot(A[1], A[1]);
		float N = abs(determinant(A));
		float tmp1 = sqrt(M + 2.0 * N);
		float tmp2 = sqrt(M - 2.0 * N);
		semi_minor_axis_length = 0.5 * (tmp1 - tmp2);
		semi_major_axis_length = 0.5 * (tmp1 + tmp2);
	}

	// wave_vector = unit direction vector divided by wavelength
	float wave_height(vec2 position, float time, vec2 wave_vector, float frequency, float amplitude, float phase_offset) {
		float phase = tau * (dot(position, wave_vector) - frequency * time) + phase_offset;
		return amplitude * cos(phase);
	}
	vec2 wave_slope(vec2 position, float time, vec2 wave_vector, float frequency, float amplitude, float phase_offset) {
		float phase = tau * (dot(position, wave_vector) - frequency * time) + phase_offset;
		return -amplitude * wave_vector * tau * sin(phase);
	}
	float wave_slope_variance(vec2 wave_vector, float amplitude) {
		return amplitude * amplitude * 0.25 * tau * tau * (wave_vector.x * wave_vector.x + wave_vector.y * wave_vector.y);
	}
	mat2 wave_slope_covariance_matrix(vec2 wave_vector, float amplitude) {
		return amplitude * amplitude * 0.5 * tau * tau * mat2(
			wave_vector.x * wave_vector.x, wave_vector.x * wave_vector.y,
			wave_vector.y * wave_vector.x, wave_vector.y * wave_vector.y
		);
	}

	/*
	mat2 wave_distribution_slope_covariance(
		vec2 wind_dir,
		float wind_speed,
		float amplitude,
		float wave_length
	) {

	}
	*/

	#define WAVES_WIND_PERF_CHEAT // Significantly improves performance in exchance for a probably unnoticeabe accuracy loss.
	float CalculateWaterWavesLayerPair(
		vec2 p,
		float t,
		#ifdef WAVES_WIND_PERF_CHEAT
		float wind_speed,
		vec2 wind_dir,
		#endif
		const vec2 wavelengths,
		const float grid_frequency,
		const int set
	) {
		const float g = 9.81;
		const float tau = 6.2831853;

		vec2 k = tau / wavelengths; // angular wavenumber (radians per metre)
		vec2 w = sqrt(g * k);      // angular frequency (radians per second)
		vec2 wavevel = w / k;

		#ifdef WAVES_WIND_PERF_CHEAT
		vec2 amplitude = CalcWaveAmplitude(wavevel, wind_speed, wavelengths);
		#endif

		ivec2 i = ivec2(floor(grid_frequency * p));
		vec2 f = fract(grid_frequency * p);

		float n = 0.0;
		for (int ox = 0; ox < 2; ++ox)
		for (int oy = 0; oy < 2; ++oy) {
			ivec2 ci = i + ivec2(ox, oy);
			vec2 cell_pos = vec2(ci) / grid_frequency;

			#ifndef WAVES_WIND_PERF_CHEAT
			vec2 windvel = GetWind(cell_pos);
			#endif
			vec2 phoffs  = texelFetch(noisetex, (ci + (2*set+0)*97) % 256, 0).xy;
			vec2 angoffs = texelFetch(noisetex, (ci + (2*set+1)*97) % 256, 0).xy;

			#ifndef WAVES_WIND_PERF_CHEAT
			float wind_speed = length(windvel);
			vec2 amplitude = CalcWaveAmplitude(wavevel, wind_speed, wavelengths);

			vec2 wind_dir = normalize(windvel);
			#endif
			vec2[2] wavevector = vec2[2](
				k.x * distribute_wave(wind_dir, wind_speed, angoffs.x),
				k.y * distribute_wave(wind_dir, wind_speed, angoffs.y)
			);

			vec2 rel_pos = p - cell_pos;
			vec2 phase = vec2(
				dot(rel_pos, wavevector[0]),
				dot(rel_pos, wavevector[1])
			) + w * t + tau * phoffs;
			vec2 waves = amplitude * (sin(phase) - 1.0);

			float c = waves.x + waves.y;

			vec2 tmp = f * f * (3.0 - 2.0 * f);
			float we = (ox == 0 ? 1.0 - tmp.x : tmp.x)
			         * (oy == 0 ? 1.0 - tmp.y : tmp.y);

			n += c * we;
		}

		return n;
	}
	vec2 CalculateWaterWavesLayerPairSlope(
		vec2 p,
		float t,
		#ifdef WAVES_WIND_PERF_CHEAT
		float wind_speed,
		vec2 wind_dir,
		#endif
		const vec2 wavelengths,
		const float grid_frequency,
		const int set
	) {
		const float g = 9.81;
		const float tau = 6.2831853;

		vec2 k = tau / wavelengths; // angular wavenumber (radians per metre)
		vec2 w = sqrt(g * k);      // angular frequency (radians per second)
		vec2 wavevel = w / k;

		#ifdef WAVES_WIND_PERF_CHEAT
		vec2 amplitude = CalcWaveAmplitude(wavevel, wind_speed, wavelengths);
		#endif

		ivec2 i = ivec2(floor(grid_frequency * p));
		vec2 f = fract(grid_frequency * p);

		vec2 slope = vec2(0.0);
		for (int ox = 0; ox < 2; ++ox)
		for (int oy = 0; oy < 2; ++oy) {
			ivec2 ci = i + ivec2(ox, oy);
			vec2 cell_pos = vec2(ci) / grid_frequency;

			#ifndef WAVES_WIND_PERF_CHEAT
			vec2 windvel = GetWind(cell_pos);
			#endif
			vec2 phoffs  = texelFetch(noisetex, (ci + (2*set+0)*97) % 256, 0).xy;
			vec2 angoffs = texelFetch(noisetex, (ci + (2*set+1)*97) % 256, 0).xy;

			#ifndef WAVES_WIND_PERF_CHEAT
			float wind_speed = length(windvel);
			vec2 amplitude = CalcWaveAmplitude(wavevel, wind_speed, wavelengths);

			vec2 wind_dir = normalize(windvel);
			#endif
			vec2[2] wavevector = vec2[2](
				k.x * distribute_wave(wind_dir, wind_speed, angoffs.x),
				k.y * distribute_wave(wind_dir, wind_speed, angoffs.y)
			);

			vec2 rel_pos = p - cell_pos;
			vec2 phase = vec2(
				dot(rel_pos, wavevector[0]),
				dot(rel_pos, wavevector[1])
			) + w * t + tau * phoffs;
			vec2 waves = amplitude * (sin(phase) - 1.0);
			vec2 slopes = amplitude * cos(phase);

			float c = waves.x + waves.y;
			vec2 c_slope = slopes.x * wavevector[0] + slopes.y * wavevector[1];


			vec2 tmp = f * f * (3.0 - 2.0 * f);
			vec2 tmp2 = vec2(
				ox == 0 ? 1.0 - tmp.x : tmp.x,
				oy == 0 ? 1.0 - tmp.y : tmp.y
			);
			float we = tmp2.x * tmp2.y;
			vec2 we_slope = vec2(
				(ox == 0 ? -1 : 1) * (6.0 * f.x * (1.0 - f.x)) * tmp2.y,
				(oy == 0 ? -1 : 1) * (6.0 * f.y * (1.0 - f.y)) * tmp2.x
			) * grid_frequency;

			slope += c_slope * we + c * we_slope;
		}

		return slope;
	}
	vec2 CalculateWaterWavesLayerPairSlopeLod(
		vec2 p,
		float t,
		#ifdef WAVES_WIND_PERF_CHEAT
		float wind_speed,
		vec2 wind_dir,
		#endif
		const vec2 wavelengths,
		const float grid_frequency,
		const int set,
		inout float slope_variance
	) {
		const float g = 9.81;
		const float tau = 6.2831853;

		vec2 k = tau / wavelengths; // angular wavenumber (radians per metre)
		vec2 w = sqrt(g * k);      // angular frequency (radians per second)
		vec2 wavevel = w / k;

		#ifdef WAVES_WIND_PERF_CHEAT
		vec2 amplitude = CalcWaveAmplitude(wavevel, wind_speed, wavelengths);
		#endif

		mat2 A = mat2(dFdx(p), dFdy(p));
		float minor, major;
		ellipoid_axis_lengths(A, minor, major);
		vec2 lodweights = clamp(log2(wavelengths / major), 0.0, 1.0);
		vec2 vars = 0.25 * tau * tau * amplitude * amplitude / (wavelengths * wavelengths);
		slope_variance += dot(1.0 - lodweights, vars);
		amplitude *= lodweights;

		if (lodweights.x + lodweights.y <= 0.001) {
			return vec2(0.0);
		}

		ivec2 i = ivec2(floor(grid_frequency * p));
		vec2 f = fract(grid_frequency * p);

		vec2 slope = vec2(0.0);
		for (int ox = 0; ox < 2; ++ox)
		for (int oy = 0; oy < 2; ++oy) {
			ivec2 ci = i + ivec2(ox, oy);
			vec2 cell_pos = vec2(ci) / grid_frequency;

			#ifndef WAVES_WIND_PERF_CHEAT
			vec2 windvel = GetWind(cell_pos);
			#endif
			vec2 phoffs  = texelFetch(noisetex, (ci + (2*set+0)*97) % 256, 0).xy;
			vec2 angoffs = texelFetch(noisetex, (ci + (2*set+1)*97) % 256, 0).xy;

			#ifndef WAVES_WIND_PERF_CHEAT
			float wind_speed = length(windvel);
			vec2 amplitude = CalcWaveAmplitude(wavevel, wind_speed, wavelengths);

			vec2 wind_dir = normalize(windvel);
			#endif
			vec2[2] wavevector = vec2[2](
				k.x * distribute_wave(wind_dir, wind_speed, angoffs.x),
				k.y * distribute_wave(wind_dir, wind_speed, angoffs.y)
			);

			vec2 rel_pos = p - cell_pos;
			vec2 phase = vec2(
				dot(rel_pos, wavevector[0]),
				dot(rel_pos, wavevector[1])
			) + w * t + tau * phoffs;
			vec2 waves = amplitude * (sin(phase) - 1.0);
			vec2 slopes = amplitude * cos(phase);

			float c = waves.x + waves.y;
			vec2 c_slope = slopes.x * wavevector[0] + slopes.y * wavevector[1];


			vec2 tmp = f * f * (3.0 - 2.0 * f);
			vec2 tmp2 = vec2(
				ox == 0 ? 1.0 - tmp.x : tmp.x,
				oy == 0 ? 1.0 - tmp.y : tmp.y
			);
			float we = tmp2.x * tmp2.y;
			vec2 we_slope = vec2(
				(ox == 0 ? -1 : 1) * (6.0 * f.x * (1.0 - f.x)) * tmp2.y,
				(oy == 0 ? -1 : 1) * (6.0 * f.y * (1.0 - f.y)) * tmp2.x
			) * grid_frequency;

			slope += c_slope * we + c * we_slope;
		}

		return slope;
	}

	float CalculateWaterWaves(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		vec2 p = position.xz + cameraPosition.xz;

		#ifdef WAVES_WIND_PERF_CHEAT
		vec2 windvel = GetWind(p);
		float wind_speed = length(windvel);
		vec2 wind_dir = normalize(windvel);
		#endif

		float n = 0.0;

		// large
		n += CalculateWaterWavesLayerPair(
			p, time,
			#ifdef WAVES_WIND_PERF_CHEAT
			wind_speed,
			wind_dir,
			#endif
			vec2(2.0, 1.0),
			1.0,
			0
		);

		// small
		n += CalculateWaterWavesLayerPair(
			p, time,
			#ifdef WAVES_WIND_PERF_CHEAT
			wind_speed,
			wind_dir,
			#endif
			vec2(0.5, 0.25),
			4.0,
			1
		);

		return n;
	}
	vec2 CalculateWaterWavesSlope(vec3 position) {
		const float g = 9.81;
		const float tau = 6.2831853;


		float time = frameTimeCounter * TIME_SCALE;

		vec2 p = position.xz + cameraPosition.xz;
		float t = time;

		#ifdef WAVES_WIND_PERF_CHEAT
		vec2 windvel = GetWind(p);
		float wind_speed = length(windvel);
		vec2 wind_dir = normalize(windvel);
		#endif

		vec2 slope = vec2(0.0);

		// large
		slope += CalculateWaterWavesLayerPairSlope(
			p, time,
			#ifdef WAVES_WIND_PERF_CHEAT
			wind_speed,
			wind_dir,
			#endif
			vec2(2.0, 1.0),
			1.0,
			0
		);

		// small
		slope += CalculateWaterWavesLayerPairSlope(
			p, time,
			#ifdef WAVES_WIND_PERF_CHEAT
			wind_speed,
			wind_dir,
			#endif
			vec2(0.5, 0.25),
			4.0,
			1
		);

		return slope;
	}
	vec2 CalculateWaterWavesSlopeLod(vec3 position, out float slope_variance) {
		const float g = 9.81;
		const float tau = 6.2831853;


		float time = frameTimeCounter * TIME_SCALE;

		vec2 p = position.xz + cameraPosition.xz;
		float t = time;

		#ifdef WAVES_WIND_PERF_CHEAT
		vec2 windvel = GetWind(p);
		float wind_speed = length(windvel);
		vec2 wind_dir = normalize(windvel);
		#endif

		vec2 slope = vec2(0.0);
		slope_variance = 0.0;

		// large
		slope += CalculateWaterWavesLayerPairSlopeLod(
			p, time,
			#ifdef WAVES_WIND_PERF_CHEAT
			wind_speed,
			wind_dir,
			#endif
			vec2(2.0, 1.0),
			1.0,
			0,
			slope_variance
		);

		// small
		slope += CalculateWaterWavesLayerPairSlopeLod(
			p, time,
			#ifdef WAVES_WIND_PERF_CHEAT
			wind_speed,
			wind_dir,
			#endif
			vec2(0.5, 0.25),
			4.0,
			1,
			slope_variance
		);

		return slope;
	}

	vec3 CalculateWaterNormal(vec3 position) {
		vec2 slope  = CalculateWaterWavesSlope(position);
		vec3 normal = vec3(-slope.x, 1.0, -slope.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		vec2 slope  = CalculateWaterWavesSlope(position);
		     slope *= strength;
		vec3 normal = vec3(-slope.x, 1.0, -slope.y);

		return normalize(normal);
	}

	vec3 CalculateWaterNormalLod(vec3 position, out float slope_variance) {
		vec2 slope  = CalculateWaterWavesSlopeLod(position, slope_variance);
		vec3 normal = vec3(-slope.x, 1.0, -slope.y);

		return normalize(normal);
	}
#elif WATER_WAVES_VERSION == 3
	/*
	float SmoothMin(float x0, float x1, float s) {
		// Low-quality caustics need higher-order continuity to look right.
		// This is nearly indistinguishable in reflections/refractions or
		// in the high quality caustics, so as a small optimization I only
		// do it in the shadow map.
		#if defined PROGRAM_SHADOW
		s *= 2.0 / 3.0;
		#endif

		float m = Clamp01(0.5 + s * (x0 - x1));

		#if defined PROGRAM_SHADOW
		return mix(x0, x1, m) - (m * (m * (m * (2.0 - m) - 2.0) + 1.0) / (2.0 * s));
		#else
		return mix(x0, x1, m) - (m * (1.0 - m) / (2.0 * s));
		#endif
	}
	float WaterCellNoise(vec3 position, float s) {
		vec3 i = floor(position);
		vec3 f = fract(position);

		float distSq = 2.75; // max possible
		float distSq2 = 2.75;
		float distSq3 = 2.75;
		for (int x = -1; x <= 1; ++x) {
			for (int y = -1; y <= 1; ++y) {
				for (int z = -1; z <= 1; ++z) {
					vec3 cell = Hash3(i + vec3(x, y, z)) + vec3(x, y, z) - f;
					float cellDistSq = dot(cell, cell);
					if (cellDistSq < distSq) {
						distSq3 = distSq2;
						distSq2 = distSq;
						distSq = cellDistSq;
					} else if (cellDistSq < distSq2) {
						distSq3 = distSq2;
						distSq2 = cellDistSq;
					} else if (cellDistSq < distSq3) {
						distSq3 = cellDistSq;
					}
				}
			}
		}

		distSq2 = SmoothMin(distSq2, distSq3, s);
		return SmoothMin(distSq, distSq2, s);
	}
	*/
	float CalculateWaterWaves(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		position = mod(position, 40.0);
		position += mod(cameraPosition, 40.0);
		position.y += mod(2.0 * time, 40.0);

		vec4 tmp;
		tmp.xy = TextureCubic(gaux4, position / 40.0, 0).xy;
		tmp.zw = TextureCubic(gaux4, position / 20.0, 0).yz;
		tmp *= tmp * 2.75;
		tmp.xy *= tmp.xy;
		tmp -= 1.0;
		float waves = 0.18 * (tmp.x + 0.3 * (tmp.y + 0.35 * (tmp.z + 0.3 * tmp.w)));

		return waves;
	}
	vec2 CalculateWaterWavesSlope(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		position = mod(position, 40.0);
		position += mod(cameraPosition, 40.0);
		position.y += mod(2.0 * time, 40.0);

		vec4 tmp;
		tmp.xy = TextureCubic(gaux4, position / 40.0, 0).xy;
		tmp.zw = TextureCubic(gaux4, position / 20.0, 0).yz;

		mat3x4 m1 = TextureCubicJacobian(gaux4, position / 40.0) / 40.0;
		m1[0].xy *= 30.25 * Pow3(tmp.xy);
		m1[2].xy *= 30.25 * Pow3(tmp.xy);
		mat3x4 m2 = TextureCubicJacobian(gaux4, position / 20.0) / 20.0;
		m2[0].yz *= 5.5 * tmp.zw;
		m2[2].yz *= 5.5 * tmp.zw;
		vec2 slope = 0.18 * (vec2(m1[0].x, m1[2].x) + 0.3 * (vec2(m1[0].y, m1[2].y) + 0.35 * (vec2(m2[0].y, m2[2].y) + 0.3 * vec2(m2[0].z, m2[2].z))));

		return slope;
	}

	vec3 CalculateWaterNormal(vec3 position) {
		vec2 slope  = CalculateWaterWavesSlope(position);
		vec3 normal = vec3(-slope.x, 1.0, -slope.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		vec2 slope  = CalculateWaterWavesSlope(position);
		     slope *= strength;
		vec3 normal = vec3(-slope.x, 1.0, -slope.y);

		return normalize(normal);
	}
#else
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
	vec4 TextureCubicHq(sampler2D sampler, vec2 coord) {
		ivec2 res = textureSize(sampler, 0);

		coord = coord * res;

		vec2 cLo, cHi, m;
		FastCubicCM(coord, cLo, cHi, m);

		cLo = (cLo + 0.5) / res;
		cHi = (cHi + 0.5) / res;

		return mix(
			mix(TextureBilinearHq(sampler, vec2(cLo.x, cLo.y)), TextureBilinearHq(sampler, vec2(cHi.x, cLo.y)), m.x),
			mix(TextureBilinearHq(sampler, vec2(cLo.x, cHi.y)), TextureBilinearHq(sampler, vec2(cHi.x, cHi.y)), m.x),
			m.y
		);
	}

	#if WATER_WAVES_VERSION == 2
	float CalculateWaterWaves(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		const int   iterations = WATER_WAVES2_COUNT;
		const float g          = WATER_WAVES2_G;
		      float wavelength = WATER_WAVES2_WAVELENGTH;
		const float wlGain     = WATER_WAVES2_WAVELENGTH_GAIN;
		      float height     = WATER_WAVES2_WAVELENGTH * WATER_WAVES2_HEIGHT_RATIO / pi;
		const float gain       = WATER_WAVES2_HEIGHT_GAIN * WATER_WAVES2_WAVELENGTH_GAIN;

		const float windScale = 2.0;

		vec2 camPos = cameraPosition.xz;

		vec2 windNoisePos = (position.xz + camPos) / 12.0;
		vec2 windDir = TextureCubicHq(noisetex, windNoisePos / 256.0).xy * 4.0 - 2.0;

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
			float wave = waveHeight * TextureCubicHq(noisetex, np / 256.0).x;
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
		const float dist = 0.02;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		const float dist = 0.02;

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
		const float g = WATER_WAVES1_G;

		float k = tau / wavelength; // angular wavenumber (radians per metre)
		float w = sqrt(g * k);      // angular frequency (radians per second)

		float phase = k * (dot(direction, position) + phaseOffset) - w * time;
		return CalculateWaterWave(phase, height, sharpness);
	}

	float CalculateWaterWaves(vec3 position) {
		float time = frameTimeCounter * TIME_SCALE;

		const int   iterations      = WATER_WAVES1_COUNT;
		const float g               = WATER_WAVES1_G;
		const float baseWavelength  = WATER_WAVES1_WAVELENGTH;
		const float heightRatio     = WATER_WAVES1_HEIGHT_RATIO;
		const float wavelengthGain  = WATER_WAVES1_WAVELENGTH_GAIN;
		const float heightRatioGain = WATER_WAVES1_HEIGHT_GAIN;
		const float sharpening      = WATER_WAVES1_SHARPENING;

		float wavelength = baseWavelength;
		float height     = baseWavelength * heightRatio / pi;
		float heightGain = heightRatioGain * wavelengthGain;

		vec2 camPos = cameraPosition.xz;

		const float angle = 2.6;
		const mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

		float waves = 0.0;
		for (int i = 0; i < iterations; ++i) {
			vec2 noiseUv = (position.xz + camPos) * vec2(1.0, 1.0) / wavelength;
			float phaseOffset = 2.0 * wavelength * TextureCubicHq(noisetex, noiseUv / textureSize(noisetex, 0)).x;

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
		const float dist = 0.02;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		const float dist = 0.02;

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
		const float dist = 0.02;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	vec3 CalculateWaterNormal(vec3 position, float strength) {
		const float dist = 0.02;

		vec2 diffs;
		diffs.x = CalculateWaterWaves(position + vec3( dist, 0.0,-dist));
		diffs.y = CalculateWaterWaves(position + vec3(-dist, 0.0, dist));
		diffs  -= CalculateWaterWaves(position + vec3(-dist, 0.0,-dist));
		diffs *= strength;

		vec3 normal = vec3(-diffs.x, 2.0 * dist, -diffs.y);

		return normalize(normal);
	}
	#endif
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
	#if defined WAVES_LOD_SUPPORT
	vec3 CalculateWaterNormalLod(vec3 position, vec3 tangentViewVector, out float slope_variance) {
		position = CalculateWaterParallax(position, tangentViewVector.xzy);

		return CalculateWaterNormalLod(position, slope_variance).xzy;
	}
	#endif
#endif

#endif
