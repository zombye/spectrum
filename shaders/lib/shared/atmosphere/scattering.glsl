#if !defined INCLUDE_SHARED_ATMOSPHERE_SCATTERING
#define INCLUDE_SHARED_ATMOSPHERE_SCATTERING

vec3 Texture4DRGBE8(sampler2D sampler, vec4 coord, ivec4 res) {
	coord = coord * res - 0.5;
	ivec4 i = ivec4(floor(coord));
	vec4 f = coord - i;

	vec3 s0  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,0,0,0), res), 0));
	vec3 s1  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,0,0,0), res), 0));
	vec3 s2  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,1,0,0), res), 0));
	vec3 s3  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,1,0,0), res), 0));
	vec3 s4  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,0,1,0), res), 0));
	vec3 s5  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,0,1,0), res), 0));
	vec3 s6  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,1,1,0), res), 0));
	vec3 s7  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,1,1,0), res), 0));
	vec3 s8  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,0,0,1), res), 0));
	vec3 s9  = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,0,0,1), res), 0));
	vec3 s10 = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,1,0,1), res), 0));
	vec3 s11 = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,1,0,1), res), 0));
	vec3 s12 = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,0,1,1), res), 0));
	vec3 s13 = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,0,1,1), res), 0));
	vec3 s14 = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(0,1,1,1), res), 0));
	vec3 s15 = DecodeRGBE8(texelFetch(sampler, LookupUv4DTo2D(i + ivec4(1,1,1,1), res), 0));

	return mix(
		mix(mix(mix(s0,  s1,  f.x), mix(s2,  s3,  f.x), f.y),
			mix(mix(s4,  s5,  f.x), mix(s6,  s7,  f.x), f.y),
			f.z
		),
		mix(mix(mix(s8,  s9,  f.x), mix(s10, s11, f.x), f.y),
			mix(mix(s12, s13, f.x), mix(s14, s15, f.x), f.y),
			f.z
		),
		f.w
	);
}

vec3 AtmosphereScatteringSingle(sampler2D sampler, float R, float Mu, float MuS, float V) {
	if (MuS < atmosphere_MuS_min) { return vec3(0.0); }

	vec4 uv = AtmosphereScatteringLookupUv(R, Mu, MuS, V);
	vec3 single_rayleigh = PhaseRayleigh(V)             * Texture4DRGBE8(sampler, uv,                 res4D);
	vec3 single_mie      = PhaseMie(V, atmosphere_mieg) * Texture4DRGBE8(sampler, uv + vec4(0,0,0,1), res4D);

	return single_rayleigh + single_mie;
}
vec3 AtmosphereScatteringSingle(sampler2D sampler, vec3 p, vec3 d, vec3 l) {
	float R   = length(p);
	float Mu  = dot(p, d) / R;
	float MuS = dot(p, l) / R;
	float V   = dot(d, l);

	return AtmosphereScatteringSingle(sampler, R, Mu, MuS, V);
}
vec3 AtmosphereScatteringSingle(sampler2D samplerScattering, sampler2D samplerTransmittance, vec3 p, vec3 d, vec3 l, float ed) {
	return AtmosphereScatteringSingle(samplerScattering, p, d, l) - AtmosphereScatteringSingle(samplerScattering, p + d * ed, d, l) * AtmosphereTransmittance(samplerTransmittance, p, d, ed);
}

vec3 AtmosphereScatteringMulti(sampler2D sampler, float R, float Mu, float MuS, float V) {
	if (MuS < atmosphere_MuS_min) { return vec3(0.0); }

	vec4 uv = AtmosphereScatteringLookupUv(R, Mu, MuS, V);
	vec3 multi = Texture4DRGBE8(sampler, uv + vec4(0,0,0,2), res4D);

	return multi;
}
vec3 AtmosphereScatteringMulti(sampler2D sampler, vec3 p, vec3 d, vec3 l) {
	float R   = length(p);
	float Mu  = dot(p, d) / R;
	float MuS = dot(p, l) / R;
	float V   = dot(d, l);

	return AtmosphereScatteringMulti(sampler, R, Mu, MuS, V);
}
vec3 AtmosphereScatteringMulti(sampler2D samplerScattering, sampler2D samplerTransmittance, vec3 p, vec3 d, vec3 l, float ed) {
	return AtmosphereScatteringMulti(samplerScattering, p, d, l) - AtmosphereScatteringMulti(samplerScattering, p + d * ed, d, l) * AtmosphereTransmittance(samplerTransmittance, p, d, ed);
}

vec3 AtmosphereScattering(sampler2D sampler, float R, float Mu, float MuS, float V) {
	if (MuS < atmosphere_MuS_min) { return vec3(0.0); }

	vec4 uv = AtmosphereScatteringLookupUv(R, Mu, MuS, V);
	vec3 single_rayleigh = PhaseRayleigh(V)             * Texture4DRGBE8(sampler, uv,                 res4D);
	vec3 single_mie      = PhaseMie(V, atmosphere_mieg) * Texture4DRGBE8(sampler, uv + vec4(0,0,0,1), res4D);
	vec3 multi           =                                Texture4DRGBE8(sampler, uv + vec4(0,0,0,2), res4D);

	return single_rayleigh + single_mie + multi;
}
vec3 AtmosphereScattering(sampler2D sampler, vec3 p, vec3 d, vec3 l) {
	float R   = length(p);
	float Mu  = dot(p, d) / R;
	float MuS = dot(p, l) / R;
	float V   = dot(d, l);

	return AtmosphereScattering(sampler, R, Mu, MuS, V);
}
vec3 AtmosphereScattering(sampler2D samplerScattering, sampler2D samplerTransmittance, vec3 p, vec3 d, vec3 l, float ed) {
	return AtmosphereScattering(samplerScattering, p, d, l) - AtmosphereScattering(samplerScattering, p + d * ed, d, l) * AtmosphereTransmittance(samplerTransmittance, p, d, ed);
}

#endif
