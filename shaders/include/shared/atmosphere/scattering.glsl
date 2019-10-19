#if !defined INCLUDE_SHARED_ATMOSPHERE_SCATTERING
#define INCLUDE_SHARED_ATMOSPHERE_SCATTERING

vec3 Texture4D(sampler3D sampler, vec4 coord, ivec4 res) {
	/* xy
	float i, f = modf(coord.y * res.y - 0.5, i);

	float m = 1.0 / res.y;
	coord.x += i;
	vec3 s0 = texture(sampler, vec3(coord.x * m    , coord.zw)).rgb;
	vec3 s1 = texture(sampler, vec3(coord.x * m + m, coord.zw)).rgb;
	//*/
	//* yz
	float i, f = modf(coord.z * res.z - 0.5, i);

	float m = 1.0 / res.z;
	coord.y += i;
	vec3 s0 = texture(sampler, vec3(coord.x, coord.y * m    , coord.w)).rgb;
	vec3 s1 = texture(sampler, vec3(coord.x, coord.y * m + m, coord.w)).rgb;
	//*/
	/* zw
	float i, f = modf(coord.w * res.w - 0.5, i);

	float m = 1.0 / res.w;
	coord.z += i;
	vec3 s0 = texture(sampler, vec3(coord.xy, coord.z * m    )).rgb;
	vec3 s1 = texture(sampler, vec3(coord.xy, coord.z * m + m)).rgb;
	//*/

	return mix(s0, s1, f);
}

vec3 AtmosphereScatteringSingle(sampler3D scatteringSampler, float R, float Mu, float MuS, float V) {
	if (R > atmosphere_upperLimitRadius) {
		float discriminant = R * R * (Mu * Mu - 1.0) + atmosphere_upperLimitRadiusSquared;
		bool intersectsUpperLimit = Mu < 0.0 && discriminant >= 0.0;

		if (!intersectsUpperLimit) {
			return vec3(0.0);
		} else {
			float d = -R * Mu - sqrt(discriminant);

			// move r, mu, mus, to atmosphere starting point
			float newR = sqrt(d * d + 2.0 * R * Mu * d + R * R);
			Mu = (R * Mu + d) / newR;
			MuS = (R * MuS + d * V) / newR;
			R = newR;
		}
	}

	if (MuS < atmosphere_MuS_min) { return vec3(0.0); }

	vec4 uv = AtmosphereScatteringLookupUv(R, Mu, MuS, V);

	vec3 single_rayleigh = PhaseRayleigh(V)             * Texture4D(scatteringSampler, vec4(uv.xyz, (uv.w + 0.0) / 3.0), res4D);
	vec3 single_mie      = PhaseMie(V, atmosphere_mieg) * Texture4D(scatteringSampler, vec4(uv.xyz, (uv.w + 1.0) / 3.0), res4D);

	return (single_rayleigh + single_mie) / atmosphere_valueScale;
}
vec3 AtmosphereScatteringSingle(sampler3D scatteringSampler, vec3 p, vec3 d, vec3 l) {
	float R   = length(p);
	float Mu  = dot(p, d) / R;
	float MuS = dot(p, l) / R;
	float V   = dot(d, l);

	return AtmosphereScatteringSingle(scatteringSampler, R, Mu, MuS, V);
}
vec3 AtmosphereScatteringSingle(sampler3D scatteringSampler, sampler2D transmittanceSampler, vec3 p, vec3 d, vec3 l, float ed) {
	return AtmosphereScatteringSingle(scatteringSampler, p, d, l) - AtmosphereScatteringSingle(scatteringSampler, p + d * ed, d, l) * AtmosphereTransmittance(transmittanceSampler, p, d, ed);
}

vec3 AtmosphereScatteringMulti(sampler3D scatteringSampler, float R, float Mu, float MuS, float V) {
	if (R > atmosphere_upperLimitRadius) {
		float discriminant = R * R * (Mu * Mu - 1.0) + atmosphere_upperLimitRadiusSquared;
		bool intersectsUpperLimit = Mu < 0.0 && discriminant >= 0.0;

		if (!intersectsUpperLimit) {
			return vec3(0.0);
		} else {
			float d = -R * Mu - sqrt(discriminant);

			// move r, mu, mus, to atmosphere starting point
			float newR = sqrt(d * d + 2.0 * R * Mu * d + R * R);
			Mu = (R * Mu + d) / newR;
			MuS = (R * MuS + d * V) / newR;
			R = newR;
		}
	}

	if (MuS < atmosphere_MuS_min) { return vec3(0.0); }

	vec4 uv = AtmosphereScatteringLookupUv(R, Mu, MuS, V);

	vec3 multi = Texture4D(scatteringSampler, vec4(uv.xyz, (uv.w + 2.0) / 3.0), res4D);

	return multi / atmosphere_valueScale;
}
vec3 AtmosphereScatteringMulti(sampler3D scatteringSampler, vec3 p, vec3 d, vec3 l) {
	float R   = length(p);
	float Mu  = dot(p, d) / R;
	float MuS = dot(p, l) / R;
	float V   = dot(d, l);

	return AtmosphereScatteringMulti(scatteringSampler, R, Mu, MuS, V);
}
vec3 AtmosphereScatteringMulti(sampler3D scatteringSampler, sampler2D transmittanceSampler, vec3 p, vec3 d, vec3 l, float ed) {
	return AtmosphereScatteringMulti(scatteringSampler, p, d, l) - AtmosphereScatteringMulti(scatteringSampler, p + d * ed, d, l) * AtmosphereTransmittance(transmittanceSampler, p, d, ed);
}

vec3 AtmosphereScattering(sampler3D scatteringSampler, float R, float Mu, float MuS, float V) {
	if (R > atmosphere_upperLimitRadius) {
		float discriminant = R * R * (Mu * Mu - 1.0) + atmosphere_upperLimitRadiusSquared;
		bool intersectsUpperLimit = Mu < 0.0 && discriminant >= 0.0;

		if (!intersectsUpperLimit) {
			return vec3(0.0);
		} else {
			float d = -R * Mu - sqrt(discriminant);

			// move r, mu, mus, to atmosphere starting point
			float newR = sqrt(d * d + 2.0 * R * Mu * d + R * R);
			Mu = (R * Mu + d) / newR;
			MuS = (R * MuS + d * V) / newR;
			R = newR;
		}
	}

	if (MuS < atmosphere_MuS_min) { return vec3(0.0); }

	vec4 uv = AtmosphereScatteringLookupUv(R, Mu, MuS, V);

	vec3 single_rayleigh = PhaseRayleigh(V)             * Texture4D(scatteringSampler, vec4(uv.xyz, (uv.w + 0.0) / 3.0), res4D);
	vec3 single_mie      = PhaseMie(V, atmosphere_mieg) * Texture4D(scatteringSampler, vec4(uv.xyz, (uv.w + 1.0) / 3.0), res4D);
	vec3 multi           =                                Texture4D(scatteringSampler, vec4(uv.xyz, (uv.w + 2.0) / 3.0), res4D);

	return (single_rayleigh + single_mie + multi) / atmosphere_valueScale;
}
vec3 AtmosphereScattering(sampler3D scatteringSampler, vec3 p, vec3 d, vec3 l) {
	float R   = length(p);
	float Mu  = dot(p, d) / R;
	float MuS = dot(p, l) / R;
	float V   = dot(d, l);

	return AtmosphereScattering(scatteringSampler, R, Mu, MuS, V);
}
vec3 AtmosphereScattering(sampler3D scatteringSampler, sampler2D transmittanceSampler, vec3 p, vec3 d, vec3 l, float ed) {
	return AtmosphereScattering(scatteringSampler, p, d, l) - AtmosphereScattering(scatteringSampler, p + d * ed, d, l) * AtmosphereTransmittance(transmittanceSampler, p, d, ed);
}

#endif
