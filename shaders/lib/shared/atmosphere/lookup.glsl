#if !defined INCLUDE_SHARED_ATMOSPHERE_LOOKUP
#define INCLUDE_SHARED_ATMOSPHERE_LOOKUP

/*\
 * Many of these fucnctions are based on the ones from here:
 * https://ebruneton.github.io/precomputed_atmospheric_scattering/atmosphere/functions.glsl.html
\*/

//----------------------------------------------------------------------------//
//--// 2D/4D conversion //----------------------------------------------------//

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

	float rho = sqrt(R * R - atmosphere_lowerLimitRadiusSquared);

	float d = AtmosphereDistanceToUpperLimit(R, Mu);
	float dMin = atmosphere_upperLimitRadius - R;
	float dMax = rho + H;

	float uvMu = (d - dMin) / (dMax - dMin);
	float uvR  = rho / H;

	return vec2(uvMu, uvR);
}
void AtmosphereTransmittanceLookupUvReverse(vec2 coord, out float R, out float Mu) {
	float uvMu = coord.x;
	float uvR  = coord.y;

	const float H = sqrt(atmosphere_upperLimitRadiusSquared - atmosphere_lowerLimitRadiusSquared);

	float rho = H * uvR;
	R = sqrt(rho * rho + atmosphere_lowerLimitRadiusSquared);

	float dMin = atmosphere_upperLimitRadius - R;
	float dMax = rho + H;
	float d = dMin + uvMu * (dMax - dMin);
	Mu = d == 0.0 ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * R * d);
}

vec4 AtmosphereScatteringLookupUv(float R, float Mu, float MuS, float V) {
	const float H = sqrt(atmosphere_upperLimitRadiusSquared - atmosphere_lowerLimitRadiusSquared);

	float rho = sqrt(R * R - atmosphere_lowerLimitRadiusSquared);
	float uvR = AddUvMargin(rho / H, resR);

	float RMu = R * Mu;
	float discriminant = RMu * RMu - R * R + atmosphere_lowerLimitRadiusSquared;
	float uvMu = 0.5;
	if (AtmosphereRayIntersectsLowerLimit(R, Mu)) {
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

	float uvV = AddUvMargin((V + 1.0) / 2.0, resV);

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

	V = uvV * 2.0 - 1.0;
}

#endif
