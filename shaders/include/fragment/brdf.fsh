#if !defined INCLUDE_FRAGMENT_BRDF
#define INCLUDE_FRAGMENT_BRDF

vec3 FresnelNonpolarized(float VdotH, ComplexVec3 n1, ComplexVec3 n2) {
	ComplexVec3 eta = ComplexDiv(n1, n2);

	float       cosThetaI = VdotH;
	ComplexVec3 cosThetaT = ComplexSqrt(ComplexSub(1.0, ComplexMul(ComplexMul(eta, eta), 1.0 - cosThetaI * cosThetaI)));

	ComplexVec3 RsNum = ComplexSub(ComplexMul(eta, cosThetaI), cosThetaT);
	ComplexVec3 RsDiv = ComplexAdd(ComplexMul(eta, cosThetaI), cosThetaT);
	//vec3 sqrtRs = ComplexAbs(RsNum) / ComplexAbs(RsDiv);
	//vec3 Rs = sqrtRs * sqrtRs;
	vec3 Rs = (RsNum.r * RsNum.r + RsNum.i * RsNum.i) / (RsDiv.r * RsDiv.r + RsDiv.i * RsDiv.i);

	ComplexVec3 RpNum = ComplexSub(ComplexMul(eta, cosThetaT), cosThetaI);
	ComplexVec3 RpDiv = ComplexAdd(ComplexMul(eta, cosThetaT), cosThetaI);
	//vec3 sqrtRp = ComplexAbs(RpNum) / ComplexAbs(RpDiv);
	//vec3 Rp = sqrtRp * sqrtRp;
	vec3 Rp = (RpNum.r * RpNum.r + RpNum.i * RpNum.i) / (RpDiv.r * RpDiv.r + RpDiv.i * RpDiv.i);

	return Clamp01((Rs + Rp) * 0.5);
}
float FresnelDielectric(float VdotH, float eta) { // H = N when no roughness
	// Assumes non-polarized
	float p = 1.0 - (eta * eta * (1.0 - VdotH * VdotH));
	if (p <= 0.0) { return 1.0; } p = sqrt(p);

	vec2 r = vec2(VdotH, p);
	r = (eta * r - r.yx) / (eta * r + r.yx);
	return dot(r, r) * 0.5;
}
vec3 FresnelDielectric(float VdotH, vec3 eta) { // H = N when no roughness
	// Assumes non-polarized
	vec3 p = sqrt(Max0(1.0 - (eta * eta * (1.0 - VdotH * VdotH))));

	vec3 rs = (eta * VdotH - p) / (eta * VdotH + p);
	vec3 rp = (eta * p - VdotH) / (eta * p + VdotH);

	return Clamp01((rs * rs + rp * rp) * 0.5);
}
vec3 FresnelConductor(float VdotH, vec3 n2, vec3 k2) {
	// Found this while looking into complex fresnel online.
	// No idea about the original source.
	// Seems to assume that n1 and k1 are 1 and 0, respectively.
	vec3 ksq = k2 * k2;
	vec3 rs = (Pow2(n2 -        VdotH ) + ksq) / (Pow2(n2 +        VdotH ) + ksq);
	vec3 rp = (Pow2(n2 - (1.0 / VdotH)) + ksq) / (Pow2(n2 + (1.0 / VdotH)) + ksq);

	return Clamp01((rs + rp) * 0.5);
}

float DistributionGGX(float NdotH, float alpha2) {
	float p = (NdotH * alpha2 - NdotH) * NdotH + 1.0;
	return alpha2 / (pi * p * p);
}

float G1SmithGGX(float NdotV, float alpha2) {
	return Clamp01(2.0 * NdotV / (sqrt(alpha2 + (NdotV - NdotV * alpha2) * NdotV) + NdotV));
}
float G2SmithGGX(float NdotV, float NdotL, float alpha2) {
	float a = 2.0 * NdotV * NdotL;
	float b = NdotL * sqrt(alpha2 + (NdotV - NdotV * alpha2) * NdotV);
	float c = NdotV * sqrt(alpha2 + (NdotL - NdotL * alpha2) * NdotL);
	return Clamp01(a / (b + c));
}
vec2 G1G2SmithGGX(float NdotV, float NdotL, float alpha2) {
	vec2 delta = vec2(NdotV, NdotL);
	     delta = abs(sqrt((delta - delta * alpha2) * delta + alpha2) / delta);
	return Clamp01(2.0 / (delta.x + vec2(1.0, delta.y)));
}
float G2OverG1SmithGGX(float NdotV, float NdotL, float alpha2) {
	float a = sqrt(alpha2 + (NdotV - NdotV * alpha2) * NdotV);
	float b = sqrt(alpha2 + (NdotL - NdotL * alpha2) * NdotL);
	return Clamp01((NdotV + a) * NdotL / (NdotL * a + NdotV * b));
}

//----------------------------------------------------------------------------//

vec3 CalculateSpecularBRDF(float NdotL, float NdotH, float NdotV, float VdotH, float alpha2, vec3 n, vec3 k) {
	// A point is often used in place of a really, really small light source to simplify a lot of things.
	// Small enough that it can be assumed to be invisible unless reflected by a rough surface.
	if (alpha2 == 0.0) { return vec3(0.0); }

	vec3  f  = FresnelNonpolarized(VdotH, ComplexVec3(airMaterial.n, airMaterial.k), ComplexVec3(n, k));
	float d  = DistributionGGX(NdotH, alpha2);
	float g2 = G2SmithGGX(NdotL, NdotV, alpha2);

	return f * d * g2 / (4.0 * NdotL * NdotV);
}

// From https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
// Made radiusCos and RdotL inputs but otherwise essentially copy-pasted.
// Also made newNdotL & newVdotL outputs so they can be used afterwards
float GetNdotHSquared(float radiusCos, float radiusTan, float NdotL, float NdotV, float VdotL, float RdotL, out float newNdotL, out float newVdotL) {
	// Early out if R falls within the disc
	if (RdotL >= radiusCos) {
		newNdotL = 2.0 * NdotV - NdotV; // == dot(N, reflect(-V, N))
		newVdotL = 2.0 * NdotV * NdotV - 1.0; // == dot(V, reflect(-V, N))
		return 1.0;
	}

	float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RdotL * RdotL);
	float NoTr = rOverLengthT * (NdotV - RdotL * NdotL);
	float VoTr = rOverLengthT * (2.0 * NdotV * NdotV - 1.0 - RdotL * VdotL);

	// Calculate dot(cross(N, L), V). This could already be calculated and available.
	float triple = sqrt(clamp(1.0 - NdotL * NdotL - NdotV * NdotV - VdotL * VdotL + 2.0 * NdotL * NdotV * VdotL, 0.0, 1.0));

	// Do one Newton iteration to improve the bent light vector
	float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NdotV);
	float NdotLVTr = NdotL * radiusCos + NdotV + NoTr, VdotLVTr = VdotL * radiusCos + 1.0 + VoTr;
	float p = NoBr * VdotLVTr, q = NdotLVTr * VdotLVTr, s = VoBr * NdotLVTr;
	float xNum = q * (-0.5 * p + 0.25 * VoBr * NdotLVTr);
	float xDenom = p * p + s * ((s - 2.0 * p)) + NdotLVTr * ((NdotL * radiusCos + NdotV) * VdotLVTr * VdotLVTr + q * (-0.5 * (VdotLVTr + VdotL * radiusCos) - 0.5));
	float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
	float sinTheta = twoX1 * xDenom;
	float cosTheta = 1.0 - twoX1 * xNum;
	NoTr = cosTheta * NoTr + sinTheta * NoBr; // use new T to update NoTr
	VoTr = cosTheta * VoTr + sinTheta * VoBr; // use new T to update VoTr

	// Calculate (N.H)^2 based on the bent light vector
	newNdotL = NdotL * radiusCos + NoTr;
	newVdotL = VdotL * radiusCos + VoTr;
	float NdotH = NdotV + newNdotL;
	float HoH = 2.0 * newVdotL + 2.0;
	return Clamp01(NdotH * NdotH / HoH);
}
// Estimates normalization factor when using the above
// Not really accurate, but it works well
float EstimateNormalizationFactor(float alpha2, float lightAngularRadius) {
	return alpha2 / (alpha2 + ConeAngleToSolidAngle(lightAngularRadius)/(2.0*pi));
}

vec3 CalculateSpecularBRDFSphere(float NdotL, float NdotV, float LdotV, float VdotH, float alpha2, vec3 n, vec3 k, float angularRadius) {
	// Reflection direction
	float RdotL = 2.0 * NdotV * NdotL - LdotV; // == dot(reflect(-V, N), L)
	if (alpha2 < 0.25 / 65025.0) {
		// Specular fraction (fresnel)
		vec3 f = FresnelNonpolarized(VdotH, ComplexVec3(airMaterial.n, airMaterial.k), ComplexVec3(n, k));

		// No roughness, use mirror specular
		return step(cos(angularRadius), RdotL) * f / ConeAngleToSolidAngle(angularRadius);
	}

	float NdotH = sqrt(GetNdotHSquared(cos(angularRadius), tan(angularRadius), NdotL, NdotV, LdotV, RdotL, NdotL, LdotV));
	VdotH = (LdotV + 1.0) * inversesqrt(2.0 * LdotV + 2.0);

	// Specular fraction (fresnel) for new H
	vec3 f = FresnelNonpolarized(VdotH, ComplexVec3(airMaterial.n, airMaterial.k), ComplexVec3(n, k));

	NdotV = abs(NdotV);
	// Geometry part
	float d  = DistributionGGX(NdotH, alpha2);
	float g2 = G2SmithGGX(NdotL, NdotV, alpha2);

	float norm = EstimateNormalizationFactor(alpha2, angularRadius);

	return norm * f * d * g2 / (4.0 * NdotL * NdotV);
}

#endif
