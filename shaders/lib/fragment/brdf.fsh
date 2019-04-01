#if !defined INCLUDE_FRAGMENT_BRDF
#define INCLUDE_FRAGMENT_BRDF

vec3 FresnelNonpolarized(float VdotH, ComplexVec3 n1, ComplexVec3 n2) {
	ComplexVec3 eta       = ComplexDiv(n1, n2);
	vec3        cosThetaI = vec3(VdotH);
	float       sinThetaI = sqrt(Clamp01(1.0 - VdotH * VdotH));
	ComplexVec3 sinThetaT = ComplexVec3(eta.r * sinThetaI, eta.i * sinThetaI);
	ComplexVec3 cosThetaT = ComplexSqrt(ComplexSub(vec3(1.0), ComplexMul(sinThetaT, sinThetaT))); // Seems to be correct as long as Re(sinThetaT) is between -1 and 1, or Im(sinThetaT) is non-0.
	//ComplexVec3 cosThetaT = ComplexCos(ComplexArcsin(sinThetaT));

	vec3 sqrtRs = ComplexAbs(ComplexDiv(ComplexSub(ComplexMul(n1, cosThetaI), ComplexMul(n2, cosThetaT)), ComplexAdd(ComplexMul(n1, cosThetaI), ComplexMul(n2, cosThetaT))));
	vec3 sqrtRp = ComplexAbs(ComplexDiv(ComplexSub(ComplexMul(n1, cosThetaT), ComplexMul(n2, cosThetaI)), ComplexAdd(ComplexMul(n1, cosThetaT), ComplexMul(n2, cosThetaI))));

	return Clamp01((sqrtRs * sqrtRs + sqrtRp * sqrtRp) * 0.5);
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
	float p = NdotH == 1.0 ? alpha2 : (NdotH * alpha2 - NdotH) * NdotH + 1.0;
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
float G2OverG1SmithGGX(float NdotL, float NdotV, float alpha2) {
	float a = sqrt(alpha2 + (NdotV - NdotV * alpha2) * NdotV);
	float b = sqrt(alpha2 + (NdotL - NdotL * alpha2) * NdotL);
	return Clamp01((NdotV + a) * NdotL / (NdotL * a + NdotV * b));
}

//----------------------------------------------------------------------------//

vec3 CalculateSpecularBRDF(float NdotL, float NdotH, float NdotV, float VdotH, float alpha2, vec3 n, vec3 k) {
	// A point is often used in place of a really, really small light source to simplify a lot of things.
	// Small enough that it can be assumed to be invisible unless reflected by a rough surface.
	if (alpha2 == 0.0) { return vec3(0.0); }

	vec3  f  = FresnelDielectric(VdotH, 1.000275 / n);
	float d  = DistributionGGX(NdotH, alpha2);
	float g2 = G2SmithGGX(NdotL, NdotV, alpha2);

	return f * d * g2 / (4.0 * NdotL * NdotV);
}

// From https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
// Made radiusCos and RdotL inputs but otherwise essentially copy-pasted.
float GetNdotHSquared(float radiusCos, float radiusTan, float NdotL, float NdotV, float VdotL, float RdotL) {
	// Early out if R falls within the disc
	if (RdotL >= radiusCos) { return 1.0; }

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
	float newNdotL = NdotL * radiusCos + NoTr;
	float newVdotL = VdotL * radiusCos + VoTr;
	float NdotH = NdotV + newNdotL;
	float HoH = 2.0 * newVdotL + 2.0;
	return Clamp01(NdotH * NdotH / HoH);
}
vec3 CalculateSpecularBRDFSphere(float NdotL, float NdotV, float VdotL, float VdotH, float alpha2, vec3 n, vec3 k, float angularRadius) {
	// Specular fraction (fresnel)
	vec3 f = FresnelDielectric(VdotH, 1.000275 / n);

	// Reflection direction
	float RdotL = 2.0 * NdotV * NdotL - VdotL; // == dot(reflect(-V, N), L)
	if (alpha2 < 0.25 / 65025.0) {
		// No roughness, use mirror specular
		return step(cos(angularRadius), RdotL) * f / ConeAngleToSolidAngle(angularRadius);
	}


	float NdotH = sqrt(GetNdotHSquared(cos(angularRadius), tan(angularRadius), NdotL, NdotV, VdotL, RdotL));

	NdotV = abs(NdotV);
	// Geometry part
	float d  = DistributionGGX(NdotH, alpha2);
	float g2 = G2SmithGGX(NdotL, NdotV, alpha2);

	return f * d * g2 / (4.0 * NdotL * NdotV);
}

#endif
