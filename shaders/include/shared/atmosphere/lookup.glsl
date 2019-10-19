#if !defined INCLUDE_SHARED_ATMOSPHERE_LOOKUP
#define INCLUDE_SHARED_ATMOSPHERE_LOOKUP

/*\
 * Most of these functions are based on the ones from here:
 * https://ebruneton.github.io/precomputed_atmospheric_scattering/atmosphere/functions.glsl.html
\*/

//----------------------------------------------------------------------------//
//--// 2D/4D and 3D/4D conversion //------------------------------------------//

vec2 LookupUv4DTo2D(vec4 coord, const ivec4 resolution) {
	vec2 xy = coord.xy;
	ivec2 zw = ivec2(floor(coord.zw)) * resolution.xy;
	return xy + zw;
}
ivec2 LookupUv4DTo2D(ivec4 coord, const ivec4 resolution) {
	return coord.xy + coord.zw * resolution.xy;
}
vec4 Lookup2DTo4D(ivec2 texel, const ivec4 resolution) {
	vec2 uvXY = vec2(texel % resolution.xy) / resolution.xy;
	vec2 uvZW = floor(vec2(texel.xy) / vec2(resolution.xy)) / resolution.zw;

	return vec4(uvXY, uvZW);
}

vec3 LookupUv4DTo3D(vec4 coord, const ivec4 resolution) {
	return vec3(coord.xy, coord.z + floor(coord.w) * resolution.z);
}
ivec3 LookupUv4DTo3D(ivec4 coord, const ivec4 resolution) {
	coord.z += resolution.z * coord.w;
	return coord.xyz;
}

//----------------------------------------------------------------------------//
//--// Boundary intersection functions //-------------------------------------//

bool AtmosphereRayIntersectsLowerLimit(float R, float Mu) {
	return Mu < 0.0 && R * R * (Mu * Mu - 1.0) + atmosphere_lowerLimitRadiusSquared >= 0.0;
}

float AtmosphereDistanceToUpperLimit(float R, float Mu) {
	float discriminant = R * R * (Mu * Mu - 1.0) + atmosphere_upperLimitRadiusSquared;
	return -R * Mu + sqrt(discriminant);
}
float AtmosphereDistanceToLowerLimit(float R, float Mu) {
	float discriminant = R * R * (Mu * Mu - 1.0) + atmosphere_lowerLimitRadiusSquared;
	return -R * Mu - sqrt(discriminant);
}

//----------------------------------------------------------------------------//
//--// Lookups //-------------------------------------------------------------//

vec2 AtmosphereTransmittanceLookupUv(float R, float Mu) {
	const float H = sqrt(atmosphere_upperLimitRadiusSquared - atmosphere_lowerLimitRadiusSquared);

	float rho = sqrt(Max0(R * R - atmosphere_lowerLimitRadiusSquared));

	float uvMu;
	float absHorizonMu = sqrt(1.0 - atmosphere_lowerLimitRadiusSquared / (R * R));
	if (Mu < -absHorizonMu) {
		float dMin = R - atmosphere_lowerLimitRadius; // distance to lower limit directly down
		float dMax = sqrt(Max0(R * R - atmosphere_lowerLimitRadiusSquared)); // distance to lower limit at horizon
		float d = AtmosphereDistanceToLowerLimit(R, Mu);

		uvMu = AddUvMargin((d - dMin) / (dMax - dMin), transmittanceResolutionMu / 2) * 0.5;
	} else {
		float dMin = atmosphere_upperLimitRadius - R; // distance to upper limit directly up
		float dMax = sqrt(Max0(R * R - atmosphere_lowerLimitRadiusSquared)) + H; // distance to upper limit at horizon
		float d = AtmosphereDistanceToUpperLimit(R, Mu);

		uvMu = AddUvMargin((d - dMin) / (dMax - dMin), transmittanceResolutionMu / 2) * 0.5 + 0.5;
	}

	float uvR = AddUvMargin(rho / H, transmittanceResolutionR);

	return vec2(uvMu, uvR);
}
void AtmosphereTransmittanceLookupUvReverse(vec2 coord, out float R, out float Mu) {
	float uvMu = coord.x;
	float uvR  = RemoveUvMargin(coord.y, transmittanceResolutionR);

	const float H = sqrt(atmosphere_upperLimitRadiusSquared - atmosphere_lowerLimitRadiusSquared);

	float rho = H * uvR;
	R = sqrt(rho * rho + atmosphere_lowerLimitRadiusSquared);

	if (uvMu < 0.5) {
		float dMin = R - atmosphere_lowerLimitRadius; // distance to lower limit directly down
		float dMax = sqrt(R * R - atmosphere_lowerLimitRadiusSquared); // distance to lower limit at horizon
		float d = RemoveUvMargin(uvMu * 2.0, transmittanceResolutionMu / 2) * (dMax - dMin) + dMin;

		Mu = d > 0.0 ? (-R*R + atmosphere_lowerLimitRadiusSquared - d*d) / (2.0 * R * d) : -1.0;
	} else {
		float dMin = atmosphere_upperLimitRadius - R; // distance to upper limit directly up
		float dMax = sqrt(R * R - atmosphere_lowerLimitRadiusSquared) + H; // distance to upper limit at horizon
		float d = RemoveUvMargin(uvMu * 2.0 - 1.0, transmittanceResolutionMu / 2) * (dMax - dMin) + dMin;

		Mu = d > 0.0 ? (-R*R + atmosphere_upperLimitRadiusSquared - d*d) / (2.0 * R * d) : 1.0;
	}
}

vec4 AtmosphereScatteringLookupUv(float R, float Mu, float MuS, float V) {
	const float H = sqrt(atmosphere_upperLimitRadiusSquared - atmosphere_lowerLimitRadiusSquared);

	float rho = sqrt(R * R - atmosphere_lowerLimitRadiusSquared);
	float uvR = AddUvMargin(rho / H, resR);

	float RMu = R * Mu;
	float discriminant = RMu * RMu - R * R + atmosphere_lowerLimitRadiusSquared;
	float uvMu = 0.5;
	if (Mu < 0.0 && discriminant >= 0.0) {
		float d = -RMu - sqrt(discriminant);
		float dMin = R - atmosphere_lowerLimitRadius;
		float dMax = rho;
		uvMu -= 0.5 * AddUvMargin(dMax == dMin ? 0.0 : (d - dMin) / (dMax - dMin), resMu / 2);
	} else {
		float d = -RMu + sqrt(discriminant + H * H);
		float dMin = atmosphere_upperLimitRadius - R;
		float dMax = rho + H;
		uvMu += 0.5 * AddUvMargin((d - dMin) / (dMax - dMin), resMu / 2);
	}

	float d = AtmosphereDistanceToUpperLimit(atmosphere_lowerLimitRadius, MuS);
	float dMin = atmosphere_upperLimitRadius - atmosphere_lowerLimitRadius;
	float dMax = H;
	float a = (d - dMin) / (dMax - dMin);
	float A = -2.0 * atmosphere_MuS_min * atmosphere_lowerLimitRadius / (dMax - dMin);
	float uvMuS = AddUvMargin(Max0(1.0 - a / A) / (1.0 + a), resMuS);

	float halfRangeV = sqrt(Clamp01(1.0 - Mu * Mu) * Clamp01(1.0 - MuS * MuS));
	float maxV = Mu * MuS + halfRangeV;
	float minV = Mu * MuS - halfRangeV;
	float uvV = AddUvMargin((maxV - minV) <= 0.0 ? 0.0 : Clamp01((V - minV) / (maxV - minV)), resV);

	return vec4(uvMu, uvV, uvR, uvMuS);
}
void AtmosphereScatteringLookupUvReverse(vec4 coord, out float R, out float Mu, out float MuS, out float V) {
	float uvMu  = coord.x;
	float uvV   = RemoveUvMargin(coord.y, resV);
	float uvR   = RemoveUvMargin(coord.z, resR);
	float uvMuS = RemoveUvMargin(coord.w, resMuS);

	const float H = sqrt(atmosphere_upperLimitRadiusSquared - atmosphere_lowerLimitRadiusSquared);

	float rho = H * uvR;
	R = sqrt(rho * rho + atmosphere_lowerLimitRadiusSquared);

	if (uvMu < 0.5) {
		float dMin = R - atmosphere_lowerLimitRadius;
		float dMax = rho;
		float d = dMin + (dMax - dMin) * RemoveUvMargin(1.0 - 2.0 * uvMu, resMu / 2);
		Mu = d == 0.0 ? -1.0 : -(rho * rho + d * d) / (2.0 * R * d);
	} else {
		float dMin = atmosphere_upperLimitRadius - R;
		float dMax = rho + H;
		float d = dMin + (dMax - dMin) * RemoveUvMargin(2.0 * uvMu - 1.0, resMu / 2);
		Mu = d == 0.0 ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * R * d);
	}

	float dMin = atmosphere_upperLimitRadius - atmosphere_lowerLimitRadius;
	float dMax = H;
	float A = -2.0 * atmosphere_MuS_min * atmosphere_lowerLimitRadius / (dMax - dMin);
	float a = (A - uvMuS * A) / (1.0 + uvMuS * A);
	float d = dMin + min(a, A) * (dMax - dMin);
	MuS = d == 0.0 ? 1.0 : (H * H - d * d) / (2.0 * atmosphere_lowerLimitRadius * d);

	float halfRangeV = sqrt(Clamp01(1.0 - Mu * Mu) * Clamp01(1.0 - MuS * MuS));
	float maxV = Mu * MuS + halfRangeV;
	float minV = Mu * MuS - halfRangeV;
	V = uvV * (maxV - minV) + minV;
}

#endif
