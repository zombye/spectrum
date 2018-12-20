#if !defined INCLUDE_FRAGMENT_BRDF
#define INCLUDE_FRAGMENT_BRDF

vec3 FresnelNonpolarized(float VoH, ComplexVec3 n1, ComplexVec3 n2) {
	// Assuming this is all correctly implemented this should be exact.
	ComplexVec3 eta       = ComplexDiv(n1, n2);
	vec3        cosThetaI = vec3(VoH);
	float       sinThetaI = sqrt(clamp(1.0 - VoH * VoH, 0.0, 1.0));
	ComplexVec3 sinThetaT = ComplexVec3(eta.r * sinThetaI, eta.i * sinThetaI);
	ComplexVec3 cosThetaT = ComplexSqrt(ComplexSub(vec3(1.0), ComplexMul(sinThetaT, sinThetaT))); // assuming `sqrt(1-x^2) = cos(asin(x)) = sin(acos(x))` is still true for complex numbers...
	//ComplexVec3 cosThetaT = ComplexCos(ComplexAsin(sinThetaT)); // i actually don't know how to implement these two with complex numbers so I can't make sure it's correct

	vec3 sqrtRs = ComplexAbs(ComplexDiv(ComplexSub(ComplexMul(n1, cosThetaI), ComplexMul(n2, cosThetaT)), ComplexAdd(ComplexMul(n1, cosThetaI), ComplexMul(n2, cosThetaT))));
	vec3 sqrtRp = ComplexAbs(ComplexDiv(ComplexSub(ComplexMul(n1, cosThetaT), ComplexMul(n2, cosThetaI)), ComplexAdd(ComplexMul(n1, cosThetaT), ComplexMul(n2, cosThetaI))));

	return Clamp01((sqrtRs * sqrtRs + sqrtRp * sqrtRp) * 0.5);
}
float FresnelDielectric(float VoH, float eta) { // H = N when no roughness
	// Assumes non-polarized
	float p = 1.0 - (eta * eta * (1.0 - VoH * VoH));
	if (p <= 0.0) { return 1.0; } p = sqrt(p);

	vec2 r = vec2(VoH, p);
	r = (eta * r - r.yx) / (eta * r + r.yx);
	return dot(r, r) * 0.5;
}
vec3 FresnelDielectric(float VoH, vec3 eta) { // H = N when no roughness
	// Assumes non-polarized
	vec3 p = sqrt(Max0(1.0 - (eta * eta * (1.0 - VoH * VoH))));

	vec3 rs = (eta * VoH - p) / (eta * VoH + p);
	vec3 rp = (eta * p - VoH) / (eta * p + VoH);

	return Clamp01((rs * rs + rp * rp) * 0.5);
}
vec3 FresnelConductor(float VoH, vec3 n2, vec3 k2) {
	// Found this while looking into complex fresnel online.
	// No idea about the original source.
	// Seems to assume that n1 and k1 are 1 and 0, respectively.
	// Also supposedly assumes that n2^2 + k2^2 is above 1.
	vec3 ksq = k2 * k2;
	vec3 rs = (Pow2(n2 -        VoH ) + ksq) / (Pow2(n2 +        VoH ) + ksq);
	vec3 rp = (Pow2(n2 - (1.0 / VoH)) + ksq) / (Pow2(n2 + (1.0 / VoH)) + ksq);

	return Clamp01((rs + rp) * 0.5);
}

float DistributionGGX(float NoH, float alpha2) {
	float p = NoH == 1.0 ? alpha2 : (NoH * alpha2 - NoH) * NoH + 1.0;
	return alpha2 / (pi * p * p);
}

float G1SmithGGX(float cosTheta, float alpha2) {
	return Clamp01(1.0 / (0.5 + 0.5 * abs(sqrt((cosTheta - cosTheta * alpha2) * cosTheta + alpha2) / cosTheta)));
}
float G2SmithGGX(float NoV, float NoL, float alpha2) {
	vec2 delta = vec2(NoV, NoL);
	     delta = abs(sqrt((delta - delta * alpha2) * delta + alpha2) / delta);
	return Clamp01(2.0 / (delta.x + delta.y));
}
vec2 G1G2SmithGGX(float NoV, float NoL, float alpha2) {
	vec2 delta = vec2(NoV, NoL);
	     delta = abs(sqrt((delta - delta * alpha2) * delta + alpha2) / delta);
	vec2 denominator = vec2(delta.x + 1.0, delta.x + delta.y);
	return Clamp01(2.0 / denominator);
}

#endif
